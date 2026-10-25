import CloudKit
import Foundation
import os

/// The keyboard's own view of iCloud, kept in the App Group as `keyboard-cache.json`.
///
/// Written only by the keyboard. A full fetch replaces the clips; later fetches apply changes since `token`.
public struct KeyboardCache: Codable, Equatable, Sendable {
  public var clips: [Clip] = []
  public var collections: [ClipCollection] = []
  /// Archived `CKServerChangeToken` of the last fetch; nil means the next fetch is a full one.
  public var token: Data?
  public var fetchedAt: Date?
  /// The zone `token` belongs to. A cache from the original zone starts over with a full fetch.
  public var zone: String?
  /// Since 1.3: the fetch reads images, PDFs and files too (not their files). A cache from before starts over.
  public var includesMedia = false

  public init(clips: [Clip] = [], collections: [ClipCollection] = [], token: Data? = nil, fetchedAt: Date? = nil) {
    self.clips = clips
    self.collections = collections
    self.token = token
    self.fetchedAt = fetchedAt
    self.zone = ClipRecord.zoneName
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    clips = try container.decodeIfPresent([Clip].self, forKey: .clips) ?? []
    collections = try container.decodeIfPresent([ClipCollection].self, forKey: .collections) ?? []
    token = try container.decodeIfPresent(Data.self, forKey: .token)
    fetchedAt = try container.decodeIfPresent(Date.self, forKey: .fetchedAt)
    zone = try container.decodeIfPresent(String.self, forKey: .zone)
    includesMedia = try container.decodeIfPresent(Bool.self, forKey: .includesMedia) ?? false
  }

