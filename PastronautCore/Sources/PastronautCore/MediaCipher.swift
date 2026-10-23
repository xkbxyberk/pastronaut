import CryptoKit
import Foundation

/// Encrypts the bytes of images and files before they become CloudKit assets, which `encryptedValues` can't hold.
///
/// The key is derived from the account's record-name key (`SyncKey`), which only travels in an encrypted field,
/// so every device of the account has it and nobody else does. Each file is bound to its clip: a file moved to
/// another record doesn't open.
public struct MediaCipher: Sendable {
  public enum Failure: Error, Equatable {
    case notMedia
  }

  /// Marks the format, so a later one can be told apart.
  static let magic = Data("PTM1".utf8)

  private let key: SymmetricKey

  public init(syncKey: SyncKey) {
    key = HKDF<SHA256>.deriveKey(
      inputKeyMaterial: SymmetricKey(data: syncKey.data),
      salt: Data("pastronaut.media".utf8),
      info: Data("files v1".utf8),
      outputByteCount: 32
    )
  }

  public func seal(_ data: Data, clipID: String) throws -> Data {
    let box = try AES.GCM.seal(data, using: key, authenticating: Data(clipID.utf8))
    // swiftlint:disable:next force_unwrapping
    return Self.magic + box.combined!
  }

  public func open(_ data: Data, clipID: String) throws -> Data {
    guard data.starts(with: Self.magic) else { throw Failure.notMedia }
    let box = try AES.GCM.SealedBox(combined: data.dropFirst(Self.magic.count))
    return try AES.GCM.open(box, using: key, authenticating: Data(clipID.utf8))
  }
}
