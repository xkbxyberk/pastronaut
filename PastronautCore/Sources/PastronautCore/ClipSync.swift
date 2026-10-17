import CloudKit
import CryptoKit
import Foundation
import os

/// A clip or collection that changed because of another device.
public enum ClipChange: Equatable, Sendable {
  case upserted(Clip)
  case deleted(id: String)
  case collectionUpserted(ClipCollection)
  case collectionDeleted(id: String)
}

public struct SyncStatus: Equatable, Sendable {
  public var isRunning: Bool
  public var syncedClips: Int
  public var lastSyncAt: Date?
  public var lastError: String?
  /// Records are named with the account's key (see `SyncKey`); false until the first sync reached iCloud.
  public var hasKey: Bool
  /// Clips may still be waiting in the original zone.
  public var isMovingOldClips: Bool
  /// The original zone was found empty or deleted.
  public var oldZoneCleared: Bool
}

/// Two-way sync of clips and collections with the user's private iCloud database, built on CKSyncEngine.
///
/// Keeps a small mirror of every synced clip (with the server's system fields) next to the app's own
/// storage, so the app's history model stays untouched. Callers report local changes with `upsert`
/// and `delete`; remote changes arrive through the change handler.
///
/// Clips are mirrored by their local ID (`Clip.id`, a hash of the text). In iCloud their records are named with
/// the account's key instead (`SyncKey`), which every device reads from the settings record before it sends
/// anything. Version 1 kept clips in another zone under their plain hash; `syncNow` moves those and then
/// deletes that zone, in the background.
public actor ClipSync {
  public typealias ChangeHandler = @Sendable ([ClipChange]) async -> Void

  struct MirrorEntry: Codable {
    var clip: Clip
    /// Archived system fields of the last known server record; nil until first saved or fetched.
    var systemFields: Data?
  }

  struct CollectionEntry: Codable {
    var collection: ClipCollection
    var systemFields: Data?
  }

  struct PersistedState: Codable {
    static let currentSchema = 2

    /// By clip ID (`Clip.id`), not by record name.
    var entries: [String: MirrorEntry] = [:]
    var collections: [String: CollectionEntry] = [:]
    var engineState: CKSyncEngine.State.Serialization?
    /// Archived change token of our own zone fetch (see `catchUp`). Separate from the engine's tokens.
    var catchUpToken: Data?
    var key: SyncKey?
    /// 2 since clips moved to the "Library" zone; files written before have none.
    var schema = PersistedState.currentSchema
    /// The original zone may still hold clips. Cleared once it is gone.
    var needsLegacyCleanup = true
    /// Clips deleted here while the original zone still existed, so moving it doesn't bring them back.
    var legacyTombstones: Set<String> = []

    init() {}

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      entries = try container.decodeIfPresent([String: MirrorEntry].self, forKey: .entries) ?? [:]
      collections = try container.decodeIfPresent([String: CollectionEntry].self, forKey: .collections) ?? [:]
      engineState = try container.decodeIfPresent(CKSyncEngine.State.Serialization.self, forKey: .engineState)
      catchUpToken = try container.decodeIfPresent(Data.self, forKey: .catchUpToken)
      key = try container.decodeIfPresent(SyncKey.self, forKey: .key)
      schema = try container.decodeIfPresent(Int.self, forKey: .schema) ?? 1
      needsLegacyCleanup = try container.decodeIfPresent(Bool.self, forKey: .needsLegacyCleanup) ?? true
      legacyTombstones = try container.decodeIfPresent(Set<String>.self, forKey: .legacyTombstones) ?? []
    }
  }

  private let container: CKContainer
  private let fileURL: URL
  private let keyFile: SyncKeyFile
  private let policy: SyncPolicy
  private var state: PersistedState
  /// Record name → clip ID for the current key. Not stored; rebuilt from the mirror.
  private var clipIDsByRecordName: [String: String] = [:]
  /// The original zone was read during this session, so its clips are in the mirror.
  private var movedLegacyClips = false
  private var engine: CKSyncEngine?
  private var changeHandler: ChangeHandler?
  private var lastSyncAt: Date?
  private var lastError: String?
  private let logger = Logger(subsystem: "com.xkbxyberk.pastronaut", category: "ClipSync")

  public init(containerIdentifier: String, storageDirectory: URL, policy: SyncPolicy = .default) {
    self.container = CKContainer(identifier: containerIdentifier)
    self.fileURL = storageDirectory.appending(path: "clip-sync.json")
    self.keyFile = SyncKeyFile(directory: storageDirectory)
    self.policy = policy
    let state = Self.load(from: fileURL)
    self.state = state
    if let key = state.key {
      clipIDsByRecordName = Self.recordNames(for: state.entries.keys, key: key)
    }
  }

  public func setChangeHandler(_ handler: ChangeHandler?) {
    changeHandler = handler
  }

  public var status: SyncStatus {
    SyncStatus(
      isRunning: engine != nil,
      syncedClips: state.entries.count,
      lastSyncAt: lastSyncAt,
      lastError: lastError,
      hasKey: state.key != nil,
      isMovingOldClips: state.needsLegacyCleanup && movedLegacyClips,
      oldZoneCleared: !state.needsLegacyCleanup
    )
  }

  public var clips: [Clip] {
    state.entries.values.map(\.clip)
  }

  public func clip(withID id: String) -> Clip? {
    state.entries[id]?.clip
  }

  public var collections: [ClipCollection] {
    state.collections.values.map(\.collection).ordered
  }

  #if DEBUG
  /// For the end-to-end test: the name a clip has in iCloud.
  public func recordName(forClipID id: String) -> String? {
    state.key?.recordName(forClipID: id)
  }

  /// For the end-to-end test: a short hash of the key, to see that two devices share it.
  public var keyFingerprint: String? {
    state.key.map { SHA256.hash(data: $0.data).prefix(8).map { String(format: "%02x", $0) }.joined() }
  }
  #endif

  // MARK: - Lifecycle

  public func start() {
    guard engine == nil else { return }
    let configuration = CKSyncEngine.Configuration(
      database: container.privateCloudDatabase,
      stateSerialization: state.engineState,
      delegate: self
    )
    let engine = CKSyncEngine(configuration)
    self.engine = engine
    if state.engineState == nil {
      engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: ClipRecord.zoneID))])
    }
    if state.schema < PersistedState.currentSchema {
      prepareMove(engine: engine)
    }
    logger.notice("Started with \(self.state.entries.count) mirrored clips, \(self.state.collections.count) collections")
  }

  /// Stops syncing and forgets the local mirror. iCloud data and local history are left untouched.
  public func stop() {
    engine = nil
    state = PersistedState()
    clipIDsByRecordName = [:]
    keyFile.write(nil)
    persist()
  }

  /// Deletes the clips zone (and the original one, if still there) from iCloud for every device, then stops.
  public func deleteCloudData() async throws {
    guard let engine else { return }
    engine.state.add(pendingDatabaseChanges: [.deleteZone(ClipRecord.zoneID)])
    try await engine.sendChanges()
    _ = try? await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [ClipRecord.legacyZoneID])
    stop()
  }

  /// Fetches and sends now. Call at launch, on foreground, on push and from a periodic fallback.
  public func syncNow() async throws {
    guard let engine else { return }
    try await ensureKey(engine: engine)
    if state.needsLegacyCleanup {
      try await moveLegacyClips(engine: engine)
    }
    try await engine.fetchChanges()
    try await catchUp(syncEngine: engine)
    try await engine.sendChanges()
    await deleteLegacyZoneIfDone(engine: engine)
  }

  /// Uploads pending changes now instead of waiting for the engine's own schedule, which runs a few
  /// seconds later and never runs if iOS suspends the app first.
  public func sendNow() async throws {
    guard let engine, state.key != nil else { return }
    try await engine.sendChanges()
  }

  /// Fetches our zone directly with our own change token.
  ///
  /// CKSyncEngine only fetches zones it was told changed, and it learns that from pushes. When a push is
  /// lost (observed on macOS: apsd drops CloudKit pushes for an "unknown token") the engine logs "no zone
  /// IDs needing to be fetched" for every fetch, so launch, manual sync and polling never see changes,
  /// even with an explicit zone scope. Changes found here go through the same merge as the engine's, so
  /// seeing a change twice is harmless.
  private func catchUp(syncEngine: CKSyncEngine) async throws {
    var token = state.catchUpToken.flatMap {
      try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0)
    }
    let isFullFetch = token == nil
    var records: [CKRecord] = []
    var deletions: [CKRecord.ID] = []
    var moreComing = true
    do {
      while moreComing {
        let changes = try await container.privateCloudDatabase.recordZoneChanges(
          inZoneWith: ClipRecord.zoneID, since: token
        )
        for (_, result) in changes.modificationResultsByID {
          if case .success(let modification) = result { records.append(modification.record) }
        }
        deletions += changes.deletions.map(\.recordID)
        token = changes.changeToken
        moreComing = changes.moreComing
      }
    } catch let error as CKError where error.code == .changeTokenExpired {
      state.catchUpToken = nil
      persist()
      return try await catchUp(syncEngine: syncEngine)
    } catch let error as CKError where error.code == .zoneNotFound {
      // Nothing uploaded yet, or iCloud data was deleted; the engine handles both.
      return
    }

    if isFullFetch, let key = state.key {
      // A full fetch reports no deletions. What this device saw on the server that is gone now, and is not
      // waiting to be uploaded again, was deleted elsewhere.
      let onServer = Set(records.map(\.recordID.recordName))
      let pendingSaves = Set(syncEngine.state.pendingRecordZoneChanges.compactMap { change -> String? in
        if case .saveRecord(let id) = change { return id.recordName }
        return nil
      })
      let gone: (String) -> Bool = { !onServer.contains($0) && !pendingSaves.contains($0) }
      deletions += state.entries
        .filter { $0.value.systemFields != nil }
        .map { key.recordName(forClipID: $0.key) }
        .filter(gone)
        .map { CKRecord.ID(recordName: $0, zoneID: ClipRecord.zoneID) }
      deletions += state.collections
        .filter { $0.value.systemFields != nil && gone($0.key) }
        .map { CollectionRecord.recordID(for: $0.key) }
    }

    state.catchUpToken = token.flatMap {
      try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
    }
    await apply(modifications: records, deletions: deletions, syncEngine: syncEngine, source: "catch-up")
  }

  // MARK: - Record-name key

  /// Reads (or creates) the account's key before anything is sent, so every record gets its private name.
  private func ensureKey(engine: CKSyncEngine) async throws {
    guard state.key == nil else { return }
    let (key, created) = try await SettingsRecord.fetchOrCreateKey(in: container.privateCloudDatabase)
    logger.notice("\(created ? "Created" : "Fetched", privacy: .public) the record-name key")
    adopt(key, engine: engine)
  }

  /// Starts using `key`. Everything not yet in iCloud under it is queued. A different key than before means
  /// another device recreated the zone (after iCloud data was deleted): records saved under the old key are
  /// renamed.
  private func adopt(_ key: SyncKey, engine: CKSyncEngine) {
    guard key != state.key else { return }
    if let previous = state.key {
      logger.notice("The record-name key changed; renaming \(self.state.entries.count) clips")
      let staleSaves = engine.state.pendingRecordZoneChanges.filter {
        if case .saveRecord(let id) = $0 { return Self.isClipRecordName(id.recordName) }
        return false
      }
      engine.state.remove(pendingRecordZoneChanges: staleSaves)
      let oldRecords = state.entries.filter { $0.value.systemFields != nil }.keys.map {
        CKRecord.ID(recordName: previous.recordName(forClipID: $0), zoneID: ClipRecord.zoneID)
      }
      engine.state.add(pendingRecordZoneChanges: oldRecords.map { .deleteRecord($0) })
      for id in state.entries.keys {
        state.entries[id]?.systemFields = nil
      }
    }
    state.key = key
    keyFile.write(key)
    clipIDsByRecordName = Self.recordNames(for: state.entries.keys, key: key)
    let unsent = state.entries.filter { $0.value.systemFields == nil }.keys.map {
      ClipRecord.recordID(forClipID: $0, key: key)
    }
    let unsentCollections = state.collections.filter { $0.value.systemFields == nil }.keys.map {
      CollectionRecord.recordID(for: $0)
    }
    engine.state.add(pendingRecordZoneChanges: (unsent + unsentCollections).map { .saveRecord($0) })
    persist()
  }

  private static func recordNames(for clipIDs: some Sequence<String>, key: SyncKey) -> [String: String] {
    Dictionary(clipIDs.map { (key.recordName(forClipID: $0), $0) }, uniquingKeysWith: { first, _ in first })
  }

  static func isClipRecordName(_ name: String) -> Bool {
    name.hasPrefix("c-")
  }

  /// The record for a clip under the current key; nil until the key is known.
  private func recordID(forClipID id: String) -> CKRecord.ID? {
    guard let key = state.key else { return nil }
    let recordID = ClipRecord.recordID(forClipID: id, key: key)
    clipIDsByRecordName[recordID.recordName] = id
    return recordID
  }

  // MARK: - Moving clips out of the original zone

  /// Version 1 mirrored records of the original zone; their system fields mean nothing in the new one, and
  /// changes the engine had not sent yet name records there. Clips stay in the mirror and are sent again
  /// once the key is known.
  private func prepareMove(engine: CKSyncEngine) {
    logger.notice("Moving \(self.state.entries.count) clips to the \(ClipRecord.zoneName, privacy: .public) zone")
    let backup = fileURL.deletingLastPathComponent().appending(path: "clip-sync-v1.json")
    if !FileManager.default.fileExists(atPath: backup.path) {
      try? FileManager.default.copyItem(at: fileURL, to: backup)
    }
    let legacyChanges = engine.state.pendingRecordZoneChanges.filter { $0.recordID?.zoneID != ClipRecord.zoneID }
    for case .deleteRecord(let id) in legacyChanges {
      // Deleted here but not sent yet: must not come back from the old zone.
      state.legacyTombstones.insert(id.recordName)
    }
    engine.state.remove(pendingRecordZoneChanges: legacyChanges)
    let legacyZoneChanges = engine.state.pendingDatabaseChanges.filter { $0.zoneID == ClipRecord.legacyZoneID }
    engine.state.remove(pendingDatabaseChanges: legacyZoneChanges)
    engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: ClipRecord.zoneID))])
    for id in state.entries.keys {
      state.entries[id]?.systemFields = nil
    }
    state.catchUpToken = nil
    state.needsLegacyCleanup = true
    state.schema = PersistedState.currentSchema
    persist()
  }

  /// Reads every clip still in the original zone (left by version 1, or by a device that has not updated yet)
  /// and queues it for the new zone. The old zone is deleted later, once these reached iCloud.
  private func moveLegacyClips(engine: CKSyncEngine) async throws {
    var records: [CKRecord] = []
    var token: CKServerChangeToken?
    var moreComing = true
    do {
      while moreComing {
        let changes = try await container.privateCloudDatabase.recordZoneChanges(
          inZoneWith: ClipRecord.legacyZoneID, since: token
        )
        for (_, result) in changes.modificationResultsByID {
          if case .success(let modification) = result { records.append(modification.record) }
        }
        token = changes.changeToken
        moreComing = changes.moreComing
      }
    } catch let error as CKError where error.code == .zoneNotFound {
      finishLegacyCleanup()
      return
    }

    var result: [ClipChange] = []
    for record in records {
      guard let remote = ClipRecord.clip(from: record),
            ClipRecord.isLegacyRecord(record, of: remote),
            policy.isEligible(remote.text),
            !state.legacyTombstones.contains(remote.id) else { continue }
      let local = state.entries[remote.id]
      let merged = local.map { $0.clip.merged(with: remote) } ?? remote
      if merged != local?.clip || local?.systemFields == nil {
        state.entries[remote.id] = MirrorEntry(clip: merged, systemFields: local?.systemFields)
        if let recordID = recordID(forClipID: remote.id) {
          engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        }
      }
      if merged != local?.clip {
        result.append(.upserted(merged))
      }
    }
    movedLegacyClips = true
    logger.notice("Read \(records.count) records from the original zone, \(result.count) changes")
    persist()
    await notify(result)
  }

  /// Deletes the original zone once every clip read from it has been saved in the new one. This removes the
  /// plain-hash record names from iCloud. Devices still on version 1 keep their local history.
  private func deleteLegacyZoneIfDone(engine: CKSyncEngine) async {
    guard state.needsLegacyCleanup, movedLegacyClips, state.key != nil else { return }
    let waiting = engine.state.pendingRecordZoneChanges.contains {
      if case .saveRecord(let id) = $0 { return Self.isClipRecordName(id.recordName) }
      return false
    }
    guard !waiting else { return }
    do {
      let result = try await container.privateCloudDatabase.modifyRecordZones(
        saving: [], deleting: [ClipRecord.legacyZoneID]
      )
      switch result.deleteResults[ClipRecord.legacyZoneID] {
      case .success?:
        logger.notice("Deleted the original zone")
        finishLegacyCleanup()
      case .failure(let error as CKError)? where error.code == .zoneNotFound:
        finishLegacyCleanup()
      case .failure(let error)?:
        logger.error("Cannot delete the original zone: \(error.localizedDescription, privacy: .public)")
      case nil:
        break
      }
    } catch let error as CKError where error.code == .zoneNotFound {
      finishLegacyCleanup()
    } catch {
      logger.error("Cannot delete the original zone: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func finishLegacyCleanup() {
    guard state.needsLegacyCleanup else { return }
    state.needsLegacyCleanup = false
    state.legacyTombstones = []
    persist()
  }

  // MARK: - Local changes

  /// Reports a clip created or changed on this device. Ineligible clips and no-op updates are ignored.
  public func upsert(_ clip: Clip) {
    if store(clip) { persist() }
  }

  /// Many clips at once (import, first upload), written to disk once.
  public func upsert(contentsOf clips: [Clip]) {
    var changed = false
    for clip in clips {
      changed = store(clip) || changed
    }
    if changed { persist() }
  }

  /// Reports a new copy of some text captured on this device. Keeps the pin and collections if the clip
  /// already exists.
  public func recordCopy(_ copy: Clip) {
    upsert(state.entries[copy.id].map { $0.clip.copiedAgain(copy) } ?? copy)
  }

  /// `recordCopy` for many copies, written to disk once.
  public func recordCopies(_ copies: [Clip]) {
    upsert(contentsOf: copies.map { copy in state.entries[copy.id].map { $0.clip.copiedAgain(copy) } ?? copy })
  }

  /// Merges a local change into the mirror and queues it; false when nothing changed.
  private func store(_ clip: Clip) -> Bool {
    guard let engine, policy.isEligible(clip.text) else { return false }
    let existing = state.entries[clip.id]
    let merged = existing.map { $0.clip.merged(with: clip) } ?? clip
    guard merged != existing?.clip else { return false }

    state.entries[clip.id] = MirrorEntry(clip: merged, systemFields: existing?.systemFields)
    state.legacyTombstones.remove(clip.id)
    // Without the key nothing is queued yet; `adopt` queues every unsent clip.
    if let recordID = recordID(forClipID: clip.id) {
      engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
    }
    return true
  }

  /// Changes a clip as this device mirrors it, so fields the caller doesn't track (the Mac doesn't keep
  /// collections) survive. `fallback` is used when the clip isn't mirrored yet.
  public func modify(clipID: String, fallback: Clip? = nil, _ change: @Sendable (inout Clip) -> Void) {
    guard var clip = state.entries[clipID]?.clip ?? fallback else { return }
    let before = clip.modifiedAt
    change(&clip)
    // Strictly newer, so this version wins the merge.
    clip.modifiedAt = max(.now, before.addingTimeInterval(0.001))
    upsert(clip)
  }

  /// Adds clips to a collection or takes them out of it.
  public func setMembership(_ isMember: Bool, of clipIDs: some Sequence<String>, in collectionID: String) {
    var changed: [Clip] = []
    for id in clipIDs {
      guard var clip = state.entries[id]?.clip, clip.isIn(collectionID) != isMember else { continue }
      let before = clip.modifiedAt
      if isMember {
        clip.collectionIDs.append(collectionID)
      } else {
        clip.collectionIDs.removeAll { $0 == collectionID }
      }
      clip.modifiedAt = max(.now, before.addingTimeInterval(0.001))
      changed.append(clip)
    }
    upsert(contentsOf: changed)
  }

  /// Reports clips deleted on this device. Unknown IDs are ignored.
  public func delete(ids: some Sequence<String>) {
    guard let engine else { return }
    let removed = ids.filter { state.entries.removeValue(forKey: $0) != nil }
    guard !removed.isEmpty else { return }
    if state.needsLegacyCleanup {
      state.legacyTombstones.formUnion(removed)
    }
    engine.state.add(pendingRecordZoneChanges: removed.compactMap(recordID(forClipID:)).map { .deleteRecord($0) })
    persist()
  }

  // MARK: - Collections

  /// Creates or renames a collection.
  public func upsertCollection(_ collection: ClipCollection) {
    guard let engine else { return }
    let existing = state.collections[collection.id]
    let merged = existing.map { $0.collection.merged(with: collection) } ?? collection
    guard merged != existing?.collection else { return }
    state.collections[collection.id] = CollectionEntry(collection: merged, systemFields: existing?.systemFields)
    if state.key != nil {
      engine.state.add(pendingRecordZoneChanges: [.saveRecord(CollectionRecord.recordID(for: collection.id))])
    }
    persist()
  }

  /// Deletes a collection for every device. Its clips stay, outside it.
  public func deleteCollection(id: String) {
    guard let engine, state.collections.removeValue(forKey: id) != nil else { return }
    if state.key != nil {
      engine.state.add(pendingRecordZoneChanges: [.deleteRecord(CollectionRecord.recordID(for: id))])
    }
    setMembership(false, of: Array(state.entries.keys), in: id)
    persist()
  }

  // MARK: - Persistence

  private static func load(from url: URL) -> PersistedState {
    guard let data = try? Data(contentsOf: url),
          let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
      return PersistedState()
    }
    return state
  }

  private func persist() {
    do {
      try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(state).write(to: fileURL, options: .atomic)
    } catch {
      logger.error("Cannot persist sync state: \(error.localizedDescription)")
    }
  }

  private func notify(_ changes: [ClipChange]) async {
    guard !changes.isEmpty else { return }
    await changeHandler?(changes)
  }

  private func record(for recordID: CKRecord.ID) -> CKRecord? {
    guard recordID.zoneID == ClipRecord.zoneID else { return nil }
    let name = recordID.recordName
    if ClipCollection.isValidID(name) {
      guard let entry = state.collections[name] else { return nil }
      let base = entry.systemFields.flatMap(ClipRecord.record(fromSystemFields:))
      return CollectionRecord.record(for: entry.collection, updating: base)
    }
    guard let key = state.key, let id = clipIDsByRecordName[name], let entry = state.entries[id],
          key.recordName(forClipID: id) == name else { return nil }
    let base = entry.systemFields.flatMap(ClipRecord.record(fromSystemFields:))
    return ClipRecord.record(for: entry.clip, key: key, updating: base)
  }

  /// Forgets what this device knew about iCloud after the zone disappeared (iCloud data deleted from another
  /// device or from iCloud settings). Local history is kept; clips in `keeping` are sent again once a new key
  /// exists, because they are changes made here that never arrived.
  private func forgetCloudState(engine: CKSyncEngine, keeping: Set<String> = []) -> [ClipChange] {
    let forgottenCollections = state.collections.keys.map { ClipChange.collectionDeleted(id: $0) }
    state.entries = state.entries.filter { keeping.contains($0.key) }.mapValues {
      MirrorEntry(clip: $0.clip, systemFields: nil)
    }
    state.collections.removeAll()
    state.catchUpToken = nil
    state.key = nil
    keyFile.write(nil)
    clipIDsByRecordName = [:]
    engine.state.remove(pendingRecordZoneChanges: engine.state.pendingRecordZoneChanges)
    persist()
    return forgottenCollections
  }
}

