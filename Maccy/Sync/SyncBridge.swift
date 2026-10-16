import AppKit
import Defaults
import Logging
import os
import PastronautCore
import Settings

extension Defaults.Keys {
  static let iCloudSync = Key<Bool>("pastronautICloudSync", default: false)
}

// Declared here rather than next to the SwiftUI pane: SwiftUI's `Settings` scene makes the name ambiguous.
extension Settings.PaneIdentifier {
  static let sync = Self("sync")
}

/// Connects Maccy's history to `ClipSync`.
///
/// History reports local changes through the `did…`/`will…` hooks; remote changes are applied back
/// through the normal History API with `isApplyingRemote` set, so they are not echoed to iCloud.
/// Only items that already passed Clipboard's ignore rules reach History, so nothing ignored is synced.
@MainActor
final class SyncBridge {
  static let shared = SyncBridge()

  private let sync: ClipSync
  private let logger = Logger(label: "com.xkbxyberk.pastronaut.sync")
  private var isApplyingRemote = false
  /// Serializes calls into the actor so a delete and a re-add of the same clip keep their order.
  private var tail: Task<Void, Never>?
  private var observation: Task<Void, Never>?

  private var isEnabled: Bool { Defaults[.iCloudSync] && !isApplyingRemote }

  private init() {
    let directory = URL.applicationSupportDirectory.appending(path: "Pastronaut")
    sync = ClipSync(containerIdentifier: PastronautIDs.iCloudContainer, storageDirectory: directory)
  }

  /// Call once at launch. Follows the setting for the rest of the session.
  func start() {
    guard observation == nil else { return }
    #if DEBUG
    // Tests run inside the app and clear History constantly; they must never reach the user's iCloud
    // data or the sync mirror, which share this app's container.
    if AppDelegate.isTesting { return }
    E2EControl.start(sync: sync)
    #endif
    // CKSyncEngine fetches when its subscription push arrives; without registering, the Mac only
    // fetched at launch and on "Sync Now", so changes from the iPhone never showed up.
    NSApplication.shared.registerForRemoteNotifications()
    startFallbackPolling()
    syncWhenWindowsOpen()
    observation = Task { [weak self] in
      // Maccy loads history lazily when the popup first appears. Remote clips applied to an unloaded
      // history would be stored as duplicates, so load it before syncing.
      try? await History.shared.load()
      for await enabled in Defaults.updates(.iCloudSync) {
        await self?.setEnabled(enabled)
      }
    }
  }

