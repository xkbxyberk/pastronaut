import Foundation
import Testing
@testable import PastronautCore

@Suite struct SharedClipFilesTests {
  let files = SharedClipFiles(directory: FileManager.default.temporaryDirectory.appending(path: "pastronaut-\(UUID().uuidString)"))

  @Test func missingFilesReadAsEmpty() throws {
    #expect(files.readSnapshot().isEmpty)
    #expect(files.readInbox().isEmpty)
    #expect(try files.drainInbox().isEmpty)
  }

  @Test func snapshotRoundTrip() throws {
    let clips = [Clip(text: "a", sourceDevice: .mac), Clip(text: "b", sourceDevice: .iphone, pinned: true)]
    try files.writeSnapshot(clips)
    #expect(files.readSnapshot() == clips)
  }

  @Test func inboxMergesDuplicatesAndDrainsOnce() throws {
    let early = Date(timeIntervalSince1970: 1_000)
    let late = Date(timeIntervalSince1970: 2_000)
    try files.appendToInbox(Clip(text: "x", sourceDevice: .iphone, firstCopiedAt: early))
    try files.appendToInbox(Clip(text: "x", sourceDevice: .iphone, firstCopiedAt: late))
    try files.appendToInbox(Clip(text: "y", sourceDevice: .iphone, firstCopiedAt: late))

    let inbox = files.readInbox()
    #expect(inbox.map(\.text) == ["x", "y"])
    #expect(inbox[0].firstCopiedAt == early)
    #expect(inbox[0].lastCopiedAt == late)

    #expect(try files.drainInbox().count == 2)
    #expect(try files.drainInbox().isEmpty)
  }

  @Test func historyOrderPutsPinnedFirstThenNewest() {
    let clips = [
      Clip(text: "old", sourceDevice: .mac, firstCopiedAt: Date(timeIntervalSince1970: 1)),
      Clip(text: "new", sourceDevice: .mac, firstCopiedAt: Date(timeIntervalSince1970: 3)),
      Clip(text: "pinned", sourceDevice: .mac, firstCopiedAt: Date(timeIntervalSince1970: 2), pinned: true)
    ]
    #expect(clips.inHistoryOrder.map(\.text) == ["pinned", "new", "old"])
  }
}
