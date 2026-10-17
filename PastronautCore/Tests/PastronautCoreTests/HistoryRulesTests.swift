import Foundation
import Testing
@testable import PastronautCore

@Suite struct HistoryRulesTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
  }

  private func date(_ text: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = calendar.timeZone
    formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
    return formatter.date(from: text)!
  }

  @Test func retention() {
    let now = date("2026-10-17T12:00:00")
    #expect(!HistoryAge.forever.isExpired(lastCopiedAt: date("2000-01-01T00:00:00"), pinned: false, now: now))
    #expect(HistoryAge.day.isExpired(lastCopiedAt: date("2026-10-16T11:59:00"), pinned: false, now: now, calendar: calendar))
    #expect(!HistoryAge.day.isExpired(lastCopiedAt: date("2026-10-16T12:01:00"), pinned: false, now: now, calendar: calendar))
    #expect(HistoryAge.month.isExpired(lastCopiedAt: date("2026-09-16T00:00:00"), pinned: false, now: now, calendar: calendar))
    #expect(!HistoryAge.month.isExpired(lastCopiedAt: date("2026-09-18T00:00:00"), pinned: false, now: now, calendar: calendar))
    // Pinned items never expire.
    #expect(!HistoryAge.day.isExpired(lastCopiedAt: date("2020-01-01T00:00:00"), pinned: true, now: now))
  }

  @Test func shorterRetentionNeedsConfirmation() {
    #expect(HistoryAge.week.isShorter(than: .month))
    #expect(HistoryAge.year.isShorter(than: .forever))
    #expect(!HistoryAge.forever.isShorter(than: .day))
    #expect(!HistoryAge.month.isShorter(than: .month))
  }

  @Test func pauseEnds() {
    let now = date("2026-10-17T23:50:00")
    #expect(PauseLength.fifteenMinutes.end(from: now) == now.addingTimeInterval(900))
    #expect(PauseLength.oneHour.end(from: now) == now.addingTimeInterval(3600))
    #expect(PauseLength.untilTomorrow.end(from: now, calendar: calendar) == date("2026-10-18T00:00:00"))
    #expect(PauseLength.indefinitely.end(from: now) == nil)
  }
}
