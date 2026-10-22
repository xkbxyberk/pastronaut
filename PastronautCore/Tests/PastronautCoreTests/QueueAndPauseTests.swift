import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import PastronautCore

@Suite struct ClipQueueTests {
  let request = QueueRequest(clipIDs: ["a", "b", "c"], createdAt: Date(timeIntervalSince1970: 1_000))

  @Test func typesInOrderAndCounts() {
    var queue = ClipQueue(request)
    #expect(queue.nextID == "a")
    #expect(queue.nextNumber == 1)
    #expect(queue.total == 3)
    queue.advance()
    #expect(queue.nextID == "b")
    #expect(queue.nextNumber == 2)
    queue.advance()
    queue.advance()
    #expect(queue.isFinished)
    #expect(queue.nextID == nil)
    queue.advance()
    #expect(queue.typedCount == 3)
  }

  @Test func skippingDoesNotCountAsTyped() {
    var queue = ClipQueue(request)
    queue.skip()
    #expect(queue.nextID == "b")
    #expect(queue.typedCount == 0)
    #expect(queue.total == 2)
  }

  @Test func reversingTurnsWhatIsLeft() {
    var queue = ClipQueue(request)
    queue.advance()
    queue.reverse()
    #expect(queue.pending == ["c", "b"])
    #expect(queue.nextNumber == 2)
  }

  @Test func endingLeavesNothingToType() {
    var queue = ClipQueue(request)
    queue.advance()
    queue.end()
    #expect(queue.isFinished)
    #expect(queue.nextID == nil)
    #expect(queue.typedCount == 1)
  }

  @Test func copyOrderIsOldestFirst() {
    let base = Date(timeIntervalSince1970: 1_000)
    let first = Clip(text: "first", sourceDevice: .mac, firstCopiedAt: base, lastCopiedAt: base, modifiedAt: base)
    let second = Clip(text: "second", sourceDevice: .mac, firstCopiedAt: base, lastCopiedAt: base.addingTimeInterval(5), modifiedAt: base)
    let third = Clip(text: "third", sourceDevice: .mac, firstCopiedAt: base, lastCopiedAt: base.addingTimeInterval(9), modifiedAt: base)
    // The history lists the newest first.
    #expect([third, first, second].inCopyOrder.map(\.text) == ["first", "second", "third"])
  }

  @Test func deletedClipsLeaveTheQueue() {
    var queue = ClipQueue(request)
    queue.keepOnly(["a", "c"])
    #expect(queue.pending == ["a", "c"])
  }

  @Test func oldRequestsExpire() {
    #expect(!request.isExpired(at: Date(timeIntervalSince1970: 1_000 + 60)))
    #expect(request.isExpired(at: Date(timeIntervalSince1970: 1_000 + QueueRequest.lifetime + 1)))
  }

  @Test func requestFileRoundTripsAndClears() throws {
    let files = SharedClipFiles(directory: FileManager.default.temporaryDirectory.appending(path: "pastronaut-\(UUID().uuidString)"))
    #expect(files.readQueue() == nil)
    let fresh = QueueRequest(clipIDs: ["x", "y"])
    try files.writeQueue(fresh)
    #expect(files.readQueue() == fresh)
    #expect(files.readQueue(now: .now.addingTimeInterval(QueueRequest.lifetime + 1)) == nil)
    try files.writeQueue(nil)
    #expect(files.readQueue() == nil)
  }

  @Test func combinesTextsWithTheChosenSeparator() {
    let clips = [
      Clip(text: " first\n", sourceDevice: .mac),
      Clip(text: "   ", sourceDevice: .mac),
      Clip(text: "second", sourceDevice: .iphone)
    ]
    #expect(clips.combinedText(separator: .newLine) == "first\nsecond")
    #expect(clips.combinedText(separator: .blankLine) == "first\n\nsecond")
    #expect(clips.combinedText(separator: .comma) == "first, second")
    #expect(clips.combinedText(separator: .space) == "first second")
  }
}

@Suite struct SavingPauseTests {
  func defaults() -> UserDefaults {
    let name = "pastronaut-tests-\(UUID().uuidString)"
    return UserDefaults(suiteName: name)!
  }

  let now = Date(timeIntervalSince1970: 1_000_000)

