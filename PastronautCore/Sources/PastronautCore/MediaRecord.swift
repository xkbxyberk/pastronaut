import CloudKit
import Foundation

/// CloudKit schema for image, PDF and file clips (since 1.3), in the same zone as the clips. A record type of its
/// own, so clients before 1.3 skip it (`ClipSync.apply`) and never see an empty text clip.
///
/// Production schemas are additive-only: field names and types here must not change once deployed. What may grow
/// (the file list, recognized text) is one encrypted JSON field, `info`, so it can change without a schema change.
public enum MediaRecord {
  public static let recordType = "Media"
  public static let schemaVersion: Int64 = 3
  /// Recognized text beyond this is not sent; records must stay well under CloudKit's 1 MB.
  public static let maxRecognizedTextLength = 20_000
  /// The thumbnail is an encrypted field; larger ones are not sent.
  public static let maxThumbnailBytes = 60_000

  enum Field {
    // Encrypted on the device (CloudKit encryptedValues).
    /// The clip's ID (`ClipMedia.clipID`): unlike a text clip's, it can't be worked out from the content.
    static let clipID = "clipID"
    /// JSON of `ClipMedia`.
    static let info = "info"
    static let thumbnail = "thumbnail"
    static let sourceApp = "sourceApp"
    static let sourceAppName = "sourceAppName"
    static let collections = "collections"
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
    // Assets: the files, encrypted with `MediaCipher`, in the order of `ClipMedia.files`.
    static let files = "files"
  }

  /// Every field but the files: what a fetch asks for when the files shouldn't come along.
  static let fieldsWithoutFiles = [
    Field.clipID, Field.info, Field.thumbnail, Field.sourceApp, Field.sourceAppName, Field.collections, Field.title,
    Field.kind, Field.sourceDevice, Field.firstCopiedAt, Field.lastCopiedAt, Field.modifiedAt, Field.pinned,
    Field.titleModifiedAt, Field.schemaVersion
  ]
  static let filesField = Field.files

  /// Writes `clip` into `record`, or into a new record named with `key`. The files are set only when given
  /// (`encryptedFiles`): content never changes for a clip ID, so a pin or a title doesn't upload them again, and
  /// CloudKit keeps fields a save doesn't set.
  public static func record(
    for clip: Clip,
    key: SyncKey,
    thumbnail: Data? = nil,
    encryptedFiles: [URL]? = nil,
    updating record: CKRecord? = nil
  ) -> CKRecord {
    precondition(clip.media != nil, "Only media clips have media records")
    let record = record ?? CKRecord(recordType: recordType, recordID: ClipRecord.recordID(forClipID: clip.id, key: key))
    record.encryptedValues[Field.clipID] = clip.id
    record.encryptedValues[Field.info] = try? JSONEncoder().encode(clip.media)
    if let thumbnail, thumbnail.count <= maxThumbnailBytes {
      record.encryptedValues[Field.thumbnail] = thumbnail
    }
    record.encryptedValues[Field.sourceApp] = clip.sourceApp
    record.encryptedValues[Field.sourceAppName] = clip.sourceAppName
    record.encryptedValues[Field.collections] = clip.collectionIDs.isEmpty ? nil : clip.collectionIDs
    record[Field.kind] = clip.kind.rawValue
    record[Field.sourceDevice] = clip.sourceDevice.rawValue
    record[Field.firstCopiedAt] = clip.firstCopiedAt
    record[Field.lastCopiedAt] = clip.lastCopiedAt
    record[Field.modifiedAt] = clip.modifiedAt
    record[Field.pinned] = clip.pinned ? 1 : 0
    if let titleModifiedAt = clip.titleModifiedAt {
      record.encryptedValues[Field.title] = clip.title
      record[Field.titleModifiedAt] = titleModifiedAt
    }
    if let encryptedFiles {
      record[Field.files] = encryptedFiles.map { CKAsset(fileURL: $0) }
    }
    record[Field.schemaVersion] = schemaVersion
    return record
  }

  /// The clip in a record, or nil when the record is not a valid media clip.
  public static func clip(from record: CKRecord) -> Clip? {
    guard record.recordType == recordType,
          let id = record.encryptedValues[Field.clipID] as? String, ClipMedia.isMediaID(id),
          let info = record.encryptedValues[Field.info] as? Data,
          let media = try? JSONDecoder().decode(ClipMedia.self, from: info),
          !media.files.isEmpty else {
      return nil
    }
    let firstCopiedAt = record[Field.firstCopiedAt] as? Date ?? record.creationDate ?? .now
    var clip = Clip(
      id: id,
      media: media,
      sourceApp: record.encryptedValues[Field.sourceApp] as? String,
      sourceAppName: record.encryptedValues[Field.sourceAppName] as? String,
      sourceDevice: (record[Field.sourceDevice] as? String).flatMap(Clip.Device.init(rawValue:)) ?? .mac,
      firstCopiedAt: firstCopiedAt,
      lastCopiedAt: record[Field.lastCopiedAt] as? Date ?? firstCopiedAt,
      modifiedAt: record[Field.modifiedAt] as? Date ?? record.modificationDate ?? firstCopiedAt,
      pinned: (record[Field.pinned] as? Int64 ?? 0) != 0,
      collectionIDs: (record.encryptedValues[Field.collections] as? [String] ?? []).filter(ClipCollection.isValidID)
    )
    if let titleModifiedAt = record[Field.titleModifiedAt] as? Date {
      clip.setTitle(record.encryptedValues[Field.title] as? String, at: titleModifiedAt)
    }
    return clip
  }

