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
  /// Bundle identifier of the app the text was copied from (Mac uses it for icons and ignore rules).
  public var sourceApp: String?
  /// Readable name of that app ("Safari"), resolved where it was copied: other devices cannot look it up.
  public var sourceAppName: String?
  public var sourceDevice: Device
  public var firstCopiedAt: Date
  public var lastCopiedAt: Date
  /// Last user-visible change (copy, pin, unpin). Decides last-writer-wins fields in `merged(with:)`.
  public var modifiedAt: Date
  public var pinned: Bool
  /// Collections the clip belongs to (`ClipCollection.id`), sorted. Like the pin, follows the newest change.
  /// A clip in any collection is kept like a pinned one: history limits and clean-ups leave it alone.
  public var collectionIDs: [String] {
    didSet { collectionIDs = Self.normalized(collectionIDs) }
  }

  public init(
    text: String,
    sourceApp: String? = nil,
    sourceAppName: String? = nil,
    sourceDevice: Device,
    firstCopiedAt: Date = .now,
    lastCopiedAt: Date? = nil,
    modifiedAt: Date? = nil,
    pinned: Bool = false,
    collectionIDs: [String] = []
  ) {
    self.id = Clip.id(for: text)
    self.text = text
    self.kind = Clip.kind(of: text)
    self.sourceApp = sourceApp
    self.sourceAppName = sourceAppName
    self.sourceDevice = sourceDevice
    self.firstCopiedAt = firstCopiedAt
    self.lastCopiedAt = lastCopiedAt ?? firstCopiedAt
    self.modifiedAt = modifiedAt ?? lastCopiedAt ?? firstCopiedAt
    self.pinned = pinned
    self.collectionIDs = Self.normalized(collectionIDs)
  }

  /// Pinned, or in a collection: clean-ups must not remove it.
  public var isKept: Bool { pinned || !collectionIDs.isEmpty }

  public func isIn(_ collectionID: String) -> Bool { collectionIDs.contains(collectionID) }

  static func normalized(_ ids: [String]) -> [String] {
    Array(Set(ids)).sorted()
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

  /// The same text was copied again. `copy` is a fresh capture that knows nothing about this clip's pin or
  /// collections, so unlike `merged(with:)` they are kept; copy times widen and the newer copy names the source.
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
      result.sourceAppName = copy.sourceAppName ?? sourceAppName
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

extension Clip {
  enum CodingKeys: String, CodingKey {
    case id, text, kind, sourceApp, sourceAppName, sourceDevice, firstCopiedAt, lastCopiedAt, modifiedAt, pinned
    case collectionIDs
  }

  /// Files written before collections existed have no `collectionIDs`.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    text = try container.decode(String.self, forKey: .text)
    kind = try container.decode(Kind.self, forKey: .kind)
    sourceApp = try container.decodeIfPresent(String.self, forKey: .sourceApp)
    sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
    sourceDevice = try container.decode(Device.self, forKey: .sourceDevice)
    firstCopiedAt = try container.decode(Date.self, forKey: .firstCopiedAt)
    lastCopiedAt = try container.decode(Date.self, forKey: .lastCopiedAt)
    modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
    pinned = try container.decode(Bool.self, forKey: .pinned)
    collectionIDs = Self.normalized(try container.decodeIfPresent([String].self, forKey: .collectionIDs) ?? [])
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(text, forKey: .text)
    try container.encode(kind, forKey: .kind)
    try container.encodeIfPresent(sourceApp, forKey: .sourceApp)
    try container.encodeIfPresent(sourceAppName, forKey: .sourceAppName)
    try container.encode(sourceDevice, forKey: .sourceDevice)
    try container.encode(firstCopiedAt, forKey: .firstCopiedAt)
    try container.encode(lastCopiedAt, forKey: .lastCopiedAt)
    try container.encode(modifiedAt, forKey: .modifiedAt)
    try container.encode(pinned, forKey: .pinned)
    if !collectionIDs.isEmpty {
      try container.encode(collectionIDs, forKey: .collectionIDs)
    }
  }
}
