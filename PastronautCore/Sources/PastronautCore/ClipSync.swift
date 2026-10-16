import CloudKit
import Foundation
import os

/// A clip that changed because of another device.
public enum ClipChange: Equatable, Sendable {
  case upserted(Clip)
  case deleted(id: String)
}

public struct SyncStatus: Equatable, Sendable {
  public var isRunning: Bool
  public var syncedClips: Int
  public var lastSyncAt: Date?
  public var lastError: String?
}

/// Two-way sync of clips with the user's private iCloud database, built on CKSyncEngine.
///
/// Keeps a small mirror of every synced clip (with the server's system fields) next to the app's own
/// storage, so the app's history model stays untouched. Callers report local changes with `upsert`
/// and `delete`; remote changes arrive through the change handler.
public actor ClipSync {
  public typealias ChangeHandler = @Sendable ([ClipChange]) async -> Void

  struct MirrorEntry: Codable {
    var clip: Clip
    /// Archived system fields of the last known server record; nil until first saved or fetched.
    var systemFields: Data?
  }

  struct PersistedState: Codable {
    var entries: [String: MirrorEntry] = [:]
    var engineState: CKSyncEngine.State.Serialization?
    /// Archived change token of our own zone fetch (see `catchUp`). Separate from the engine's tokens.
    var catchUpToken: Data?
  }

  private let container: CKContainer
  private let fileURL: URL
  private let policy: SyncPolicy
  private var state: PersistedState
  private var engine: CKSyncEngine?
  private var changeHandler: ChangeHandler?
  private var lastSyncAt: Date?
  private var lastError: String?
  private let logger = Logger(subsystem: "com.xkbxyberk.pastronaut", category: "ClipSync")

  public init(containerIdentifier: String, storageDirectory: URL, policy: SyncPolicy = .default) {
    self.container = CKContainer(identifier: containerIdentifier)
    self.fileURL = storageDirectory.appending(path: "clip-sync.json")
    self.policy = policy
    self.state = Self.load(from: fileURL)
  }

  public func setChangeHandler(_ handler: ChangeHandler?) {
    changeHandler = handler
  }

  public var status: SyncStatus {
    SyncStatus(isRunning: engine != nil, syncedClips: state.entries.count, lastSyncAt: lastSyncAt, lastError: lastError)
  }

  public var clips: [Clip] {
    state.entries.values.map(\.clip)
  }

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
    logger.notice("Started with \(self.state.entries.count) mirrored clips")
  }

  /// Stops syncing and forgets the local mirror. iCloud data and local history are left untouched.
  public func stop() {
    engine = nil
    state = PersistedState()
    persist()
  }

  /// Deletes the clips zone from iCloud for every device, then stops.
  public func deleteCloudData() async throws {
    guard let engine else { return }
    engine.state.add(pendingDatabaseChanges: [.deleteZone(ClipRecord.zoneID)])
    try await engine.sendChanges()
    stop()
  }

  /// Fetches and sends now. Call at launch, on foreground, on push and from a periodic fallback.
  public func syncNow() async throws {
    guard let engine else { return }
    try await engine.fetchChanges()
    try await catchUp(syncEngine: engine)
    try await engine.sendChanges()
  }

  /// Uploads pending changes now instead of waiting for the engine's own schedule, which runs a few
  /// seconds later and never runs if iOS suspends the app first.
  public func sendNow() async throws {
    try await engine?.sendChanges()
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

    if isFullFetch {
      // A full fetch reports no deletions. Clips this device saw on the server that are gone now, and
      // that are not waiting to be uploaded again, were deleted elsewhere.
      let onServer = Set(records.map(\.recordID.recordName))
      let pendingSaves = Set(syncEngine.state.pendingRecordZoneChanges.compactMap { change -> String? in
        if case .saveRecord(let id) = change { return id.recordName }
        return nil
      })
      deletions += state.entries
        .filter { $0.value.systemFields != nil && !onServer.contains($0.key) && !pendingSaves.contains($0.key) }
        .map { ClipRecord.recordID(for: $0.key) }
    }

    state.catchUpToken = token.flatMap {
      try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
    }
    await apply(modifications: records, deletions: deletions, syncEngine: syncEngine, source: "catch-up")
  }

  // MARK: - Local changes

  /// Reports a clip created or changed on this device. Ineligible clips and no-op updates are ignored.
  public func upsert(_ clip: Clip) {
    guard let engine, policy.isEligible(clip.text) else { return }
    let existing = state.entries[clip.id]
    let merged = existing.map { $0.clip.merged(with: clip) } ?? clip
    guard merged != existing?.clip else { return }

    state.entries[clip.id] = MirrorEntry(clip: merged, systemFields: existing?.systemFields)
    engine.state.add(pendingRecordZoneChanges: [.saveRecord(ClipRecord.recordID(for: clip.id))])
    persist()
  }

  /// Reports clips deleted on this device. Unknown IDs are ignored.
  public func delete(ids: some Sequence<String>) {
    guard let engine else { return }
    let removed = ids.filter { state.entries.removeValue(forKey: $0) != nil }
    guard !removed.isEmpty else { return }
    engine.state.add(pendingRecordZoneChanges: removed.map { .deleteRecord(ClipRecord.recordID(for: $0)) })
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
    guard let entry = state.entries[recordID.recordName] else { return nil }
    let base = entry.systemFields.flatMap(ClipRecord.record(fromSystemFields:))
    return ClipRecord.record(for: entry.clip, updating: base)
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
      // New local changes recreate the zone through the zoneNotFound path.
      guard changes.deletions.contains(where: { $0.zoneID == ClipRecord.zoneID }) else { return }
      logger.notice("Clips zone was deleted in iCloud; forgetting \(self.state.entries.count) mirrored clips")
      state.entries.removeAll()
      state.catchUpToken = nil
      lastError = "iCloud data was deleted; local history was kept."
      persist()

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
    let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
    guard !pending.isEmpty else { return nil }

    // The record provider is synchronous and nonisolated, so build the records here on the actor.
    var records: [CKRecord.ID: CKRecord] = [:]
    var stale: [CKSyncEngine.PendingRecordZoneChange] = []
    for case .saveRecord(let recordID) in pending {
      if let record = record(for: recordID) {
        records[recordID] = record
      } else {
        // Deleted locally after the save was queued.
        stale.append(.saveRecord(recordID))
      }
    }
    syncEngine.state.remove(pendingRecordZoneChanges: stale)

    let batchRecords = records
    return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { batchRecords[$0] }
  }

  private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange, syncEngine: CKSyncEngine) async {
    logger.notice("Account change: \(String(describing: change.changeType), privacy: .public)")
    switch change.changeType {
    case .signIn:
      // Upload everything mirrored so far (e.g. clips collected before iCloud was available).
      syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: ClipRecord.zoneID))])
      syncEngine.state.add(pendingRecordZoneChanges: state.entries.keys.map {
        .saveRecord(ClipRecord.recordID(for: $0))
      })
    case .signOut, .switchAccounts:
      // Another account's clips must not leak into this one. Local history is the caller's to keep.
      state.entries.removeAll()
      state.catchUpToken = nil
      persist()
    @unknown default:
      break
    }
  }

  private func handleFetched(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges, syncEngine: CKSyncEngine) async {
    await apply(
      modifications: changes.modifications.map(\.record),
      deletions: changes.deletions.map(\.recordID),
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

    for record in modifications {
      guard let remote = ClipRecord.clip(from: record) else {
        logger.error("Ignoring invalid clip record \(record.recordID.recordName)")
        continue
      }
      let local = state.entries[remote.id]?.clip
      let merged = local.map { $0.merged(with: remote) } ?? remote
      state.entries[remote.id] = MirrorEntry(clip: merged, systemFields: ClipRecord.systemFields(of: record))
      if merged != remote {
        // This device knows something newer (e.g. a later copy); push it back.
        syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
      }
      if merged != local {
        result.append(.upserted(merged))
      }
    }

    for recordID in deletions {
      let id = recordID.recordName
      if state.entries.removeValue(forKey: id) != nil {
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

  private func handleSent(_ sent: CKSyncEngine.Event.SentRecordZoneChanges, syncEngine: CKSyncEngine) {
    for record in sent.savedRecords where state.entries[record.recordID.recordName] != nil {
      state.entries[record.recordID.recordName]?.systemFields = ClipRecord.systemFields(of: record)
    }

    var resend: [CKRecord.ID] = []
    var needsZone = false
    for failure in sent.failedRecordSaves {
      let recordID = failure.record.recordID
      let id = recordID.recordName
      switch failure.error.code {
      case .serverRecordChanged:
        // Another device saved first: merge with the server version and retry on top of it.
        guard let serverRecord = failure.error.serverRecord,
              let remote = ClipRecord.clip(from: serverRecord),
              let local = state.entries[id]?.clip else { continue }
        state.entries[id] = MirrorEntry(clip: local.merged(with: remote), systemFields: ClipRecord.systemFields(of: serverRecord))
        resend.append(recordID)
      case .zoneNotFound:
        needsZone = true
        state.entries[id]?.systemFields = nil
        resend.append(recordID)
      case .unknownItem:
        // Deleted on the server; recreate from our copy.
        state.entries[id]?.systemFields = nil
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
        // The ID is a content hash, not content, so it is safe to log publicly.
        logger.error("""
          Cannot save \(id, privacy: .public): CKError \(failure.error.code.rawValue, privacy: .public) \
          \(failure.error.localizedDescription, privacy: .public)
          """)
      }
    }

    if needsZone {
      syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: ClipRecord.zoneID))])
    }
    if !resend.isEmpty {
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
