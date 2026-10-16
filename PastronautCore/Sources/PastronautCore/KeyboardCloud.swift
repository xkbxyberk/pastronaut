import CloudKit
import Foundation
import os

/// The keyboard's own view of iCloud, kept in the App Group as `keyboard-cache.json`.
///
/// Written only by the keyboard. A full fetch replaces the clips; later fetches apply changes since `token`.
public struct KeyboardCache: Codable, Equatable, Sendable {
  public var clips: [Clip] = []
  /// Archived `CKServerChangeToken` of the last fetch; nil means the next fetch is a full one.
  public var token: Data?
  public var fetchedAt: Date?

  public init(clips: [Clip] = [], token: Data? = nil, fetchedAt: Date? = nil) {
    self.clips = clips
    self.token = token
    self.fetchedAt = fetchedAt
  }

  /// Applies one fetch. A full fetch is the whole zone, so clips it does not mention are gone.
  public mutating func apply(fetched: [Clip], deletedIDs: [String], isFullFetch: Bool, token: Data?, at date: Date) {
    var byID = isFullFetch ? [:] : Dictionary(clips.map { ($0.id, $0) }, uniquingKeysWith: { $0.merged(with: $1) })
    for clip in fetched {
      byID[clip.id] = byID[clip.id].map { $0.merged(with: clip) } ?? clip
    }
    for id in deletedIDs {
      byID[id] = nil
    }
    clips = Array(byID.values)
    self.token = token
    fetchedAt = date
  }

  /// Adds a clip this keyboard saved, so it shows before the next fetch.
  public mutating func insert(_ clip: Clip) {
    if let index = clips.firstIndex(where: { $0.id == clip.id }) {
      clips[index] = clips[index].merged(with: clip)
    } else {
      clips.append(clip)
    }
  }
}

/// Direct CloudKit access for the keyboard extension, which needs Full Access for the network.
///
/// The app's `ClipSync` (CKSyncEngine) stays the only engine; a second engine sharing its state would
/// corrupt it. The keyboard only reads the clips zone with its own change token and saves single
/// records, so the Mac sees a capture without the app being opened. The app picks the saved record up
/// on its next fetch like any other remote change.
public actor KeyboardCloud {
  public enum SaveError: Error {
    case notEligible
    case gaveUp
  }

  private let database: CKDatabase
  private let files: SharedClipFiles
  private let policy: SyncPolicy
  private let logger = Logger(subsystem: "com.xkbxyberk.pastronaut", category: "KeyboardCloud")

  public init(containerIdentifier: String, files: SharedClipFiles, policy: SyncPolicy = .default) {
    self.database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
    self.files = files
    self.policy = policy
  }

  /// Fetches changes since the last call and stores them in the keyboard cache.
  @discardableResult
  public func refresh() async throws -> KeyboardCache {
    var cache = files.readKeyboardCache() ?? KeyboardCache()
    var token = cache.token.flatMap {
      try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0)
    }
    let isFullFetch = token == nil
    var fetched: [Clip] = []
    var deleted: [String] = []
    var moreComing = true
    do {
      while moreComing {
        let changes = try await database.recordZoneChanges(inZoneWith: ClipRecord.zoneID, since: token)
        for (_, result) in changes.modificationResultsByID {
          if case .success(let modification) = result, let clip = ClipRecord.clip(from: modification.record) {
            fetched.append(clip)
          }
        }
        deleted += changes.deletions.map(\.recordID.recordName)
        token = changes.changeToken
        moreComing = changes.moreComing
      }
    } catch let error as CKError where error.code == .changeTokenExpired && !isFullFetch {
      cache.token = nil
      try files.writeKeyboardCache(cache)
      return try await refresh()
    } catch let error as CKError where error.code == .zoneNotFound {
      // iCloud data was deleted or nothing was ever synced.
      cache = KeyboardCache(fetchedAt: .now)
      try files.writeKeyboardCache(cache)
      return cache
    }

    let archived = token.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
    cache.apply(fetched: fetched, deletedIDs: deleted, isFullFetch: isFullFetch, token: archived, at: .now)
    try files.writeKeyboardCache(cache)
    logger.notice("Keyboard fetched \(fetched.count) changes, \(deleted.count) deletions (full: \(isFullFetch))")
    return cache
  }

  /// Saves a captured clip straight to iCloud, merging with the server copy if the clip already exists.
  public func save(_ clip: Clip) async throws {
    guard policy.isEligible(clip.text) else { throw SaveError.notEligible }
    var clip = clip
    var base: CKRecord?
    for _ in 0..<3 {
      let record = ClipRecord.record(for: clip, updating: base)
      let result: Result<CKRecord, Error>
      do {
        // Per-record failures are returned, not thrown (learned in Faz 0).
        let saved = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
        result = saved.saveResults[record.recordID] ?? .failure(CKError(.internalError))
      } catch {
        result = .failure(error)
      }
      switch result {
      case .success:
        var cache = files.readKeyboardCache() ?? KeyboardCache()
        cache.insert(clip)
        try? files.writeKeyboardCache(cache)
        logger.notice("Keyboard saved a clip directly")
        return
      case .failure(let error as CKError) where error.code == .serverRecordChanged:
        // Same text already in iCloud: keep its pin, record this copy.
        guard let server = error.serverRecord, let remote = ClipRecord.clip(from: server) else { throw error }
        clip = remote.copiedAgain(clip)
        base = server
      case .failure(let error as CKError) where error.code == .zoneNotFound:
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: ClipRecord.zoneID)], deleting: [])
      case .failure(let error):
        throw error
      }
    }
    throw SaveError.gaveUp
  }
}
