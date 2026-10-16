import CloudKit
import Foundation

/// Minimal CloudKit access for the Faz 0 prototype (Mac app and iOS app, not the keyboard).
/// Uses a custom zone so fetching needs no queryable indexes.
struct ProtoCloud {
  let container = CKContainer(identifier: ProtoIDs.container)
  var database: CKDatabase { container.privateCloudDatabase }
  let zoneID = CKRecordZone.ID(zoneName: ProtoIDs.zoneName)

  func accountStatus() async -> String {
    do {
      switch try await container.accountStatus() {
      case .available: return "available"
      case .noAccount: return "noAccount"
      case .restricted: return "restricted"
      case .couldNotDetermine: return "couldNotDetermine"
      case .temporarilyUnavailable: return "temporarilyUnavailable"
      @unknown default: return "unknown"
      }
    } catch {
      return "error: \(error.localizedDescription)"
    }
  }

  // modifyRecordZones/modifyRecords only throw for whole-operation failures.
  // Per-item failures (e.g. a record type missing from the Production schema) come back in the result maps.
  func ensureZone() async throws {
    let result = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
    for (_, zoneResult) in result.saveResults {
      _ = try zoneResult.get()
    }
  }

  func save(text: String, source: String) async throws {
    try await ensureZone()
    let record = CKRecord(recordType: ProtoIDs.recordType, recordID: CKRecord.ID(zoneID: zoneID))
    record.encryptedValues["text"] = text
    record["source"] = source
    record["copiedAt"] = Date.now
    let result = try await database.modifyRecords(saving: [record], deleting: [])
    for (_, recordResult) in result.saveResults {
      _ = try recordResult.get()
    }
  }

  func fetchAll() async throws -> [ProtoItem] {
    try await ensureZone()
    var items: [ProtoItem] = []
    var token: CKServerChangeToken?
    var moreComing = true
    while moreComing {
      let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
      for (_, result) in changes.modificationResultsByID {
        guard let record = try? result.get().record else { continue }
        items.append(ProtoItem(
          id: record.recordID.recordName,
          text: record.encryptedValues["text"] as? String ?? "",
          date: record["copiedAt"] as? Date ?? record.creationDate ?? .distantPast,
          source: record["source"] as? String ?? "?"
        ))
      }
      token = changes.changeToken
      moreComing = changes.moreComing
    }
    return items.sorted { $0.date > $1.date }
  }
}
