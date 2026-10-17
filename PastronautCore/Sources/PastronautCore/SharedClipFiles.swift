import Foundation

/// Identifiers shared by the Mac app, the iOS app and the keyboard extension.
public enum PastronautIDs {
  public static let iCloudContainer = "iCloud.com.xkbxyberk.pastronaut"
  public static let appGroup = "group.com.xkbxyberk.pastronaut"
}

/// Files the iOS app and its keyboard extension exchange through the App Group container.
///
/// - `clips.json`: snapshot of the synced history, written only by the app, read by the keyboard.
///   The keyboard can read the App Group without Full Access (verified in Faz 0).
/// - `inbox.json`: clips captured by the keyboard (requires Full Access to write), drained by the app,
///   which then hands them to `ClipSync`. Separate files keep each one single-writer except the inbox,
///   which is guarded with `NSFileCoordinator` across processes.
/// Settings and signals shared through the App Group's user defaults by the app and its extensions.
public enum SharedSettings {
  public static var defaults: UserDefaults? { UserDefaults(suiteName: PastronautIDs.appGroup) }
  /// Bool. Face ID (or the passcode) to open the app; widgets then hide clip text.
  public static let appLockKey = "appLockEnabled"
  /// Bool. Set by the "Save Clipboard" control; the app saves the clipboard when it comes to the front.
  public static let pendingClipboardSaveKey = "pendingClipboardSave"
  /// String and Date. The clip a widget button just copied, for a brief check mark.
  public static let widgetCopiedIDKey = "widgetCopiedID"
  public static let widgetCopiedAtKey = "widgetCopiedAt"

  public static var isAppLockEnabled: Bool { defaults?.bool(forKey: appLockKey) ?? false }

  /// Date. Debug builds only: while the app shows made-up clips for screenshots, the keyboard shows them too
  /// (no iCloud fetch, English) until this time.
  public static let demoUntilKey = "demoUntil"
  public static var isDemo: Bool { (defaults?.object(forKey: demoUntilKey) as? Date).map { $0 > .now } ?? false }
}

public struct SharedClipFiles: Sendable {
  public let directory: URL

  public init(directory: URL) {
    self.directory = directory
  }

