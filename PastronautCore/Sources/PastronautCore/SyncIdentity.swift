import CloudKit
import CryptoKit
import Foundation

/// The account's secret for naming clip records in iCloud.
///
/// Record names are never encrypted. Naming a record after the plain SHA-256 of its text (as the first version
/// did) let anyone who could see the names recover short texts, such as one-time codes, by hashing every
/// candidate. An HMAC with this key means nothing without the key, and the key itself only travels in an
/// encrypted field (`SettingsRecord`). The same text still gets the same name on every device, so copies of
/// one text made on two devices still meet in one record.
public struct SyncKey: Codable, Equatable, Sendable {
  public let data: Data

  public init?(data: Data) {
    guard data.count == 32 else { return nil }
    self.data = data
  }

  public static func generate() -> SyncKey {
    let key = SymmetricKey(size: .bits256)
    // swiftlint:disable:next force_unwrapping
    return SyncKey(data: key.withUnsafeBytes { Data($0) })!
  }

  /// The iCloud record name for a clip, from its local ID (`Clip.id`).
  public func recordName(forClipID clipID: String) -> String {
    let code = HMAC<SHA256>.authenticationCode(for: Data(clipID.utf8), using: SymmetricKey(data: data))
    return "c-" + code.map { String(format: "%02x", $0) }.joined()
  }
}

/// One record per account that holds settings every device shares; for now only the record-name key.
public enum SettingsRecord {
  public static let recordType = "Settings"
  public static let recordName = "settings"

  enum Field {
    // Encrypted.
    static let idKey = "idKey"
  }

  public static var recordID: CKRecord.ID {
    CKRecord.ID(recordName: recordName, zoneID: ClipRecord.zoneID)
  }

  public static func key(from record: CKRecord) -> SyncKey? {
    guard record.recordType == recordType else { return nil }
    return (record.encryptedValues[Field.idKey] as? Data).flatMap(SyncKey.init(data:))
  }

  static func record(with key: SyncKey, updating record: CKRecord? = nil) -> CKRecord {
    let record = record ?? CKRecord(recordType: recordType, recordID: recordID)
    record.encryptedValues[Field.idKey] = key.data
    return record
  }

  /// Reads the account's key, or creates it when this is the first device to need one. When two devices create
  /// one at the same moment the server keeps the first save; the other device's save fails and it takes the
  /// saved key instead.
  public static func fetchOrCreateKey(in database: CKDatabase) async throws -> (key: SyncKey, created: Bool) {
    var base: CKRecord?
    for _ in 0..<3 {
      do {
        let existing = try await database.record(for: recordID)
        if let key = Self.key(from: existing) { return (key, false) }
        // A settings record without a key (written by a later version first): add one.
        base = existing
      } catch let error as CKError where error.code == .unknownItem {
        base = nil
      } catch let error as CKError where error.code == .zoneNotFound {
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: ClipRecord.zoneID)], deleting: [])
        base = nil
      }

      let key = SyncKey.generate()
      let record = record(with: key, updating: base)
      let result = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
      switch result.saveResults[record.recordID] {
      case .success?:
        return (key, true)
      case .failure(let error as CKError)? where error.code == .serverRecordChanged:
        if let server = error.serverRecord, let serverKey = Self.key(from: server) { return (serverKey, false) }
      case .failure(let error)?:
        throw error
      case nil:
        throw CKError(.internalError)
      }
    }
    throw CKError(.serverRecordChanged)
  }
}

/// The key on this device, as a small file next to the sync state, so the iOS app's extensions (keyboard,
/// Share) can name records without reading the whole sync state. Same protection as the clips beside it.
public struct SyncKeyFile: Sendable {
  public let url: URL

  public init(directory: URL) {
    url = directory.appending(path: "sync-key.json")
  }

  public func read() -> SyncKey? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(SyncKey.self, from: data)
  }

  public func write(_ key: SyncKey?) {
    guard let key else {
      try? FileManager.default.removeItem(at: url)
      return
    }
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? JSONEncoder().encode(key).write(to: url, options: .atomic)
  }
}
