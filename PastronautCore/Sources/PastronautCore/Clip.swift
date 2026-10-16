import CryptoKit
import Foundation

/// A synced clipboard entry. Platform-neutral: no AppKit, UIKit or SwiftData.
public struct Clip: Codable, Equatable, Hashable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case text
    case url
  }

  public enum Device: String, Codable, Sendable {
    case mac
    case iphone
    case ipad
  }

  /// Stable identity derived from the content (see `Clip.id(for:)`), shared by every device.
  public let id: String
  public let text: String
  public var kind: Kind
  public var sourceApp: String?
  public var sourceDevice: Device
  public var firstCopiedAt: Date
  public var lastCopiedAt: Date
  /// Last user-visible change (copy, pin, unpin). Decides last-writer-wins fields in `merged(with:)`.
  public var modifiedAt: Date
  public var pinned: Bool

  public init(
    text: String,
    sourceApp: String? = nil,
    sourceDevice: Device,
    firstCopiedAt: Date = .now,
    lastCopiedAt: Date? = nil,
    modifiedAt: Date? = nil,
    pinned: Bool = false
  ) {
    self.id = Clip.id(for: text)
    self.text = text
    self.kind = Clip.kind(of: text)
    self.sourceApp = sourceApp
    self.sourceDevice = sourceDevice
    self.firstCopiedAt = firstCopiedAt
    self.lastCopiedAt = lastCopiedAt ?? firstCopiedAt
    self.modifiedAt = modifiedAt ?? lastCopiedAt ?? firstCopiedAt
    self.pinned = pinned
  }

  /// SHA-256 of the text with line endings unified, so the same copy on any device maps to one record.
  /// Other whitespace is significant: "a" and "a " are different clips.
  public static func id(for text: String) -> String {
    let normalized = text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    let digest = SHA256.hash(data: Data(normalized.utf8))
    return "clip-" + digest.map { String(format: "%02x", $0) }.joined()
  }

  static func kind(of text: String) -> Kind {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.contains(where: \.isWhitespace),
          let url = URL(string: trimmed),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme),
          url.host != nil else {
      return .text
    }
    return .url
  }

  /// The same text was copied again. `copy` is a fresh capture that knows nothing about this clip's pin,
  /// so unlike `merged(with:)` the pin is kept; copy times widen and the newer copy names the source.
  /// `modifiedAt` moves forward so other devices take this version, pin included.
  public func copiedAgain(_ copy: Clip) -> Clip {
    precondition(id == copy.id, "Only copies of the same text can be combined")
    var result = self
    result.firstCopiedAt = min(firstCopiedAt, copy.firstCopiedAt)
    result.lastCopiedAt = max(lastCopiedAt, copy.lastCopiedAt)
    result.modifiedAt = max(modifiedAt, copy.modifiedAt)
    if copy.lastCopiedAt > lastCopiedAt {
      result.sourceDevice = copy.sourceDevice
      result.sourceApp = copy.sourceApp ?? sourceApp
    }
    return result
  }

  /// Combines two versions of the same clip from different devices.
  /// Copy dates widen to cover both; source and pin state follow the most recent modification.
  public func merged(with other: Clip) -> Clip {
    precondition(id == other.id, "Only versions of the same clip can be merged")
    let newer = other.modifiedAt > modifiedAt ? other : self
    var result = newer
    result.firstCopiedAt = min(firstCopiedAt, other.firstCopiedAt)
    result.lastCopiedAt = max(lastCopiedAt, other.lastCopiedAt)
    result.modifiedAt = max(modifiedAt, other.modifiedAt)
    return result
  }
}