  /// Safety net for missed pushes (e.g. while asleep or offline). An unchanged zone costs one small request.
  private func startFallbackPolling() {
    Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(60))
        guard let self, Defaults[.iCloudSync] else { continue }
        try? await self.sync.syncNow()
      }
    }
  }

  /// Fetches when the history popup (or any window of this app) opens, so the list is fresh when the
  /// user is about to paste even if a push was lost. At most every 10 seconds.
  private func syncWhenWindowsOpen() {
    var lastSync = Date.distantPast
    NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
    ) { [weak self] _ in
      guard Defaults[.iCloudSync], Date.now.timeIntervalSince(lastSync) > 10 else { return }
      lastSync = .now
      Task { try? await self?.sync.syncNow() }
    }
  }

  private func setEnabled(_ enabled: Bool) async {
    if enabled {
      await sync.setChangeHandler { changes in
        await SyncBridge.shared.apply(changes)
      }
      await sync.start()
      uploadExistingHistory()
      // Catch up on changes made while this app was closed; the engine alone waits for a push.
      try? await sync.syncNow()
    } else {
      await sync.setChangeHandler(nil)
      await sync.stop()
    }
  }

  // MARK: - Settings

  func status() async -> SyncStatus {
    await sync.status
  }

  func syncNow() async throws {
    try await sync.syncNow()
  }

  /// Removes synced clips from iCloud for all devices and turns sync off. Local history is kept.
  func deleteCloudData() async throws {
    try await sync.deleteCloudData()
    Defaults[.iCloudSync] = false
  }

  // MARK: - Local changes (hooks from History)

  func didAdd(_ item: HistoryItem) {
    guard isEnabled, let clip = Self.clip(for: item, modifiedAt: item.lastCopiedAt) else { return }
    enqueue { await $0.upsert(clip) }
  }

  func didChangePin(_ item: HistoryItem) {
    guard isEnabled, let clip = Self.clip(for: item, modifiedAt: .now) else { return }
    enqueue { await $0.upsert(clip) }
  }

  func willDelete(_ items: [HistoryItem]) {
    guard isEnabled else { return }
    let ids = items.compactMap(Self.clipID(of:))
    guard !ids.isEmpty else { return }
    enqueue { await $0.delete(ids: ids) }
  }

  func didEdit(_ item: HistoryItem, previousClipID: String?) {
    guard isEnabled else { return }
    let clip = Self.clip(for: item, modifiedAt: .now)
    if let previousClipID, previousClipID != clip?.id {
      enqueue { await $0.delete(ids: [previousClipID]) }
    }
    if let clip {
      enqueue { await $0.upsert(clip) }
    }
  }

  private func uploadExistingHistory() {
    let clips = History.shared.allItems.compactMap { Self.clip(for: $0.item, modifiedAt: $0.item.lastCopiedAt) }
    logger.info("Uploading \(clips.count) existing clips")
    enqueue { sync in
      for clip in clips {
        await sync.upsert(clip)
      }
    }
  }

  private func enqueue(_ operation: @escaping @Sendable (ClipSync) async -> Void) {
    let previous = tail
    let sync = sync
    tail = Task {
      await previous?.value
      await operation(sync)
    }
  }

  // MARK: - Remote changes

  private func apply(_ changes: [ClipChange]) {
    isApplyingRemote = true
    defer { isApplyingRemote = false }

    for change in changes {
      switch change {
      case .upserted(let clip):
        if let local = decorator(for: clip.id) {
          if local.isPinned != clip.pinned {
            History.shared.togglePin(local)
          }
        } else {
          insert(clip)
        }
      case .deleted(let id):
        if let local = decorator(for: id) {
          History.shared.delete(local)
        }
      }
    }
  }

  private func decorator(for clipID: String) -> HistoryItemDecorator? {
    History.shared.allItems.first { Self.clipID(of: $0.item) == clipID }
  }

  private func insert(_ clip: Clip) {
    let content = HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data(clip.text.utf8))
    let item = HistoryItem(contents: [content])
    if #unavailable(macOS 15.0) {
      // Same requirement as Clipboard: on macOS 14 the item must be in storage before History.add.
      try? History.shared.insertIntoStorage(item)
    }
    item.application = clip.sourceApp
    item.firstCopiedAt = clip.firstCopiedAt
    item.lastCopiedAt = clip.lastCopiedAt
    if clip.pinned, let pin = HistoryItem.availablePins.randomElement() {
      item.pin = pin
    }
    item.title = item.generateTitle()
    History.shared.add(item)
  }

  // MARK: - Mapping

  /// Only plain-text items sync; images and files stay on this Mac.
  static func clipID(of item: HistoryItem) -> String? {
    syncableText(of: item).map(Clip.id(for:))
  }

  static func clip(for item: HistoryItem, modifiedAt: Date) -> Clip? {
    guard let text = syncableText(of: item) else { return nil }
    return Clip(
      text: text,
      sourceApp: item.application,
      sourceDevice: item.universalClipboard ? .iphone : .mac,
      firstCopiedAt: item.firstCopiedAt,
      lastCopiedAt: item.lastCopiedAt,
      modifiedAt: modifiedAt,
      pinned: item.pin != nil
    )
  }

  private static func syncableText(of item: HistoryItem) -> String? {
    guard item.fileURLs.isEmpty, item.imageData == nil, let text = item.text, !text.isEmpty else { return nil }
    return text
  }
}

