import Foundation

/// Queue: clips the keyboard types one after another, one per tap.
///
/// iOS doesn't tell an app when another app pastes, so a clipboard that moves on after each paste (the Mac's
/// queue) can't work here. The keyboard does the typing itself, so it can. The app writes a `QueueRequest` to
/// the App Group; the keyboard keeps its progress in a `ClipQueue` in its own container, which works without
/// Full Access (a keyboard without it can read the App Group but not write it).
public struct QueueRequest: Codable, Equatable, Sendable {
  public var id: UUID
  /// In the order they are typed.
  public var clipIDs: [String]
  public var createdAt: Date

  public init(clipIDs: [String], id: UUID = UUID(), createdAt: Date = .now) {
    self.id = id
    self.clipIDs = clipIDs
    self.createdAt = createdAt
  }

  /// A queue nobody finished in this long is dropped instead of surprising someone the next day.
  public static let lifetime: TimeInterval = 12 * 60 * 60

  public func isExpired(at date: Date = .now) -> Bool {
    date.timeIntervalSince(createdAt) > Self.lifetime
  }
}

/// The keyboard's progress through a `QueueRequest`.
public struct ClipQueue: Codable, Equatable, Sendable {
  public let requestID: UUID
  /// Still to type, the next one first.
  public private(set) var pending: [String]
  public private(set) var typedCount = 0

  public init(_ request: QueueRequest) {
    requestID = request.id
    pending = request.clipIDs
  }

  public var nextID: String? { pending.first }
  public var isFinished: Bool { pending.isEmpty }
  public var total: Int { typedCount + pending.count }
  /// 1-based, for "Next (2 of 5)".
  public var nextNumber: Int { typedCount + 1 }

  /// The next clip was typed.
  public mutating func advance() {
    guard !pending.isEmpty else { return }
    pending.removeFirst()
    typedCount += 1
  }

  /// Moves past the next clip without typing it.
  public mutating func skip() {
    guard !pending.isEmpty else { return }
    pending.removeFirst()
  }

  /// Types what is left in the opposite order.
  public mutating func reverse() {
    pending.reverse()
  }

  /// Drops clips deleted since the queue started.
  public mutating func keepOnly(_ existing: Set<String>) {
    pending.removeAll { !existing.contains($0) }
  }
}

/// How "Combine & Copy" joins several clips into one text.
public enum ClipSeparator: String, CaseIterable, Codable, Sendable {
  case newLine
  case blankLine
  case comma
  case space

  public var string: String {
    switch self {
    case .newLine: "\n"
    case .blankLine: "\n\n"
    case .comma: ", "
    case .space: " "
    }
  }
}

public extension Sequence<Clip> {
  /// The clips' texts in this order, joined with `separator`. Line breaks and spaces at the ends of each text are
  /// dropped so the separator is the only thing between two clips; empty ones are left out.
  func combinedText(separator: ClipSeparator) -> String {
    map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: separator.string)
  }
}
