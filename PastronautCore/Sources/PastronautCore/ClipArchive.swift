import Foundation

/// Pastronaut's export file: text clips with their pins and collections, as readable JSON. Images and files are
/// not included. The same file imports on the Mac and on the iPhone.
public struct ClipArchive: Codable, Equatable, Sendable {
  public static let formatName = "pastronaut-archive"
  public static let currentVersion = 1

  public struct Item: Codable, Equatable, Sendable {
    public var text: String
    public var pinned: Bool
    /// IDs of the archive's own `collections`.
    public var collections: [String]
    public var firstCopiedAt: Date
    public var lastCopiedAt: Date
    public var sourceDevice: Clip.Device?
    public var sourceApp: String?
    public var sourceAppName: String?
    /// Since 1.2; older files have none.
    public var title: String?
  }

  public enum ReadError: Error, Equatable {
    /// Some other JSON, or not JSON at all.
    case notAnArchive
    /// Written by a later Pastronaut.
    case newerVersion(Int)
  }

  public var format: String
  public var version: Int
  public var exportedAt: Date
  public var collections: [ClipCollection]
  public var clips: [Item]

  public init(clips: [Clip], collections: [ClipCollection], exportedAt: Date = .now) {
    let known = Set(collections.map(\.id))
    format = Self.formatName
    version = Self.currentVersion
    self.exportedAt = exportedAt
    self.collections = collections.ordered
    self.clips = clips.inHistoryOrder.map { clip in
      Item(
        text: clip.text,
        pinned: clip.pinned,
        collections: clip.collectionIDs.filter(known.contains),
        firstCopiedAt: clip.firstCopiedAt,
        lastCopiedAt: clip.lastCopiedAt,
        sourceDevice: clip.sourceDevice,
        sourceApp: clip.sourceApp,
        sourceAppName: clip.sourceAppName,
        title: clip.title
      )
    }
  }

  /// One collection on its own ("Export Collection"), to keep or hand to someone: only its clips, and no other
  /// collection. Imports like any export: into a collection of the same name.
  public init(collection: ClipCollection, from clips: [Clip], exportedAt: Date = .now) {
    self.init(
      clips: clips.filter { $0.collectionIDs.contains(collection.id) },
      collections: [collection],
      exportedAt: exportedAt
    )
  }

  public func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(self)
  }

  public static func decode(_ data: Data) throws -> ClipArchive {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    struct Header: Decodable {
      var format: String
      var version: Int
    }
    guard let header = try? decoder.decode(Header.self, from: data), header.format == formatName else {
      throw ReadError.notAnArchive
    }
    guard header.version <= currentVersion else { throw ReadError.newerVersion(header.version) }
    do {
      return try decoder.decode(ClipArchive.self, from: data)
    } catch {
      throw ReadError.notAnArchive
    }
  }

  /// A file name such as "Pastronaut 2026-10-17.json".
  public static func suggestedFileName(on date: Date = .now) -> String {
    let day = date.formatted(.iso8601.year().month().day())
    return "Pastronaut \(day).json"
  }

  /// A file name such as "Pastronaut Adresler 2026-10-22.json"; characters a file name can't hold become spaces.
  public static func suggestedFileName(for collection: ClipCollection, on date: Date = .now) -> String {
    let day = date.formatted(.iso8601.year().month().day())
    let name = collection.name
      .map { "/\\:".contains($0) || $0.isNewline ? " " : String($0) }
      .joined()
      .trimmingCharacters(in: .whitespaces)
    return name.isEmpty ? "Pastronaut \(day).json" : "Pastronaut \(name) \(day).json"
  }

  /// What importing this file into a history changes.
  public struct ImportPlan: Equatable, Sendable {
    /// New clips, and existing ones that gained a pin or a collection. Ready for `ClipSync.upsert`.
    public var clips: [Clip]
    /// Collections to create; ones whose name already exists are reused.
    public var collections: [ClipCollection]
    public var newClipCount: Int
  }

  /// Import only adds: new clips, pins and collection memberships. Nothing is removed or unpinned, so importing
  /// the same file twice changes nothing the second time.
  public func importPlan(
    existingClips: [Clip],
    existingCollections: [ClipCollection],
    device: Clip.Device,
    now: Date = .now
  ) -> ImportPlan {
    var collectionIDs: [String: String] = [:]
    var created: [ClipCollection] = []
    var order = existingCollections.nextOrder
    for collection in collections.ordered {
      let key = collection.name.lowercased()
      if let match = (existingCollections + created).first(where: { $0.name.lowercased() == key }) {
        collectionIDs[collection.id] = match.id
      } else if let name = ClipCollection.cleanName(collection.name) {
        let new = ClipCollection(name: name, order: order, createdAt: now)
        order += 1
        created.append(new)
        collectionIDs[collection.id] = new.id
      }
    }

    let existing = Dictionary(existingClips.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    var changed: [String: Clip] = [:]
    var newClipCount = 0
    for item in clips where !item.text.isEmpty {
      var imported = Clip(
        text: item.text,
        sourceApp: item.sourceApp,
        sourceAppName: item.sourceAppName,
        sourceDevice: item.sourceDevice ?? device,
        firstCopiedAt: item.firstCopiedAt,
        lastCopiedAt: max(item.firstCopiedAt, item.lastCopiedAt),
        modifiedAt: now,
        pinned: item.pinned,
        collectionIDs: item.collections.compactMap { collectionIDs[$0] }
      )
      if let title = Clip.cleanTitle(item.title) {
        imported.setTitle(title, at: now)
      }
      if let base = changed[imported.id] ?? existing[imported.id] {
        var result = base
        result.pinned = base.pinned || imported.pinned
        result.collectionIDs = base.collectionIDs + imported.collectionIDs
        // Only adds, like pins: a title is taken when the clip here has none.
        if result.title == nil, imported.title != nil {
          result.takeTitle(from: imported)
        }
        result.firstCopiedAt = min(base.firstCopiedAt, imported.firstCopiedAt)
        result.lastCopiedAt = max(base.lastCopiedAt, imported.lastCopiedAt)
        guard result != base else { continue }
        result.modifiedAt = max(now, base.modifiedAt.addingTimeInterval(0.001))
        changed[imported.id] = result
      } else {
        changed[imported.id] = imported
        newClipCount += 1
      }
    }
    return ImportPlan(clips: Array(changed.values).inHistoryOrder, collections: created, newClipCount: newClipCount)
  }
}