  public static func thumbnail(of record: CKRecord) -> Data? {
    record.encryptedValues[Field.thumbnail] as? Data
  }

  /// The downloaded (still encrypted) files, in order; nil when the fetch left them out or one didn't download.
  public static func encryptedFileURLs(of record: CKRecord) -> [URL]? {
    guard let assets = record[Field.files] as? [CKAsset], !assets.isEmpty else { return nil }
    let urls = assets.compactMap(\.fileURL).filter { FileManager.default.fileExists(atPath: $0.path) }
    return urls.count == assets.count ? urls : nil
  }
}

/// CloudKit schema for app icons (since 1.3): one record per app, written by the Mac.
public enum AppIconRecord {
  public static let recordType = "AppIcon"

  enum Field {
    // Encrypted.
    static let bundleIdentifier = "bundleIdentifier"
    static let name = "name"
    static let png = "png"
    // Plain metadata.
    static let modifiedAt = "modifiedAt"
    static let schemaVersion = "schemaVersion"
  }

  public static func recordID(for bundleIdentifier: String, key: SyncKey) -> CKRecord.ID {
    CKRecord.ID(recordName: key.recordName(forAppIcon: bundleIdentifier), zoneID: ClipRecord.zoneID)
  }

  /// Named with `key` for the bundle identifier in it; not a stray saved under an older key.
  public static func isNamed(_ record: CKRecord, key: SyncKey) -> Bool {
    guard let bundleIdentifier = record.encryptedValues[Field.bundleIdentifier] as? String else { return false }
    return record.recordID.recordName == key.recordName(forAppIcon: bundleIdentifier)
  }

  public static func record(for icon: AppIcon, key: SyncKey, updating record: CKRecord? = nil) -> CKRecord {
    let record = record ?? CKRecord(recordType: recordType, recordID: recordID(for: icon.bundleIdentifier, key: key))
    record.encryptedValues[Field.bundleIdentifier] = icon.bundleIdentifier
    record.encryptedValues[Field.name] = icon.name
    record.encryptedValues[Field.png] = icon.png
    record[Field.modifiedAt] = icon.modifiedAt
    record[Field.schemaVersion] = MediaRecord.schemaVersion
    return record
  }

  public static func icon(from record: CKRecord) -> AppIcon? {
    guard record.recordType == recordType,
          let bundleIdentifier = record.encryptedValues[Field.bundleIdentifier] as? String,
          let png = record.encryptedValues[Field.png] as? Data, png.count <= AppIcon.maxBytes else {
      return nil
    }
    return AppIcon(
      bundleIdentifier: bundleIdentifier,
      name: record.encryptedValues[Field.name] as? String,
      png: png,
      modifiedAt: record[Field.modifiedAt] as? Date ?? record.modificationDate ?? .distantPast
    )
  }

  static let fields = [Field.bundleIdentifier, Field.name, Field.png, Field.modifiedAt, Field.schemaVersion]
}

extension SyncKey {
  /// The iCloud record name for an app's icon. Keyed like clip names, so bundle identifiers don't show.
  public func recordName(forAppIcon bundleIdentifier: String) -> String {
    "a-" + recordName(forClipID: "app-icon:" + bundleIdentifier).dropFirst(2)
  }
}

/// Settings every device shares (since 1.3), next to the key in the settings record.
extension SettingsRecord {
  enum SharedField {
    /// Encrypted JSON of `SharedSyncSettings`.
    static let shared = "shared"
  }

  static let fields = [Field.idKey, SharedField.shared]

  public static func sharedSettings(from record: CKRecord) -> SharedSyncSettings? {
    guard record.recordType == recordType, let data = record.encryptedValues[SharedField.shared] as? Data else {
      return nil
    }
    return try? JSONDecoder().decode(SharedSyncSettings.self, from: data)
  }

  /// Writes the shared settings only; the key in the record stays as it is.
  public static func write(_ settings: SharedSyncSettings, into record: CKRecord) {
    record.encryptedValues[SharedField.shared] = try? JSONEncoder().encode(settings)
  }
}
