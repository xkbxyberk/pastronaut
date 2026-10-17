import Foundation

/// How long unpinned history is kept. Pinned items never expire.
public enum HistoryAge: String, CaseIterable, Codable, Sendable {
  case forever
  case day
  case week
  case month
  case year

  /// Items last copied before this date expire; `nil` keeps everything.
  public func cutoff(before now: Date, calendar: Calendar = .current) -> Date? {
    switch self {
    case .forever: nil
    case .day: calendar.date(byAdding: .day, value: -1, to: now)
    case .week: calendar.date(byAdding: .day, value: -7, to: now)
    case .month: calendar.date(byAdding: .month, value: -1, to: now)
    case .year: calendar.date(byAdding: .year, value: -1, to: now)
    }
  }

  public func isExpired(lastCopiedAt: Date, pinned: Bool, now: Date, calendar: Calendar = .current) -> Bool {
    guard !pinned, let cutoff = cutoff(before: now, calendar: calendar) else { return false }
    return lastCopiedAt < cutoff
  }

  /// Whether switching from `self` to `other` can delete items, which the settings confirm first.
  public func isShorter(than other: HistoryAge) -> Bool {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let mine = cutoff(before: now) ?? .distantPast
    let theirs = other.cutoff(before: now) ?? .distantPast
    return mine > theirs
  }
}

/// How long copying stays paused when chosen from the menu bar.
public enum PauseLength: CaseIterable, Sendable {
  case fifteenMinutes
  case oneHour
  case untilTomorrow
  case indefinitely

  /// When copying resumes by itself; `nil` waits for the user.
  public func end(from now: Date, calendar: Calendar = .current) -> Date? {
    switch self {
    case .fifteenMinutes: now.addingTimeInterval(15 * 60)
    case .oneHour: now.addingTimeInterval(60 * 60)
    case .untilTomorrow: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
    case .indefinitely: nil
    }
  }
}
