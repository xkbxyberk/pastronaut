import CloudKit
import Foundation

/// CloudKit schema for clips. Deployed to Production once before release; Production schemas are
/// additive-only, so field names and types here must not change afterwards. Add fields instead.
public enum ClipRecord {
  public static let recordType = "Clip"
  public static let zoneName = "Clips"
  public static let schemaVersion: Int64 = 1

  public static var zoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: zoneName) }

  enum Field {
    // Encrypted (end-to-end, not visible in the CloudKit console).
    static let text = "text"
    static let sourceApp = "sourceApp"
    static let sourceAppName = "sourceAppName"
    // Plain metadata.
    static let kind = "kind"
    static let sourceDevice = "sourceDevice"
    static let firstCopiedAt = "firstCopiedAt"
    static let lastCopiedAt = "lastCopiedAt"
    static let modifiedAt = "modifiedAt"
    static let pinned = "pinned"
    static let schemaVersion = "schemaVersion"
  }

  public static func recordID(for clipID: String) -> CKRecord.ID {
    CKRecord.ID(recordName: clipID, zoneID: zoneID)
  }

  /// Writes `clip` into `record`, or into a new record when `record` is nil.
  /// Reusing the last known server record keeps its change tag and avoids needless conflicts.
  public static func record(for clip: Clip, updating record: CKRecord? = nil) -> CKRecord {
    let record = record ?? CKRecord(recordType: recordType, recordID: recordID(for: clip.id))
    record.encryptedValues[Field.text] = clip.text
    record.encryptedValues[Field.sourceApp] = clip.sourceApp
    record.encryptedValues[Field.sourceAppName] = clip.sourceAppName
    record[Field.kind] = clip.kind.rawValue
    record[Field.sourceDevice] = clip.sourceDevice.rawValue
    record[Field.firstCopiedAt] = clip.firstCopiedAt
    record[Field.lastCopiedAt] = clip.lastCopiedAt
    record[Field.modifiedAt] = clip.modifiedAt
    record[Field.pinned] = clip.pinned ? 1 : 0
    record[Field.schemaVersion] = schemaVersion
    return record
  }

  /// nil for records that are not valid clips (wrong type, missing text, or an ID that does not match the text).
  public static func clip(from record: CKRecord) -> Clip? {
    guard record.recordType == recordType,
          let text = record.encryptedValues[Field.text] as? String else {
      return nil
    }
    let firstCopiedAt = record[Field.firstCopiedAt] as? Date ?? record.creationDate ?? .now
    var clip = Clip(
      text: text,
      sourceApp: record.encryptedValues[Field.sourceApp] as? String,
      sourceAppName: record.encryptedValues[Field.sourceAppName] as? String,
      sourceDevice: (record[Field.sourceDevice] as? String).flatMap(Clip.Device.init(rawValue:)) ?? .mac,
      firstCopiedAt: firstCopiedAt,
      lastCopiedAt: record[Field.lastCopiedAt] as? Date ?? firstCopiedAt,
      modifiedAt: record[Field.modifiedAt] as? Date ?? record.modificationDate ?? firstCopiedAt,
      pinned: (record[Field.pinned] as? Int64 ?? 0) != 0
    )
    if let kind = (record[Field.kind] as? String).flatMap(Clip.Kind.init(rawValue:)) {
      clip.kind = kind
    }
    guard clip.id == record.recordID.recordName else { return nil }
    return clip
  }

  public static func systemFields(of record: CKRecord) -> Data {
    let archiver = NSKeyedArchiver(requiringSecureCoding: true)
    record.encodeSystemFields(with: archiver)
    archiver.finishEncoding()
    return archiver.encodedData
  }

  public static func record(fromSystemFields data: Data) -> CKRecord? {
    guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
    unarchiver.requiresSecureCoding = true
    return CKRecord(coder: unarchiver)
  }
}
