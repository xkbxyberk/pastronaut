import AppKit
import Defaults
import Logging
import os
import PastronautCore
import Security
import Settings

extension Defaults.Keys {
  static let iCloudSync = Key<Bool>("pastronautICloudSync", default: false)
  // Privacy switches in Sync settings; off by default, so everything syncs.
  static let syncSkipOneTimeCodes = Key<Bool>("pastronautSkipOneTimeCodes", default: false)
  static let syncSkipCardNumbers = Key<Bool>("pastronautSkipCardNumbers", default: false)
  static let syncPinnedOnly = Key<Bool>("pastronautPinnedOnly", default: false)
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

  let sync: ClipSync
  let logger = Logger(label: "com.xkbxyberk.pastronaut.sync")
  private var isApplyingRemote = false
  /// The history limit or "Keep history" is removing items (see `pruning`).
  private var isPruning = false
  /// Apps whose icon was offered to `ClipSync` this session.
  var publishedIcons: Set<String> = []
  /// Serializes calls into the actor so a delete and a re-add of the same clip keep their order.
  private var tail: Task<Void, Never>?
  private var observation: Task<Void, Never>?
  private var privacyObservation: Task<Void, Never>?
  private var mediaSettingsObservation: Task<Void, Never>?

  var isEnabled: Bool { Defaults[.iCloudSync] && !isApplyingRemote }

  private init() {
    let directory = URL.applicationSupportDirectory.appending(path: "Pastronaut")
    sync = ClipSync(
      containerIdentifier: PastronautIDs.iCloudContainer, storageDirectory: directory, environment: Self.iCloudEnvironment
    )
  }

  /// "development" for Debug builds, "production" for the App Store and GitHub ones: the push environment in this
  /// app's signature, which follows the iCloud one. A Debug build opens the same container as the real app.
  static var iCloudEnvironment: String? {
    guard let task = SecTaskCreateFromSelf(nil) else { return nil }
    return SecTaskCopyValueForEntitlement(task, "com.apple.developer.aps-environment" as CFString, nil) as? String
  }

  /// Call once at launch. Follows the setting for the rest of the session.
  func start() {
    guard observation == nil else { return }
    PopupExtras.start()
    #if DEBUG
    // Tests run inside the app and clear History constantly; they must never reach the user's iCloud
    // data or the sync mirror, which share this app's container.
    if AppDelegate.isTesting {
      // Design review screenshots (MaccyUITests.testPastronautScreenshots).
      if CommandLine.arguments.contains("pastronaut-show-onboarding") { OnboardingWindow.show() }
      return
    }
    E2EControl.start(sync: sync)
    #endif
    OnboardingWindow.showIfNeeded()
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
    // The sync layer keeps what the switches hold back (an unpinned image with "Sync pinned items only") on this
    // Mac only, and sends it once it is allowed (pinned). Text is filtered before it gets there.
    let initialPrivacy = privacy
    enqueue { await $0.setPrivacy(initialPrivacy) }
    privacyObservation = Task { [weak self] in
      for await _ in Defaults.updates(.syncSkipOneTimeCodes, .syncSkipCardNumbers, .syncPinnedOnly, initial: false) {
        if let privacy = self?.privacy { self?.enqueue { await $0.setPrivacy(privacy) } }
        await self?.sendSharedSettings()
        await self?.applyPrivacyChange()
      }
    }
    mediaSettingsObservation = Task { [weak self] in
      for await _ in Defaults.updates(.mediaSyncEnabled, .mediaMaxItemBytes, .mediaCloudBudgetBytes, initial: false) {
        await self?.sendSharedSettings()
      }
    }
  }

  // MARK: - Privacy

  var privacy: PrivacyOptions {
    PrivacyOptions(
      skipOneTimeCodes: Defaults[.syncSkipOneTimeCodes],
      skipCardNumbers: Defaults[.syncSkipCardNumbers],
      pinnedOnly: Defaults[.syncPinnedOnly]
    )
  }