  @Test func pauseEndsByItself() {
    let store = defaults()
    SavingPause.pause(.fifteenMinutes, in: store, from: now)
    #expect(SavingPause.isPaused(in: store, at: now.addingTimeInterval(14 * 60)))
    #expect(!SavingPause.isPaused(in: store, at: now.addingTimeInterval(16 * 60)))
  }

  @Test func untilResumedWaitsForThePerson() {
    let store = defaults()
    SavingPause.pause(.indefinitely, in: store, from: now)
    #expect(SavingPause.pausedUntil(in: store, at: now.addingTimeInterval(86_400 * 365)) == .distantFuture)
    SavingPause.resume(in: store)
    #expect(!SavingPause.isPaused(in: store, at: now))
  }

  @Test func automaticSavingNeedsTheSettingAndNoPause() {
    let store = defaults()
    #expect(AutoCapture.isActive(in: store, at: now))
    store.set(false, forKey: AutoCapture.settingKey)
    #expect(!AutoCapture.isActive(in: store, at: now))
    store.set(true, forKey: AutoCapture.settingKey)
    SavingPause.pause(.oneHour, in: store, from: now)
    #expect(!AutoCapture.isActive(in: store, at: now.addingTimeInterval(60)))
    #expect(AutoCapture.isActive(in: store, at: now.addingTimeInterval(2 * 60 * 60)))
  }
}

@Suite struct TextRecognitionTests {
  /// Black text on white, as a scanned page would be.
  func image(of text: String) throws -> CGImage {
    let width = 900, height = 220
    let context = try #require(CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let font = CTFontCreateWithName("Helvetica" as CFString, 64, nil)
    let attributes: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    context.textPosition = CGPoint(x: 40, y: 80)
    CTLineDraw(line, context)
    return try #require(context.makeImage())
  }

  @Test func readsPrintedText() async throws {
    let text = try await TextRecognition.text(in: image(of: "Pastronaut 2026"))
    #expect(text.replacingOccurrences(of: " ", with: "").lowercased().contains("pastronaut2026"))
  }

  @Test func blankPagesAreSkipped() async throws {
    let pages = [try image(of: ""), try image(of: "Second page")]
    let text = await TextRecognition.text(inPages: pages)
    #expect(text?.lowercased().contains("second page") == true)
  }

  @Test func prefersThePersonsLanguagesThenTurkishAndEnglish() {
    let languages = TextRecognition.languages(preferred: ["de-DE"])
    #expect(!languages.isEmpty)
    if TextRecognition.readsTurkish {
      #expect(languages.contains { $0.hasPrefix("tr") })
    }
    #expect(languages.contains { $0.hasPrefix("en") })
  }
}

@Suite struct CachePrunerTests {
  let directory = FileManager.default.temporaryDirectory.appending(path: "pastronaut-cache-\(UUID().uuidString)")

  func write(_ name: String, bytes: Int, age: TimeInterval) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appending(path: name)
    try Data(count: bytes).write(to: url)
    try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(-age)], ofItemAtPath: url.path)
  }

  func names() -> Set<String> {
    Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
  }

  @Test func removesFilesOfDeletedClips() throws {
    try write("clip-a.json", bytes: 10, age: 0)
    try write("clip-a.jpg", bytes: 100, age: 0)
    try write("clip-gone.json", bytes: 10, age: 0)
    try write("clip-gone.jpg", bytes: 100, age: 0)
    try write("notes.txt", bytes: 5, age: 0)
    let removed = CachePruner.prune(directory, keeping: ["clip-a"], maxBytes: 1_000)
    #expect(removed == 110)
    #expect(names() == ["clip-a.json", "clip-a.jpg", "notes.txt"])
  }

  @Test func dropsTheOldestClipsUntilTheFolderFits() throws {
    try write("clip-old.json", bytes: 10, age: 300)
    try write("clip-old.jpg", bytes: 500, age: 300)
    try write("clip-mid.jpg", bytes: 500, age: 200)
    try write("clip-new.jpg", bytes: 500, age: 100)
    CachePruner.prune(directory, keeping: ["clip-old", "clip-mid", "clip-new"], maxBytes: 1_000)
    #expect(names() == ["clip-mid.jpg", "clip-new.jpg"])
  }

  @Test func missingFolderIsFine() {
    #expect(CachePruner.prune(directory, keeping: [], maxBytes: 0) == 0)
  }
}