  /// nil when the App Group container is unavailable.
  public init?(appGroup: String = PastronautIDs.appGroup) {
    guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
      return nil
    }
    // Under Library/ so `devicectl device copy from` can fetch it while debugging.
    self.init(directory: container.appending(path: "Library/Pastronaut"))
  }

  var snapshotURL: URL { directory.appending(path: "clips.json") }
  var collectionsURL: URL { directory.appending(path: "collections.json") }
  var inboxURL: URL { directory.appending(path: "inbox.json") }

  // MARK: - Snapshot

  public func writeSnapshot(_ clips: [Clip]) throws {
    try coordinatedWrite(to: snapshotURL) { url in
      try encode(clips, to: url)
    }
  }

  /// Plain read, no file coordination: without Full Access the keyboard cannot use file coordination
  /// and a coordinated read returned nothing (found by the end-to-end test). The snapshot is always
  /// replaced atomically, so a reader sees either the old or the new file, never half of one.
  public func readSnapshot() -> [Clip] {
    (try? decode([Clip].self, from: snapshotURL)) ?? []
  }

  /// What the keyboard, widgets and Shortcuts show: the app's snapshot, or the keyboard's own fetch when that
  /// is newer, plus captures still waiting in the inbox. `useKeyboardCache` is false for a keyboard without
  /// Full Access, whose cache can't be trusted to be current.
  public func currentClips(useKeyboardCache: Bool = true) -> [Clip] {
    var base = readSnapshot()
    if useKeyboardCache, let cache = readKeyboardCache(), let fetchedAt = cache.fetchedAt,
       fetchedAt > snapshotDate ?? .distantPast {
      base = cache.clips
    }
    var byID: [String: Clip] = [:]
    for clip in base + readInbox() {
      byID[clip.id] = byID[clip.id].map { $0.merged(with: clip) } ?? clip
    }
    return byID.values.inHistoryOrder
  }

  // MARK: - Collections

  /// Written by the app next to the snapshot, in list order.
  public func writeCollections(_ collections: [ClipCollection]) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try encode(collections, to: collectionsURL)
  }

  /// The app's list, or the keyboard's own fetch when that is newer (same rule as `currentClips`).
  public func currentCollections(useKeyboardCache: Bool = true) -> [ClipCollection] {
    let snapshot = (try? decode([ClipCollection].self, from: collectionsURL)) ?? []
    if useKeyboardCache, let cache = readKeyboardCache(), let fetchedAt = cache.fetchedAt,
       fetchedAt > snapshotDate ?? .distantPast {
      return cache.collections
    }
    return snapshot.ordered
  }

  // MARK: - Keyboard cache

  var keyboardCacheURL: URL { directory.appending(path: "keyboard-cache.json") }

  /// Written only by the keyboard (with Full Access); plain atomic file I/O like the snapshot.
  public func readKeyboardCache() -> KeyboardCache? {
    try? decode(KeyboardCache.self, from: keyboardCacheURL)
  }

  public func writeKeyboardCache(_ cache: KeyboardCache) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try encode(cache, to: keyboardCacheURL)
  }

  /// When the app last wrote the snapshot; lets the keyboard pick the fresher of snapshot and cache.
  public var snapshotDate: Date? {
    (try? FileManager.default.attributesOfItem(atPath: snapshotURL.path))?[.modificationDate] as? Date
  }

  // MARK: - Inbox

  /// Adds a captured clip unless the inbox already holds the same content.
  public func appendToInbox(_ clip: Clip) throws {
    try coordinatedWrite(to: inboxURL) { url in
      var inbox = (try? decode([Clip].self, from: url)) ?? []
      if let index = inbox.firstIndex(where: { $0.id == clip.id }) {
        inbox[index] = inbox[index].merged(with: clip)
      } else {
        inbox.append(clip)
      }
      try encode(inbox, to: url)
    }
  }

  public func readInbox() -> [Clip] {
    (try? coordinatedRead(inboxURL, decode: [Clip].self)) ?? []
  }

  /// Drops a capture the keyboard already saved to iCloud itself.
  public func removeFromInbox(id: String) throws {
    try coordinatedWrite(to: inboxURL) { url in
      guard var inbox = try? decode([Clip].self, from: url) else { return }
      inbox.removeAll { $0.id == id }
      try encode(inbox, to: url)
    }
  }

  /// Returns and removes everything in the inbox in one coordinated step.
  public func drainInbox() throws -> [Clip] {
    var drained: [Clip] = []
    try coordinatedWrite(to: inboxURL) { url in
      drained = (try? decode([Clip].self, from: url)) ?? []
      if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
      }
    }
    return drained
  }

  // MARK: - Coordination

  private func coordinatedWrite(to url: URL, _ body: (URL) throws -> Void) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var coordinationError: NSError?
    var bodyError: Error?
    NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { url in
      do { try body(url) } catch { bodyError = error }
    }
    if let error = coordinationError ?? bodyError { throw error }
  }

  private func coordinatedRead<T: Decodable>(_ url: URL, decode type: T.Type) throws -> T? {
    var coordinationError: NSError?
    var result: T?
    var bodyError: Error?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
      do { result = try decode(type, from: url) } catch { bodyError = error }
    }
    if let error = coordinationError ?? bodyError { throw error }
    return result
  }

  private func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try JSONDecoder().decode(type, from: Data(contentsOf: url))
  }

  private func encode(_ value: some Encodable, to url: URL) throws {
    try JSONEncoder().encode(value).write(to: url, options: .atomic)
  }
}

public extension Collection<Clip> {
  /// Pinned first, then most recently copied.
  var inHistoryOrder: [Clip] {
    sorted { lhs, rhs in
      lhs.pinned != rhs.pinned ? lhs.pinned : lhs.lastCopiedAt > rhs.lastCopiedAt
    }
  }
}