// MARK: - CKSyncEngineDelegate

extension ClipSync: CKSyncEngineDelegate {
  public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
    switch event {
    case .stateUpdate(let update):
      state.engineState = update.stateSerialization
      persist()

    case .accountChange(let change):
      await handleAccountChange(change, syncEngine: syncEngine)

    case .fetchedDatabaseChanges(let changes):
      // The zone disappears when iCloud data is deleted (from another device or iCloud settings).
      // Forget the mirror but do not report deletions: local history must survive a cloud wipe.
      // The original zone disappearing is the end of the move, nothing to forget.
      guard changes.deletions.contains(where: { $0.zoneID == ClipRecord.zoneID }) else { return }
      logger.notice("Clips zone was deleted in iCloud; forgetting \(self.state.entries.count) mirrored clips")
      let forgotten = forgetCloudState(engine: syncEngine)
      lastError = String(localized: "iCloud data was deleted; local history was kept.", bundle: .module)
      await notify(forgotten)

    case .fetchedRecordZoneChanges(let changes):
      await handleFetched(changes, syncEngine: syncEngine)

    case .sentRecordZoneChanges(let sent):
      handleSent(sent, syncEngine: syncEngine)

    case .sentDatabaseChanges, .willFetchChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges,
         .didFetchChanges, .willSendChanges, .didSendChanges:
      break

    @unknown default:
      logger.info("Unknown sync engine event")
    }
  }

  public func nextRecordZoneChangeBatch(
    _ context: CKSyncEngine.SendChangesContext,
    syncEngine: CKSyncEngine
  ) async -> CKSyncEngine.RecordZoneChangeBatch? {
    // Nothing leaves the device before it knows the key; an unkeyed name would be a plain hash again.
    guard state.key != nil else { return nil }
    let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
    guard !pending.isEmpty else { return nil }

    // The record provider is synchronous and nonisolated, so build the records here on the actor.
    var records: [CKRecord.ID: CKRecord] = [:]
    var stale: [CKSyncEngine.PendingRecordZoneChange] = []
    for change in pending {
      switch change {
      case .saveRecord(let recordID):
        if let record = record(for: recordID) {
          records[recordID] = record
        } else {
          // Deleted locally after the save was queued, or named for a zone or key no longer in use.
          stale.append(change)
        }
      case .deleteRecord(let recordID) where recordID.zoneID != ClipRecord.zoneID:
        stale.append(change)
      default:
        break
      }
    }
    syncEngine.state.remove(pendingRecordZoneChanges: stale)

    let batchRecords = records
    let sendable = pending.filter { !stale.contains($0) }
    guard !sendable.isEmpty else { return nil }
    return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: sendable) { batchRecords[$0] }
  }

  private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange, syncEngine: CKSyncEngine) async {
    logger.notice("Account change: \(String(describing: change.changeType), privacy: .public)")
    switch change.changeType {
    case .signIn:
      // Upload everything mirrored so far (e.g. clips collected before iCloud was available); without the key
      // this waits for `syncNow`, which reads it and queues them.
      syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: ClipRecord.zoneID))])
      if let key = state.key {
        syncEngine.state.add(pendingRecordZoneChanges: state.entries.keys.map {
          .saveRecord(ClipRecord.recordID(forClipID: $0, key: key))
        })
      }
    case .signOut, .switchAccounts:
      // Another account's clips must not leak into this one. Local history is the caller's to keep.
      let forgotten = forgetCloudState(engine: syncEngine)
      state.entries.removeAll()
      state.needsLegacyCleanup = true
      state.legacyTombstones = []
      persist()
      await notify(forgotten)
    @unknown default:
      break
    }
  }

  private func handleFetched(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges, syncEngine: CKSyncEngine) async {
    // A device still on version 1 wrote to the original zone: move it on the next sync.
    if !state.needsLegacyCleanup,
       changes.modifications.contains(where: { $0.record.recordID.zoneID == ClipRecord.legacyZoneID }) {
      state.needsLegacyCleanup = true
      movedLegacyClips = false
      persist()
    }
    // The engine fetches every zone in the database; other zones (the original one, Faz 0's ProtoZone) are
    // not read here.
    await apply(
      modifications: changes.modifications.map(\.record).filter { $0.recordID.zoneID == ClipRecord.zoneID },
      deletions: changes.deletions.map(\.recordID).filter { $0.zoneID == ClipRecord.zoneID },
      syncEngine: syncEngine,
      source: "engine"
    )
  }

  /// Merges fetched records into the mirror and reports what changed. Safe to call twice for one change.
  private func apply(
    modifications: [CKRecord],
    deletions: [CKRecord.ID],
    syncEngine: CKSyncEngine,
    source: String
  ) async {
    var result: [ClipChange] = []

    // The key names every clip record, so the settings record goes first.
    if let settings = modifications.first(where: { $0.recordType == SettingsRecord.recordType }),
       let key = SettingsRecord.key(from: settings) {
      adopt(key, engine: syncEngine)
    }
    if state.key == nil, modifications.contains(where: { $0.recordType == ClipRecord.recordType }) {
      try? await ensureKey(engine: syncEngine)
    }

    for record in modifications {
      switch record.recordType {
      case ClipRecord.recordType:
        if let change = applyClip(record, syncEngine: syncEngine) { result.append(change) }
      case CollectionRecord.recordType:
        if let change = applyCollection(record, syncEngine: syncEngine) { result.append(change) }
      default:
        break
      }
    }

    for recordID in deletions {
      let name = recordID.recordName
      if ClipCollection.isValidID(name) {
        if state.collections.removeValue(forKey: name) != nil {
          result.append(.collectionDeleted(id: name))
        }
      } else if let id = clipIDsByRecordName[name], state.entries.removeValue(forKey: id) != nil {
        result.append(.deleted(id: id))
      }
    }

    logger.notice("""
      Fetched (\(source, privacy: .public)): \(modifications.count) modifications, \(deletions.count) deletions, \
      \(result.count) changes
      """)
    lastSyncAt = .now
    persist()
    await notify(result)
  }

  private func applyClip(_ record: CKRecord, syncEngine: CKSyncEngine) -> ClipChange? {
    guard let remote = ClipRecord.clip(from: record) else {
      logger.error("Ignoring invalid clip record \(record.recordID.recordName, privacy: .public)")
      return nil
    }
    let local = state.entries[remote.id]
    let merged = local.map { $0.clip.merged(with: remote) } ?? remote
    if let key = state.key, !ClipRecord.isNamed(record, for: remote, key: key) {
      // Saved under an older key by a device that missed the change: keep the clip under its proper name and
      // remove the stray record.
      state.entries[remote.id] = MirrorEntry(clip: merged, systemFields: local?.systemFields)
      var changes: [CKSyncEngine.PendingRecordZoneChange] = [.deleteRecord(record.recordID)]
      if let recordID = recordID(forClipID: remote.id) { changes.append(.saveRecord(recordID)) }
      syncEngine.state.add(pendingRecordZoneChanges: changes)
    } else {
      state.entries[remote.id] = MirrorEntry(clip: merged, systemFields: ClipRecord.systemFields(of: record))
      clipIDsByRecordName[record.recordID.recordName] = remote.id
      if merged != remote {
        // This device knows something newer (e.g. a later copy); push it back.
        syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
      }
    }
    state.legacyTombstones.remove(remote.id)
    return merged != local?.clip ? .upserted(merged) : nil
  }

  private func applyCollection(_ record: CKRecord, syncEngine: CKSyncEngine) -> ClipChange? {
    guard let remote = CollectionRecord.collection(from: record) else {
      logger.error("Ignoring invalid collection record \(record.recordID.recordName, privacy: .public)")
      return nil
    }
    let local = state.collections[remote.id]?.collection
    let merged = local.map { $0.merged(with: remote) } ?? remote
    state.collections[remote.id] = CollectionEntry(collection: merged, systemFields: ClipRecord.systemFields(of: record))
    if merged != remote {
      syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
    }
    return merged != local ? .collectionUpserted(merged) : nil
  }

  private func handleSent(_ sent: CKSyncEngine.Event.SentRecordZoneChanges, syncEngine: CKSyncEngine) {
    for record in sent.savedRecords {
      let name = record.recordID.recordName
      if record.recordType == CollectionRecord.recordType {
        state.collections[name]?.systemFields = ClipRecord.systemFields(of: record)
      } else if let id = clipIDsByRecordName[name], state.entries[id] != nil {
        state.entries[id]?.systemFields = ClipRecord.systemFields(of: record)
      }
    }

    var resend: [CKRecord.ID] = []
    var zoneIsGone = false
    var unsentClips: Set<String> = []
    for failure in sent.failedRecordSaves {
      let recordID = failure.record.recordID
      let name = recordID.recordName
      let clipID = clipIDsByRecordName[name]
      let isCollection = ClipCollection.isValidID(name)
      switch failure.error.code {
      case .serverRecordChanged:
        // Another device saved first: merge with the server version and retry on top of it.
        guard let serverRecord = failure.error.serverRecord else { continue }
        if isCollection {
          guard let remote = CollectionRecord.collection(from: serverRecord),
                let local = state.collections[name]?.collection else { continue }
          state.collections[name] = CollectionEntry(
            collection: local.merged(with: remote), systemFields: ClipRecord.systemFields(of: serverRecord)
          )
        } else {
          guard let clipID, let remote = ClipRecord.clip(from: serverRecord),
                let local = state.entries[clipID]?.clip else { continue }
          state.entries[clipID] = MirrorEntry(
            clip: local.merged(with: remote), systemFields: ClipRecord.systemFields(of: serverRecord)
          )
        }
        resend.append(recordID)
      case .zoneNotFound:
        // The zone, and the key in it, was deleted. What this device just changed is sent again under a
        // new key; everything else is forgotten, as when the deletion is fetched.
        zoneIsGone = true
        if let clipID { unsentClips.insert(clipID) }
      case .unknownItem:
        // Deleted on the server; recreate from our copy.
        if isCollection {
          state.collections[name]?.systemFields = nil
        } else if let clipID {
          state.entries[clipID]?.systemFields = nil
        }
        resend.append(recordID)
      case .batchRequestFailed:
        // Rejected only because another record in the same batch failed.
        resend.append(recordID)
      case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable, .notAuthenticated,
           .operationCancelled, .requestRateLimited:
        // CKSyncEngine retries these on its own.
        break
      default:
        lastError = failure.error.localizedDescription
        // The name is keyed, not content, so it is safe to log publicly.
        logger.error("""
          Cannot save \(name, privacy: .public): CKError \(failure.error.code.rawValue, privacy: .public) \
          \(failure.error.localizedDescription, privacy: .public)
          """)
      }
    }

    if zoneIsGone {
      logger.notice("Clips zone is gone; \(unsentClips.count) local changes wait for a new key")
      _ = forgetCloudState(engine: syncEngine, keeping: unsentClips)
      syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: ClipRecord.zoneID))])
    } else if !resend.isEmpty {
      syncEngine.state.add(pendingRecordZoneChanges: resend.map { .saveRecord($0) })
    }
    logger.notice("""
      Sent \(sent.savedRecords.count) saves, \(sent.deletedRecordIDs.count) deletes, \
      \(sent.failedRecordSaves.count) failed saves, \(sent.failedRecordDeletes.count) failed deletes
      """)
    if sent.failedRecordSaves.isEmpty {
      lastError = nil
    }
    lastSyncAt = .now
    persist()
  }
}

extension CKSyncEngine.PendingRecordZoneChange {
  var recordID: CKRecord.ID? {
    switch self {
    case .saveRecord(let id), .deleteRecord(let id): id
    @unknown default: nil
    }
  }
}

extension CKSyncEngine.PendingDatabaseChange {
  var zoneID: CKRecordZone.ID? {
    switch self {
    case .saveZone(let zone): zone.zoneID
    case .deleteZone(let id): id
    @unknown default: nil
    }
  }
}
