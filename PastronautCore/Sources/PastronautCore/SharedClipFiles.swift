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
  var inboxURL: URL { directory.appending(path: "inbox.json") }

  // MARK: - Snapshot

  public func writeSnapshot(_ clips: [Clip]) throws {
    try coordinatedWrite(to: snapshotURL) { url in
      try encode(clips, to: url)
    }
  }

  public func readSnapshot() -> [Clip] {
    (try? coordinatedRead(snapshotURL, decode: [Clip].self)) ?? []
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