// MARK: - Push notifications

// Kept in this file so AppDelegate (upstream code) stays untouched.
extension AppDelegate {
  @objc func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    os_log(.default, "Pastronaut: registered for remote notifications")
  }

  @objc func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    os_log(.error, "Pastronaut: remote notification registration failed: %{public}@", error.localizedDescription)
  }

  @objc func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
    os_log(.default, "Pastronaut: remote notification received")
    Task { try? await SyncBridge.shared.syncNow() }
  }
}

// MARK: - End-to-end test control

#if DEBUG
/// Lets `scripts/e2e` drive this Mac during the two-device sync test. Debug builds only.
///
/// Commands arrive as a distributed notification whose object is a JSON string, e.g.
/// `{"op":"pin","text":"…"}`. Results are written to the unified log as `PTEST-STATE {json}` lines,
/// because the sandbox keeps the test script out of this app's container.
@MainActor
enum E2EControl {
  static let commandName = Notification.Name("com.xkbxyberk.pastronaut.e2e.command")
  private static var sync: ClipSync?

  static func start(sync: ClipSync) {
    self.sync = sync
    DistributedNotificationCenter.default().addObserver(
      forName: commandName, object: nil, queue: .main
    ) { notification in
      let object = notification.object as? String
      MainActor.assumeIsolated { handle(object) }
    }
    os_log(.default, "PTEST-READY")
  }

  private struct Command: Decodable {
    var op: String
    var text: String?
    var prefix: String?
    var tag: String?
  }

  private static func handle(_ object: String?) {
    guard let data = object?.data(using: .utf8),
          let command = try? JSONDecoder().decode(Command.self, from: data) else { return }
    let item = command.text.flatMap { text in History.shared.allItems.first { $0.item.text == text } }
    switch command.op {
    case "pin":
      if let item, item.item.pin == nil { History.shared.togglePin(item) }
    case "unpin":
      if let item, item.item.pin != nil { History.shared.togglePin(item) }
    case "delete":
      if let item { History.shared.delete(item) }
    case "purge":
      // Removes leftovers of earlier runs; only texts with the given prefix.
      let prefix = command.prefix ?? "PTEST-"
      for item in History.shared.allItems where item.item.text?.hasPrefix(prefix) == true {
        History.shared.delete(item)
      }
    case "sync":
      Task { try? await SyncBridge.shared.syncNow() }
    default:
      break
    }
    Task { await dump(prefix: command.prefix ?? "PTEST", tag: command.tag ?? command.op) }
  }

  private static func dump(prefix: String, tag: String) async {
    let status = await SyncBridge.shared.status()
    let mirrored = await sync?.clips ?? []
    func summary(_ text: String) -> String { text.count > 80 ? "\(text.prefix(80))…(\(text.count))" : text }
    let history: [[String: Any]] = History.shared.allItems.compactMap { decorator in
      guard let text = decorator.item.text, text.hasPrefix(prefix) else { return nil }
      return ["text": summary(text), "pinned": decorator.item.pin != nil, "length": text.count]
    }
    let cloud: [[String: Any]] = mirrored.filter { $0.text.hasPrefix(prefix) }.map {
      ["text": summary($0.text), "pinned": $0.pinned, "device": $0.sourceDevice.rawValue]
    }
    let state: [String: Any] = [
      "tag": tag,
      "enabled": Defaults[.iCloudSync],
      "running": status.isRunning,
      "synced": status.syncedClips,
      "historyCount": History.shared.allItems.count,
      "lastError": status.lastError ?? NSNull(),
      "history": history,
      "mirror": cloud
    ]
    guard let json = try? JSONSerialization.data(withJSONObject: state),
          let line = String(data: json, encoding: .utf8) else { return }
    os_log(.default, "PTEST-STATE %{public}@", line)
  }
}
#endif