  /// Applies one fetch. A full fetch is the whole zone, so clips it does not mention are gone.
  public mutating func apply(
    fetched: [Clip],
    deletedIDs: [String],
    fetchedCollections: [ClipCollection] = [],
    deletedCollectionIDs: [String] = [],
    isFullFetch: Bool,
    token: Data?,
    at date: Date
  ) {
    var byID = isFullFetch ? [:] : Dictionary(clips.map { ($0.id, $0) }, uniquingKeysWith: { $0.merged(with: $1) })
    for clip in fetched {
      byID[clip.id] = byID[clip.id].map { $0.merged(with: clip) } ?? clip
    }
    for id in deletedIDs {
      byID[id] = nil
    }
    clips = Array(byID.values)

    var collectionsByID = isFullFetch ? [:] : Dictionary(collections.map { ($0.id, $0) }, uniquingKeysWith: { $0.merged(with: $1) })
    for collection in fetchedCollections {
      collectionsByID[collection.id] = collectionsByID[collection.id].map { $0.merged(with: collection) } ?? collection
    }
    for id in deletedCollectionIDs {
      collectionsByID[id] = nil
    }
    collections = collectionsByID.values.ordered

    self.token = token
    zone = ClipRecord.zoneName
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

  /// The account's record-name key: the app's copy in the App Group, or read from iCloud when the app has not
  /// synced since it was updated.
  private func currentKey() async throws -> SyncKey {
    let file = SyncKeyFile(directory: files.directory)
    if let key = file.read() { return key }
    let (key, _) = try await SettingsRecord.fetchOrCreateKey(in: database)
    file.write(key)
    return key
  }

  /// Fetches changes since the last call and stores them in the keyboard cache.
  @discardableResult
  public func refresh() async throws -> KeyboardCache {
    var cache = files.readKeyboardCache() ?? KeyboardCache()
    if cache.zone != ClipRecord.zoneName || !cache.includesMedia {
      cache.token = nil
    }
    let key = try? await currentKey()
    var token = cache.token.flatMap {
      try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0)
    }
    let isFullFetch = token == nil
    var fetched: [Clip] = []
    var fetchedCollections: [ClipCollection] = []
    var deletedNames: [String] = []
    var moreComing = true
    do {
      while moreComing {
        // Never the media files: a full fetch would bring every picture in iCloud into the keyboard.
        let changes = try await database.recordZoneChanges(
          inZoneWith: ClipRecord.zoneID, since: token, desiredKeys: ClipSync.catchUpKeys
        )
        for (_, result) in changes.modificationResultsByID {
          guard case .success(let modification) = result else { continue }
          let record = modification.record
          if let clip = ClipRecord.clip(from: record), key.map({ ClipRecord.isNamed(record, for: clip, key: $0) }) ?? true {
            fetched.append(clip)
          } else if let clip = MediaRecord.clip(from: record),
                    key.map({ ClipRecord.isNamed(record, for: clip, key: $0) }) ?? true {
            // A picture from the Mac shows here before the app has run: its thumbnail travels in the record.
            fetched.append(clip)
            if store.thumbnail(for: clip.id) == nil, let thumbnail = MediaRecord.thumbnail(of: record) {
              try? store.storeThumbnail(thumbnail, for: clip.id)
            }
          } else if let collection = CollectionRecord.collection(from: record) {
            fetchedCollections.append(collection)
          }
        }
        deletedNames += changes.deletions.map(\.recordID.recordName)
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

    // Deletions only carry record names; map them back through the key.
    var idsByName: [String: String] = [:]
    if let key {
      for clip in cache.clips + fetched {
        idsByName[key.recordName(forClipID: clip.id)] = clip.id
      }
    }
    let archived = token.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
    cache.apply(
      fetched: fetched,
      deletedIDs: deletedNames.compactMap { idsByName[$0] },
      fetchedCollections: fetchedCollections,
      deletedCollectionIDs: deletedNames.filter(ClipCollection.isValidID),
      isFullFetch: isFullFetch,
      token: archived,
      at: .now
    )
    cache.includesMedia = true
    try files.writeKeyboardCache(cache)
    logger.notice("Keyboard fetched \(fetched.count) changes, \(deletedNames.count) deletions (full: \(isFullFetch))")
    return cache
  }

  /// The largest image, PDF or files the keyboard downloads itself: decrypting holds them in memory, and iOS stops
  /// a keyboard at about 60 MB. Larger ones wait for the app.
  public static let maxDownloadBytes = 15 * MediaSettings.megabyte

  private var store: MediaStore { MediaStore(storageDirectory: files.directory) }

  /// Downloads a media clip's files from iCloud into the app's media store (the app then needs not fetch them).
  /// False when too large, not in iCloud or not readable.
  public func downloadFiles(of clip: Clip) async -> Bool {
    guard let media = clip.media, media.totalBytes <= Self.maxDownloadBytes else { return false }
    if store.hasFiles(for: clip) { return true }
    guard let key = try? await currentKey() else { return false }
    let recordID = ClipRecord.recordID(forClipID: clip.id, key: key)
    guard let result = try? await database.records(for: [recordID], desiredKeys: [MediaRecord.filesField])[recordID],
          case .success(let record) = result, let urls = MediaRecord.encryptedFileURLs(of: record) else {
      logger.error("Keyboard could not download the files of a media clip")
      return false
    }
    return store.storeDownloaded(urls, for: clip, cipher: MediaCipher(syncKey: key))
  }

  /// Saves a captured clip straight to iCloud, merging with the server copy if the clip already exists.
  public func save(_ clip: Clip) async throws {
    // A capture knows nothing about pins: keep the server's.
    try await save(clip, updatingCache: true) { remote, local in remote.copiedAgain(local) }
  }

  /// Saves a capture from an extension (keyboard, Share): the inbox first, so the app sends it later if the
  /// upload fails, then straight to iCloud. Returns whether the upload worked.
  ///
  /// The keyboard (`keepsInInbox` false) then drops the inbox entry and adds the clip to its cache. The Share
  /// extension keeps it in the inbox instead: the keyboard and widgets show it from there until the app takes it,
  /// and the cache keeps a single writer, the keyboard.
  @discardableResult
  public func capture(_ clip: Clip, keepsInInbox: Bool = false) async -> Bool {
    try? files.appendToInbox(clip)
    // Kept on this iPhone (Settings › Privacy): the app takes it from the inbox as a local-only clip.
    guard PrivacyOptions.onPhone(in: SharedSettings.defaults).allows(clip.text, pinned: false) else { return true }
    do {
      try await save(clip, updatingCache: !keepsInInbox) { remote, local in remote.copiedAgain(local) }
      if !keepsInInbox {
        try? files.removeFromInbox(id: clip.id)
      }
      return true
    } catch {
      logger.error("Capture upload failed: \(String(describing: error), privacy: .public)")
      return false
    }
  }

  /// Puts a just-shared clip in a collection: in the inbox (so the app applies it if this upload fails) and in
  /// iCloud. On a conflict only the membership is added to what the server has, so its pin and title stay.
  public func addToCollection(_ clip: Clip, collectionID: String) async throws {
    var member = clip
    member.collectionIDs.append(collectionID)
    member.modifiedAt = .now
    try? files.appendToInbox(member)
    guard PrivacyOptions.onPhone(in: SharedSettings.defaults).allows(clip.text, pinned: false) else { return }
    try await save(member, updatingCache: false) { remote, local in
      var merged = remote
      merged.collectionIDs.append(collectionID)
      merged.modifiedAt = max(remote.modifiedAt, local.modifiedAt)
      return merged
    }
  }

  /// Pins or unpins a clip from the keyboard. The newer change wins, as everywhere else.
  public func setPinned(_ pinned: Bool, for clip: Clip) async throws {
    var changed = clip
    changed.pinned = pinned
    changed.modifiedAt = .now
    try await save(changed, updatingCache: true) { remote, local in remote.merged(with: local) }
  }

  /// Deletes a clip for every device. A clip already gone from iCloud counts as deleted.
  public func delete(id: String) async throws {
    let recordID = ClipRecord.recordID(forClipID: id, key: try await currentKey())
    let result = try await database.modifyRecords(saving: [], deleting: [recordID])
    if case .failure(let error)? = result.deleteResults[recordID], (error as? CKError)?.code != .unknownItem {
      throw error
    }
    var cache = files.readKeyboardCache() ?? KeyboardCache()
    cache.clips.removeAll { $0.id == id }
    try? files.writeKeyboardCache(cache)
  }

  private func save(
    _ clip: Clip,
    updatingCache: Bool,
    onConflict merge: (_ remote: Clip, _ local: Clip) -> Clip
  ) async throws {
    guard policy.isEligible(clip.text) else { throw SaveError.notEligible }
    var clip = clip
    var base: CKRecord?
    var key = try await currentKey()
    for _ in 0..<3 {
      let record = ClipRecord.record(for: clip, key: key, updating: base)
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
        if updatingCache {
          var cache = files.readKeyboardCache() ?? KeyboardCache()
          cache.insert(clip)
          try? files.writeKeyboardCache(cache)
        }
        logger.notice("Saved a clip directly")
        return
      case .failure(let error as CKError) where error.code == .serverRecordChanged:
        guard let server = error.serverRecord, let remote = ClipRecord.clip(from: server) else { throw error }
        clip = merge(remote, clip)
        base = server
      case .failure(let error as CKError) where error.code == .zoneNotFound:
        // iCloud data was deleted, and the key with it: start over with a new one (this creates the zone).
        SyncKeyFile(directory: files.directory).write(nil)
        key = try await currentKey()
        base = nil
      case .failure(let error):
        throw error
      }
    }
    throw SaveError.gaveUp
  }
}
