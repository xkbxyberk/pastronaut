import CloudKit
import Foundation

/// CloudKit schema for clips. Deployed to Production once before release; Production schemas are
/// additive-only, so field names and types here must not change afterwards. Add fields instead.
public enum ClipRecord {
  public static let recordType = "Clip"
  /// Clips, collections and the settings record. Replaced `legacyZoneName`, whose records were named after the
  /// plain SHA-256 of their text (see `SyncKey`); `ClipSync` moves what it finds there and deletes it.
  public static let zoneName = "Library"
  public static let legacyZoneName = "Clips"
  public static let schemaVersion: Int64 = 2

  public static var zoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: zoneName) }
  public static var legacyZoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: legacyZoneName) }

  enum Field {
    // Encrypted on the device (CloudKit encryptedValues; end-to-end with Advanced Data Protection). Not visible in the CloudKit console.
    static let text = "text"
    static let sourceApp = "sourceApp"
    static let sourceAppName = "sourceAppName"
    static let collections = "collections"
    /// Since 1.2. Written only once a title was set or cleared, so older clients' records stay as they were.
    static let title = "title"
    // Plain metadata.
    static let kind = "kind"
    static let sourceDevice = "sourceDevice"
    static let firstCopiedAt = "firstCopiedAt"
    static let lastCopiedAt = "lastCopiedAt"
    static let modifiedAt = "modifiedAt"
    static let pinned = "pinned"
    static let titleModifiedAt = "titleModifiedAt"
    static let schemaVersion = "schemaVersion"
  }

  public static func recordID(forClipID clipID: String, key: SyncKey) -> CKRecord.ID {
    CKRecord.ID(recordName: key.recordName(forClipID: clipID), zoneID: zoneID)
  }

  /// Whether a record is named the way `key` names this clip. A record named with another key was written
  /// by a device that missed a key change; `ClipSync` moves it to the right name.
  public static func isNamed(_ record: CKRecord, for clip: Clip, key: SyncKey) -> Bool {
    record.recordID.recordName == key.recordName(forClipID: clip.id)
  }

  /// Writes `clip` into `record`, or into a new record named with `key` when `record` is nil.
  /// Reusing the last known server record keeps its change tag and avoids needless conflicts.
  public static func record(for clip: Clip, key: SyncKey, updating record: CKRecord? = nil) -> CKRecord {
    let record = record ?? CKRecord(recordType: recordType, recordID: recordID(forClipID: clip.id, key: key))
    record.encryptedValues[Field.text] = clip.text
    record.encryptedValues[Field.sourceApp] = clip.sourceApp
    record.encryptedValues[Field.sourceAppName] = clip.sourceAppName
    // CloudKit returns an empty list as no value, so none is stored.
    record.encryptedValues[Field.collections] = clip.collectionIDs.isEmpty ? nil : clip.collectionIDs
    record[Field.kind] = clip.kind.rawValue
    record[Field.sourceDevice] = clip.sourceDevice.rawValue
    record[Field.firstCopiedAt] = clip.firstCopiedAt
    record[Field.lastCopiedAt] = clip.lastCopiedAt
    record[Field.modifiedAt] = clip.modifiedAt
    record[Field.pinned] = clip.pinned ? 1 : 0
    // Clients before 1.2 never write these, so a title set elsewhere survives their saves.
    if let titleModifiedAt = clip.titleModifiedAt {
      record.encryptedValues[Field.title] = clip.title
      record[Field.titleModifiedAt] = titleModifiedAt
    }
    record[Field.schemaVersion] = schemaVersion
    return record
  }

  /// The clip in a record, or nil when the record is not a valid clip (wrong type, missing text). The record
  /// name is not checked here; see `isNamed(_:for:key:)` and, for the old zone, `isLegacyRecord(_:of:)`.
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
      pinned: (record[Field.pinned] as? Int64 ?? 0) != 0,
      collectionIDs: (record.encryptedValues[Field.collections] as? [String] ?? []).filter(ClipCollection.isValidID)
    )
    if let kind = (record[Field.kind] as? String).flatMap(Clip.Kind.init(rawValue:)) {
      clip.kind = kind
    }
    if let titleModifiedAt = record[Field.titleModifiedAt] as? Date {
      clip.setTitle(record.encryptedValues[Field.title] as? String, at: titleModifiedAt)
    }
    return clip
  }

  /// Records in the old zone were named after `Clip.id` itself.
  public static func isLegacyRecord(_ record: CKRecord, of clip: Clip) -> Bool {
    record.recordID.recordName == clip.id
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

/// CloudKit schema for collections, in the same zone as the clips.
public enum CollectionRecord {
  public static let recordType = "Collection"

  enum Field {
    // Encrypted.
    static let name = "name"
    // Plain metadata.
    static let order = "order"
    static let createdAt = "createdAt"
    static let modifiedAt = "modifiedAt"
    static let schemaVersion = "schemaVersion"
  }

  public static func recordID(for collectionID: String) -> CKRecord.ID {
    CKRecord.ID(recordName: collectionID, zoneID: ClipRecord.zoneID)
  }

  public static func record(for collection: ClipCollection, updating record: CKRecord? = nil) -> CKRecord {
    let record = record ?? CKRecord(recordType: recordType, recordID: recordID(for: collection.id))
    record.encryptedValues[Field.name] = collection.name
    record[Field.order] = collection.order
    record[Field.createdAt] = collection.createdAt
    record[Field.modifiedAt] = collection.modifiedAt
    record[Field.schemaVersion] = ClipRecord.schemaVersion
    return record
  }

  public static func collection(from record: CKRecord) -> ClipCollection? {
    guard record.recordType == recordType,
          ClipCollection.isValidID(record.recordID.recordName),
          let name = record.encryptedValues[Field.name] as? String else {
      return nil
    }
    let createdAt = record[Field.createdAt] as? Date ?? record.creationDate ?? .now
    return ClipCollection(
      id: record.recordID.recordName,
      name: name,
      order: record[Field.order] as? Double ?? 0,
      createdAt: createdAt,
      modifiedAt: record[Field.modifiedAt] as? Date ?? record.modificationDate ?? createdAt
    )
  }
}
