import AppKit
import Defaults
import Logging
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

  /// Call once after History has loaded. Follows the setting for the rest of the session.
  func start() {
    guard observation == nil else { return }
    observation = Task { [weak self] in
      for await enabled in Defaults.updates(.iCloudSync) {
        await self?.setEnabled(enabled)
      }
    }
  }

  private func setEnabled(_ enabled: Bool) async {
    if enabled {
      await sync.setChangeHandler { changes in
        await SyncBridge.shared.apply(changes)
      }
      await sync.start()
      uploadExistingHistory()
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
