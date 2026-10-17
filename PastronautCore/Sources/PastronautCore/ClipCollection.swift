import Foundation

/// A named group of clips the user keeps (addresses, snippets, a project). Membership lives on the clip
/// (`Clip.collectionIDs`); this is only the name and its place in the list.
public struct ClipCollection: Codable, Equatable, Hashable, Identifiable, Sendable {
  /// Random, so the record name in iCloud says nothing about the name.
  public let id: String
  public var name: String
  /// Position in lists; smaller first.
  public var order: Double
  public var createdAt: Date
  /// Last rename or move. The newer version wins when two devices changed the same collection.
  public var modifiedAt: Date

  public init(id: String = ClipCollection.newID(), name: String, order: Double, createdAt: Date = .now, modifiedAt: Date? = nil) {
    self.id = id
    self.name = name
    self.order = order
    self.createdAt = createdAt
    self.modifiedAt = modifiedAt ?? createdAt
  }

  public static func newID() -> String {
    "col-" + UUID().uuidString.lowercased()
  }

  public static func isValidID(_ id: String) -> Bool {
    id.hasPrefix("col-")
  }

  /// Names are trimmed and limited so a list row stays readable; nil when nothing is left.
  public static func cleanName(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return String(trimmed.prefix(60))
  }

  public func merged(with other: ClipCollection) -> ClipCollection {
    precondition(id == other.id, "Only versions of the same collection can be merged")
    var result = other.modifiedAt > modifiedAt ? other : self
    result.createdAt = min(createdAt, other.createdAt)
    return result
  }
}

public extension Collection<ClipCollection> {
  /// List order, then name, so two devices that added collections at once still agree.
  var ordered: [ClipCollection] {
    sorted { lhs, rhs in
      if lhs.order != rhs.order { return lhs.order < rhs.order }
      let byName = lhs.name.localizedStandardCompare(rhs.name)
      return byName == .orderedSame ? lhs.id < rhs.id : byName == .orderedAscending
    }
  }

  /// The order value for a collection added at the end.
  var nextOrder: Double {
    (map(\.order).max() ?? 0) + 1
  }
}
