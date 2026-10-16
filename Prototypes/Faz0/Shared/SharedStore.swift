import Foundation

/// App Group JSON store shared by the iOS app and the keyboard extension.
/// Prototype only: a single small JSON file, no SwiftData.
enum ProtoIDs {
  static let appGroup = "group.com.xkbxyberk.pastronaut"
  static let container = "iCloud.com.xkbxyberk.pastronaut"
  static let zoneName = "ProtoZone"
  static let recordType = "ProtoClip"
}

struct ProtoItem: Codable, Identifiable, Hashable {
  var id: String
  var text: String
  var date: Date
  var source: String
}

struct ProtoState: Codable {
  var items: [ProtoItem] = []
  var pendingCaptures: [ProtoItem] = []
  var log: [String] = []
  var lastChangeCount: Int = -1
}

enum SharedStore {
  /// nil when the App Group container is unavailable (e.g. keyboard without Full Access).
  /// Kept under Library/ so `devicectl device copy from` can fetch it for inspection.
  static var fileURL: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: ProtoIDs.appGroup)?
      .appending(path: "Library/proto.json")
  }

  static func load() -> ProtoState? {
    guard let url = fileURL else { return nil }
    guard let data = try? Data(contentsOf: url) else { return ProtoState() }
    return (try? JSONDecoder().decode(ProtoState.self, from: data)) ?? ProtoState()
  }

  @discardableResult
  static func update(_ change: (inout ProtoState) -> Void) -> Bool {
    guard let url = fileURL, var state = load() else { return false }
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    change(&state)
    state.log = Array(state.log.suffix(50))
    guard let data = try? JSONEncoder().encode(state) else { return false }
    return (try? data.write(to: url, options: .atomic)) != nil
  }

  static func log(_ line: String) {
    let stamp = Date.now.formatted(date: .omitted, time: .standard)
    update { $0.log.append("\(stamp) \(line)") }
  }
}
