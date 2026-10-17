import Foundation
import Testing
@testable import PastronautCore

@Suite struct ClipSearchTests {
  private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
  }

  private func clip(_ text: String, daysAgo: Double = 0, pinned: Bool = false, device: Clip.Device = .mac) -> Clip {
    let date = now.addingTimeInterval(-daysAgo * 86_400)
    return Clip(text: text, sourceDevice: device, firstCopiedAt: date, lastCopiedAt: date, modifiedAt: date, pinned: pinned)
  }

  private var clips: [Clip] {
    [
      clip("https://example.com"),
      clip("ayse@example.com", daysAgo: 3),
      clip("Toplantı Perşembe", daysAgo: 1, pinned: true, device: .iphone),
      clip("#1E6FA8", daysAgo: 20)
    ]
  }

  @Test func textQueryIgnoresCaseAndAccents() {
    #expect(clips.matching("toplanti").map(\.text) == ["Toplantı Perşembe"])
    #expect(clips.matching("EXAMPLE").count == 2)
    #expect(clips.matching("  ").count == 4)
  }

  @Test func tokensOfOneGroupWiden() {
    let result = clips.matching("", tokens: [.link, .email], now: now, calendar: calendar)
    #expect(Set(result.map(\.text)) == ["https://example.com", "ayse@example.com"])
  }

  @Test func tokensOfDifferentGroupsNarrow() {
    #expect(clips.matching("", tokens: [.pinned, .text], now: now, calendar: calendar).map(\.text) == ["Toplantı Perşembe"])
    #expect(clips.matching("", tokens: [.pinned, .link], now: now, calendar: calendar).isEmpty)
    #expect(clips.matching("example", tokens: [.today], now: now, calendar: calendar).map(\.text) == ["https://example.com"])
    #expect(clips.matching("", tokens: [.thisWeek], now: now, calendar: calendar).count == 3)
    #expect(clips.matching("", tokens: [.color], now: now, calendar: calendar).map(\.text) == ["#1E6FA8"])
  }

  @Test func imagesMatchOnlyPinAndDateChips() {
    #expect(ClipSearchToken.allMatch([.today], text: nil, pinned: false, lastCopiedAt: now, now: now, calendar: calendar))
    #expect(!ClipSearchToken.allMatch([.link], text: nil, pinned: true, lastCopiedAt: now, now: now, calendar: calendar))
    #expect(ClipSearchToken.allMatch([], text: nil, pinned: false, lastCopiedAt: .distantPast))
  }

  @Test func sources() {
    #expect(ClipSource.mac.latest(from: clips, count: 2).map(\.text) == ["https://example.com", "ayse@example.com"])
    #expect(ClipSource.iphone.latest(from: clips, count: 5).map(\.text) == ["Toplantı Perşembe"])
    #expect(ClipSource.pinned.latest(from: clips, count: 5).count == 1)
    // Newest first even though a pinned clip exists.
    #expect(ClipSource.all.latest(from: clips, count: 1).map(\.text) == ["https://example.com"])
  }

  @Test func currentClipsMergesSnapshotAndInbox() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let files = SharedClipFiles(directory: directory)
    defer { try? FileManager.default.removeItem(at: directory) }
    try files.writeSnapshot([clip("from snapshot", daysAgo: 1)])
    try files.appendToInbox(clip("waiting in inbox", device: .iphone))
    #expect(files.currentClips().map(\.text) == ["waiting in inbox", "from snapshot"])
  }
}