  /// A switch changed: take this Mac's clips that are no longer allowed out of iCloud, and upload the ones that
  /// are allowed again. Clips captured on the iPhone are left alone, and local history is never touched.
  private func applyPrivacyChange() async {
    guard Defaults[.iCloudSync] else { return }
    let privacy = privacy
    let blocked = await sync.clips
      .filter { $0.sourceDevice == .mac && !privacy.allows($0.privacyText, pinned: $0.isKept) }
      .map(\.id)
    if !blocked.isEmpty {
      logger.info("Privacy change removes \(blocked.count) clips from iCloud")
      enqueue { await $0.delete(ids: blocked) }
    }
    uploadExistingHistory()
  }

  /// With "Don't sync one-time codes" on, a code also leaves this Mac's history after five minutes.
  private func scheduleRemovalIfOneTimeCode(_ item: HistoryItem) {
    guard Defaults[.syncSkipOneTimeCodes], item.pin == nil, let text = item.text,
          SensitiveContent(text) == .oneTimeCode else { return }
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(5 * 60))
      guard Defaults[.syncSkipOneTimeCodes],
            let decorator = History.shared.allItems.first(where: { $0.item == item }),
            decorator.item.pin == nil else { return }
      History.shared.delete(decorator)
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
      await sync.pruneMedia()
      await refreshCollections()
      uploadExistingHistory()
      // Catch up on changes made while this app was closed; the engine alone waits for a push.
      try? await sync.syncNow()
      await reconcileSharedSettings()
    } else {
      await sync.setChangeHandler(nil)
      await sync.stop()
    }
    await refreshCollections()
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
    scheduleRemovalIfOneTimeCode(item)
    guard isEnabled else { return }
    if !item.universalClipboard { publishIcon(for: item.application) }
    guard let clip = Self.clip(for: item, modifiedAt: item.lastCopiedAt) else {
      didAddMedia(item)
      return
    }
    guard privacy.allows(clip.text, pinned: clip.pinned || SyncedCollections.shared.isKept(item)) else { return }
    // A copy: the pin and collections iCloud already has for this text stay (this Mac may have had no pin key
    // left for it, and it doesn't keep collections itself).
    enqueue { await $0.recordCopy(clip) }
  }

  func didChangePin(_ item: HistoryItem) {
    guard isEnabled else { return }
    if let id = item.pastronautMediaID {
      let pinned = item.pin != nil
      enqueue { await $0.modify(clipID: id) { $0.pinned = pinned } }
      return
    }
    guard let clip = Self.clip(for: item, modifiedAt: .now) else { return }
    if privacy.allows(clip.text, pinned: clip.pinned || SyncedCollections.shared.isKept(item)) {
      let pinned = clip.pinned
      enqueue { await $0.modify(clipID: clip.id, fallback: clip) { $0.pinned = pinned } }
    } else if clip.sourceDevice == .mac {
      // E.g. unpinned while "Sync pinned items only" is on.
      enqueue { await $0.delete(ids: [clip.id]) }
    }
  }

  func willDelete(_ items: [HistoryItem]) {
    guard isEnabled else { return }
    // The history limit takes only this Mac's own copies out of iCloud; copies from other devices leave this
    // Mac's history but stay in iCloud and on those devices.
    let (ids, dismissed) = Self.removals(of: items, pruning: isPruning)
    if !dismissed.isEmpty {
      enqueue { await $0.dismiss(ids: dismissed) }
    }
    guard !ids.isEmpty else { return }
    enqueue { await $0.delete(ids: ids) }
  }

  /// Clip IDs to delete from iCloud, and those only to hide here: the history limit hides copies from other
  /// devices instead of deleting them.
  static func removals(of items: [HistoryItem], pruning: Bool) -> (delete: [String], dismiss: [String]) {
    var delete: [String] = [], dismiss: [String] = []
    for item in items {
      guard let id = clipID(of: item) else { continue }
      if pruning && item.isFromIPhone {
        dismiss.append(id)
      } else {
        delete.append(id)
      }
    }
    return (delete, dismiss)
  }

  /// Runs removals made by the history limit or "Keep history" (see `willDelete`).
  func pruning(_ body: () -> Void) {
    isPruning = true
    defer { isPruning = false }
    body()
  }

  /// Clear (unpinned items): clips in a collection are kept, like pinned ones, so they stay in iCloud and
  /// `didClear` puts them back.
  func willClear(_ items: [HistoryItem]) {
    willDelete(items.filter { !SyncedCollections.shared.isKept($0) })
  }

  func didClear() {
    guard isEnabled else { return }
    Task {
      let kept = await sync.clips.filter { !$0.collectionIDs.isEmpty }
      apply(kept.map { .upserted($0) })
    }
  }

  func didEdit(_ item: HistoryItem, previousClipID: String?) {
    guard isEnabled else { return }
    let clip = Self.clip(for: item, modifiedAt: .now)
    if let previousClipID, previousClipID != clip?.id {
      enqueue { await $0.delete(ids: [previousClipID]) }
    }
    if let clip, privacy.allows(clip.text, pinned: clip.pinned) {
      // The edited text is a new clip; it stays in the old one's collections and keeps its title.
      let itemID = item.persistentModelID
      enqueue { sync in
        var edited = clip
        if let previousClipID, let previous = await sync.clip(withID: previousClipID) {
          edited.collectionIDs = previous.collectionIDs
          edited.takeTitle(from: previous)
          if let title = previous.title {
            await MainActor.run {
              History.shared.allItems.first { $0.item.persistentModelID == itemID }?.item.title = title
            }
          }
        }
        await sync.upsert(edited)
      }
    }
  }

  // MARK: - Collections

  /// Text this Mac may sync, and images and files that went to iCloud, can go into a collection; other images
  /// and files and blocked text can't.
  func canCollect(_ item: HistoryItem) -> Bool {
    guard Defaults[.iCloudSync] else { return false }
    if item.pastronautMediaID != nil { return true }
    guard let text = Self.syncableText(of: item) else { return false }
    // Putting something in a collection is a decision to keep it, like a pin.
    return privacy.allows(text, pinned: true)
  }

  func setMembership(_ isMember: Bool, of items: [HistoryItem], in collectionID: String) {
    // Media clips change only as iCloud has them (`modify` without a fallback).
    let changes: [(id: String, fallback: Clip?)] = items.filter(canCollect).compactMap { item in
      if let id = item.pastronautMediaID { return (id, nil) }
      return Self.clip(for: item, modifiedAt: item.lastCopiedAt).map { ($0.id, $0) }
    }
    guard !changes.isEmpty else { return }
    enqueue { sync in
      for change in changes {
        await sync.modify(clipID: change.id, fallback: change.fallback) { clip in
          if isMember {
            clip.collectionIDs.append(collectionID)
          } else {
            clip.collectionIDs.removeAll { $0 == collectionID }
          }
        }
      }
    }
    collectionsChanged()
  }

  func createCollection(named name: String, with items: [HistoryItem]) {
    let collection = ClipCollection(name: name, order: SyncedCollections.shared.collections.nextOrder)
    enqueue { await $0.upsertCollection(collection) }
    if items.isEmpty {
      collectionsChanged()
    } else {
      setMembership(true, of: items, in: collection.id)
    }
  }

  func rename(_ collection: ClipCollection, to name: String) {
    var renamed = collection
    renamed.name = name
    renamed.modifiedAt = .now
    let change = renamed
    enqueue { await $0.upsertCollection(change) }
    collectionsChanged()
  }

  func deleteCollection(_ collection: ClipCollection) {
    let id = collection.id
    enqueue { await $0.deleteCollection(id: id) }
    collectionsChanged()
  }

  /// After a change made here: show it, and send it now rather than in a few seconds.
  private func collectionsChanged() {
    enqueue { sync in
      await SyncBridge.shared.refreshCollections()
      try? await sync.sendNow()
    }
  }

  func refreshCollections() async {
    let enabled = Defaults[.iCloudSync]
    let collections = enabled ? await sync.collections : []
    let clips = enabled ? await sync.clips : []
    SyncedCollections.shared.update(collections: collections, clips: clips, isAvailable: enabled)
  }

  // MARK: - Export and import

  /// Every text item in this Mac's history, with pins and collections.
  func makeArchive() -> ClipArchive {
    let collections = SyncedCollections.shared
    let clips = History.shared.allItems.compactMap { decorator -> Clip? in
      guard var clip = Self.clip(for: decorator.item, modifiedAt: decorator.item.lastCopiedAt) else { return nil }
      clip.collectionIDs = collections.collectionIDs(of: decorator.item)
      return clip
    }
    return ClipArchive(clips: clips, collections: collections.collections)
  }

  /// Adds an export's clips to this Mac's history (and to iCloud, with its collections, when sync is on).
  /// Returns how many clips were new.
  @discardableResult
  func importArchive(_ archive: ClipArchive) -> Int {
    let collections = SyncedCollections.shared
    let existing = History.shared.allItems.compactMap { decorator -> Clip? in
      guard var clip = Self.clip(for: decorator.item, modifiedAt: decorator.item.lastCopiedAt) else { return nil }
      clip.collectionIDs = collections.collectionIDs(of: decorator.item)
      return clip
    }
    let plan = archive.importPlan(existingClips: existing, existingCollections: collections.collections, device: .mac)
    logger.info("Importing \(plan.clips.count) clips, \(plan.collections.count) new collections")

    // Local history first, without echoing every item; the whole plan goes to iCloud below.
    isApplyingRemote = true
    for clip in plan.clips.reversed() {
      if let local = decorator(for: clip.id) {
        if clip.pinned, !local.isPinned, !HistoryItem.availablePins.isEmpty {
          History.shared.togglePin(local)
        }
      } else {
        insert(clip)
      }
    }
    isApplyingRemote = false

    guard Defaults[.iCloudSync] else { return plan.newClipCount }
    let privacy = privacy
    let newCollections = plan.collections
    let clips = plan.clips.filter { privacy.allows($0.text, pinned: $0.isKept) }
    enqueue { sync in
      for collection in newCollections {
        await sync.upsertCollection(collection)
      }
      await sync.upsert(contentsOf: clips)
    }
    collectionsChanged()
    return plan.newClipCount
  }

  private func uploadExistingHistory() {
    let privacy = privacy
    let clips = History.shared.allItems
      .compactMap { decorator -> Clip? in
        guard let clip = Self.clip(for: decorator.item, modifiedAt: decorator.item.lastCopiedAt),
              privacy.allows(clip.text, pinned: clip.pinned || SyncedCollections.shared.isKept(decorator.item)) else {
          return nil
        }
        return clip
      }
    logger.info("Uploading \(clips.count) existing clips")
    // As copies, so pins and collections iCloud has stay.
    enqueue { await $0.recordCopies(clips) }
    // Icons of the apps in the history, so the iPhone can show where clips came from.
    let apps = Set(History.shared.allItems.filter { !$0.item.universalClipboard }.compactMap(\.item.application))
    for app in apps.prefix(100) {
      publishIcon(for: app)
    }
  }

  func enqueue(_ operation: @escaping @Sendable (ClipSync) async -> Void) {
    let previous = tail
    let sync = sync
    tail = Task {
      await previous?.value
      await operation(sync)
    }
  }

  /// Takes a row out of this Mac's history without telling iCloud (it is not a deletion of the clip).
  func removeLocally(_ decorator: HistoryItemDecorator) {
    isApplyingRemote = true
    defer { isApplyingRemote = false }
    History.shared.delete(decorator)
  }

  // MARK: - Remote changes

  private func apply(_ changes: [ClipChange]) {
    isApplyingRemote = true
    defer {
      isApplyingRemote = false
      Task { await refreshCollections() }
    }

    for change in changes {
      switch change {
      case .upserted(let clip):
        if let local = decorator(for: clip.id) {
          if local.isPinned != clip.pinned {
            History.shared.togglePin(local)
          }
          applyTitle(of: clip, to: local.item)
          // Copied again on another device: it moves up here too.
          if clip.lastCopiedAt > local.item.lastCopiedAt {
            local.item.lastCopiedAt = clip.lastCopiedAt
            History.shared.reorder(local)
          }
        } else if clip.isMedia {
          // Shown once its files are here; `ClipSync` reports it again when they arrive.
          if sync.media.hasFiles(for: clip) { insertMedia(clip) }
        } else if !isFileNameEcho(clip) {
          insert(clip)
        }
      case .deleted(let id):
        if let local = decorator(for: id) {
          History.shared.delete(local)
        }
      case .collectionUpserted, .collectionDeleted:
        // Shown from the mirror by refreshCollections.
        break
      case .settingsChanged(let settings):
        applySharedSettings(settings)
      case .appIconsChanged:
        // This Mac shows its own apps' icons.
        break
      }
    }
  }

  func decorator(for clipID: String) -> HistoryItemDecorator? {
    History.shared.allItems.first { Self.clipID(of: $0.item) == clipID }
  }

  private func insert(_ clip: Clip) {
    let content = HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data(clip.text.utf8))
    var contents = [content]
    if clip.sourceDevice != .mac {
      // Remembers the origin so the popup can badge it and later changes from this Mac keep it an iPhone clip.
      contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.pastronautFromIPhone.rawValue, value: Data()))
    }
    let item = HistoryItem(contents: contents)
    if #unavailable(macOS 15.0) {
      // Same requirement as Clipboard: on macOS 14 the item must be in storage before History.add.
      try? History.shared.insertIntoStorage(item)
    }
    item.application = clip.sourceApp
    item.firstCopiedAt = clip.firstCopiedAt
    item.lastCopiedAt = clip.lastCopiedAt
    // Without a pin key left the item stays unpinned here, but it is kept (`SyncedCollections.isKept`).
    if clip.pinned, let pin = HistoryItem.availablePins.randomElement() {
      item.pin = pin
    }
    item.title = clip.title ?? item.generateTitle()
    History.shared.add(item)
  }

  /// A title given on another device (or taken away) shows here.
  private func applyTitle(of clip: Clip, to item: HistoryItem) {
    guard clip.titleModifiedAt != nil else { return }
    let title = clip.title ?? (clip.isMedia ? Self.mediaTitle(of: clip) : item.generateTitle())
    if item.title != title { item.title = title }
  }

  /// Gives an item a title (or removes it with nil) here and on the other devices.
  func setTitle(_ title: String?, of item: HistoryItem) {
    guard Defaults[.iCloudSync], let id = Self.clipID(of: item) else { return }
    let fallback = Self.clip(for: item, modifiedAt: item.lastCopiedAt)
    let isMedia = item.pastronautMediaID != nil
    if let title {
      item.title = title
    } else if !isMedia {
      item.title = item.generateTitle()
    }
    enqueue { sync in
      await sync.modify(clipID: id, fallback: fallback) { $0.setTitle(title) }
      if isMedia, title == nil, let clip = await sync.clip(withID: id) {
        let untitled = SyncBridge.mediaTitle(of: clip)
        await MainActor.run { SyncBridge.shared.decorator(for: id)?.item.title = untitled }
      }
      try? await sync.sendNow()
    }
  }

  // MARK: - Mapping

  /// Plain text by its hash; images and files by the ID they got when they went to iCloud (1.3). Other images
  /// and files stay on this Mac.
  static func clipID(of item: HistoryItem) -> String? {
    item.pastronautMediaID ?? syncableText(of: item).map(Clip.id(for:))
  }

  static func clip(for item: HistoryItem, modifiedAt: Date) -> Clip? {
    guard let text = syncableText(of: item) else { return nil }
    return Clip(
      text: text,
      // A Universal Clipboard copy was made on another device; the app recorded here is just whatever was
      // frontmost on this Mac, so it must not be shown as the source.
      sourceApp: item.universalClipboard ? nil : item.application,
      sourceAppName: item.universalClipboard ? nil : item.application.flatMap(appName(for:)),
      sourceDevice: item.isFromIPhone ? .iphone : .mac,
      firstCopiedAt: item.firstCopiedAt,
      lastCopiedAt: item.lastCopiedAt,
      modifiedAt: modifiedAt,
      pinned: item.pin != nil
    )
  }

  /// Readable app name for other devices, which cannot resolve a Mac bundle identifier.
  static func appName(for bundleIdentifier: String) -> String? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
    return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
  }

  static func syncableText(of item: HistoryItem) -> String? {
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
    /// Collection name for "collect" and "uncollect" (and "collectMedia"); the title for "titleMedia".
    var name: String?
  }

  private static func handle(_ object: String?) {
    guard let data = object?.data(using: .utf8),
          let command = try? JSONDecoder().decode(Command.self, from: data) else { return }
    // 1.3: images, PDFs and files, found by text in them or in their file names (`text`).
    // "deleteUnsyncedMedia" works on history rows that have no clip, below.
    if command.op.hasSuffix("Media"), command.op != "deleteUnsyncedMedia" {
      Task {
        await handleMedia(command)
        await dump(prefix: command.prefix ?? "PTEST", tag: command.tag ?? command.op, full: false)
      }
      return
    }
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
    case "privacy":
      // {"op":"privacy","text":"otp:on"} — otp, cards or pinned; on or off.
      let parts = (command.text ?? "").split(separator: ":").map(String.init)
      if parts.count == 2 {
        let on = parts[1] == "on"
        switch parts[0] {
        case "otp": Defaults[.syncSkipOneTimeCodes] = on
        case "cards": Defaults[.syncSkipCardNumbers] = on
        case "pinned": Defaults[.syncPinnedOnly] = on
        default: break
        }
      }
    case "collect", "uncollect":
      // {"op":"collect","text":"…","name":"PTEST Collection"}: creates the collection when needed.
      guard let item, let name = command.name else { break }
      if let collection = SyncedCollections.shared.collections.first(where: { $0.name == name }) {
        SyncBridge.shared.setMembership(command.op == "collect", of: [item.item], in: collection.id)
      } else if command.op == "collect" {
        SyncBridge.shared.createCollection(named: name, with: [item.item])
      }
    case "deleteCollection":
      if let collection = SyncedCollections.shared.collections.first(where: { $0.name == command.name }) {
        SyncBridge.shared.deleteCollection(collection)
      }
    case "mediaSync":
      // {"op":"mediaSync","text":"on"}: Images & Files on or off (shared by every device).
      Defaults[.mediaSyncEnabled] = command.text == "on"
    case "pinNewest":
      // The newest item, whatever it is (e.g. an image kept on this Mac by "Sync pinned items only").
      if let newest = History.shared.allItems.max(by: { $0.item.lastCopiedAt < $1.item.lastCopiedAt }),
         newest.item.pin == nil {
        History.shared.togglePin(newest)
      }
    case "deleteUnsyncedMedia":
      // {"op":"deleteUnsyncedMedia","text":"<from>,<to>"} (seconds since 2001): images and files the test copied
      // that never went to iCloud, so none stay in this Mac's history.
      let bounds = (command.text ?? "").split(separator: ",").compactMap { Double($0) }
      if bounds.count == 2 {
        let from = Date(timeIntervalSinceReferenceDate: bounds[0]), to = Date(timeIntervalSinceReferenceDate: bounds[1])
        for decorator in History.shared.allItems where decorator.item.pastronautMediaID == nil
          && (decorator.item.imageData != nil || !decorator.item.fileURLs.isEmpty)
          && decorator.item.lastCopiedAt >= from && decorator.item.lastCopiedAt <= to {
          History.shared.delete(decorator)
        }
      }
    case "mediaLimit":
      // {"op":"mediaLimit","text":"10000000"}: Largest Item (shared by every device).
      if let bytes = command.text.flatMap(Int.init) { Defaults[.mediaMaxItemBytes] = bytes }
    case "sync":
      Task { try? await SyncBridge.shared.syncNow() }
    default:
      break
    }
    Task { await dump(prefix: command.prefix ?? "PTEST", tag: command.tag ?? command.op, full: command.op == "fullDump") }
  }

  /// What a media clip can be found by: the text read from it and its file names.
  private static func haystack(_ clip: Clip) -> String {
    ([clip.media?.recognizedText ?? ""] + (clip.media?.files.map(\.name) ?? [])).joined(separator: " ")
  }

  private static func handleMedia(_ command: Command) async {
    guard let needle = command.text, let sync,
          let clip = await sync.clips.first(where: { $0.isMedia && haystack($0).contains(needle) }),
          let item = SyncBridge.shared.decorator(for: clip.id) else { return }
    switch command.op {
    case "pinMedia":
      if item.item.pin == nil { History.shared.togglePin(item) }
    case "unpinMedia":
      if item.item.pin != nil { History.shared.togglePin(item) }
    case "deleteMedia":
      History.shared.delete(item)
    case "pruneMedia":
      // As the history limit removes it (decision 3: another device's clip leaves this Mac only).
      SyncBridge.shared.pruning { History.shared.delete(item) }
    case "titleMedia":
      SyncBridge.shared.setTitle(command.name, of: item.item)
    case "collectMedia":
      guard let name = command.name else { break }
      if let collection = SyncedCollections.shared.collections.first(where: { $0.name == name }) {
        SyncBridge.shared.setMembership(true, of: [item.item], in: collection.id)
      } else {
        SyncBridge.shared.createCollection(named: name, with: [item.item])
      }
    default:
      break
    }
  }

  /// `full`: also every clip in iCloud, as IDs and fields (no text), to compare with the iPhone's mirror.
  private static func dump(prefix: String, tag: String, full: Bool = false) async {
    let status = await SyncBridge.shared.status()
    let mirrored = await sync?.clips ?? []
    func summary(_ text: String) -> String { text.count > 80 ? "\(text.prefix(80))…(\(text.count))" : text }
    let history: [[String: Any]] = History.shared.allItems.compactMap { decorator in
      guard let text = decorator.item.text, text.hasPrefix(prefix) else { return nil }
      return [
        "text": summary(text),
        "pinned": decorator.item.pin != nil,
        "length": text.count,
        "kept": SyncedCollections.shared.isKept(decorator.item),
        "lastCopiedAt": decorator.item.lastCopiedAt.timeIntervalSinceReferenceDate
      ]
    }
    let collections = await sync?.collections ?? []
    let names = Dictionary(uniqueKeysWithValues: collections.map { ($0.id, $0.name) })
    var cloud: [[String: Any]] = []
    for clip in mirrored where clip.text.hasPrefix(prefix) {
      cloud.append([
        "text": summary(clip.text),
        "pinned": clip.pinned,
        "device": clip.sourceDevice.rawValue,
        "id": clip.id,
        "title": clip.title ?? NSNull(),
        "lastCopiedAt": clip.lastCopiedAt.timeIntervalSinceReferenceDate,
        "collections": clip.collectionIDs.compactMap { names[$0] },
        // Must not be the content hash: record names are keyed (SyncKey).
        "keyedName": await sync?.recordName(forClipID: clip.id).map { $0 != clip.id && !$0.contains(clip.id.dropFirst(5)) } ?? false
      ])
    }
    // 1.3: media in this Mac's history and in the sync mirror whose text or file names contain the prefix.
    let mediaHistory: [[String: Any]] = History.shared.allItems.compactMap { decorator in
      guard let id = decorator.item.pastronautMediaID,
            let clip = mirrored.first(where: { $0.id == id }), haystack(clip).contains(prefix) else { return nil }
      return [
        "id": id, "title": decorator.item.title, "pinned": decorator.item.pin != nil, "kind": clip.kind.rawValue,
        "device": clip.sourceDevice.rawValue, "files": clip.media?.files.map(\.name) ?? [],
        "hasFiles": sync?.media.hasFiles(for: clip) ?? false,
        "lastCopiedAt": decorator.item.lastCopiedAt.timeIntervalSinceReferenceDate,
        "collections": clip.collectionIDs.compactMap { names[$0] }
      ]
    }
    let localOnlyIDs = await sync?.localOnly.clips ?? []
    let mediaMirror: [[String: Any]] = mirrored.filter { $0.isMedia && haystack($0).contains(prefix) }.map { clip in
      [
        "localOnly": localOnlyIDs.contains(clip.id),
        "id": clip.id, "kind": clip.kind.rawValue, "pinned": clip.pinned, "device": clip.sourceDevice.rawValue,
        "files": clip.media?.files.map(\.name) ?? [], "bytes": clip.media?.totalBytes ?? 0,
        "text": String((clip.media?.recognizedText ?? "").prefix(80)), "title": clip.title ?? NSNull(),
        "collections": clip.collectionIDs.compactMap { names[$0] }
      ]
    }
    // 1.3 copy matrix: every picture or file row whose title, file names or clip contains the prefix, with or without
    // a clip: what the row shows, and whether it says it stays on this Mac.
    let rows: [[String: Any]] = History.shared.allItems.compactMap { decorator in
      let item = decorator.item
      guard item.pastronautMediaID != nil || item.imageData != nil || item.pdfData != nil || !item.fileURLs.isEmpty
      else { return nil }
      let clip = item.pastronautMediaID.flatMap { id in mirrored.first { $0.id == id } }
      let names = item.fileURLs.map(\.lastPathComponent)
      guard item.title.contains(prefix) || names.contains(where: { $0.contains(prefix) })
              || clip.map({ haystack($0).contains(prefix) }) == true else { return nil }
      return [
        "title": item.title, "mediaID": item.pastronautMediaID ?? NSNull(), "kind": clip?.kind.rawValue ?? NSNull(),
        "hasImage": item.imageData != nil, "files": names, "clipFiles": clip?.media?.files.map(\.name) ?? [],
        "localOnlyMarker": item.isLocalOnlyMedia,
        "lastCopiedAt": item.lastCopiedAt.timeIntervalSinceReferenceDate
      ]
    }
    let shared = await sync?.sharedSettings
    // Every clip in iCloud (not those kept on this Mac), without its text: titles as a short hash.
    var everything: [[String: Any]] = []
    if full, let sync {
      let localOnly = await sync.localOnly.clips
      for clip in mirrored where !localOnly.contains(clip.id) {
        everything.append([
          "id": clip.id, "pinned": clip.pinned, "lastCopiedAt": clip.lastCopiedAt.timeIntervalSinceReferenceDate,
          "title": clip.title.map { String(ClipMedia.sha256(Data($0.utf8)).prefix(12)) } ?? NSNull(),
          "collections": clip.collectionIDs.sorted(), "media": clip.isMedia
        ])
      }
    }
    let state: [String: Any] = [
      "tag": tag,
      "full": everything,
      "media": mediaHistory,
      "mediaMirror": mediaMirror,
      "rows": rows,
      "shared": [
        "codes": shared?.skipOneTimeCodes ?? false, "cards": shared?.skipCardNumbers ?? false,
        "pinnedOnly": shared?.pinnedOnly ?? false, "mediaSync": shared?.media.syncEnabled ?? true,
        "maxItemBytes": shared?.media.maxItemBytes ?? 0, "cloudBudgetBytes": shared?.media.cloudBudgetBytes ?? 0
      ],
      "defaults": [
        "maxItemBytes": Defaults[.mediaMaxItemBytes], "cards": Defaults[.syncSkipCardNumbers],
        "codes": Defaults[.syncSkipOneTimeCodes], "pinnedOnly": Defaults[.syncPinnedOnly]
      ],
      "mediaBytesInCloud": status.mediaBytesInCloud,
      "enabled": Defaults[.iCloudSync],
      "running": status.isRunning,
      "synced": status.syncedClips,
      "historyCount": History.shared.allItems.count,
      "lastError": status.lastError ?? NSNull(),
      "hasKey": status.hasKey,
      "keyFingerprint": await sync?.keyFingerprint ?? NSNull(),
      "movingOldClips": status.isMovingOldClips,
      "oldZoneCleared": status.oldZoneCleared,
      "collections": collections.map(\.name).filter { $0.hasPrefix(prefix) },
      "history": history,
      "mirror": cloud
    ]
    guard let json = try? JSONSerialization.data(withJSONObject: state),
          let line = String(data: json, encoding: .utf8) else { return }
    // The unified log truncates long messages, so the state goes out in numbered parts.
    let parts = stride(from: 0, to: line.count, by: 600).map {
      String(line.dropFirst($0).prefix(600))
    }
    for (index, part) in parts.enumerated() {
      os_log(.default, "PTEST-STATE %{public}@ %d/%d %{public}@", tag, index + 1, parts.count, part)
    }
  }
}
#endif
