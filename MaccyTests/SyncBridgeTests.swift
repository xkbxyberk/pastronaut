import AppKit
import Defaults
import PastronautCore
import XCTest
@testable import Maccy

// Pastronaut: what may leave the Mac through iCloud sync.
@MainActor
class SyncBridgeTests: XCTestCase {
  private func item(_ contents: [(NSPasteboard.PasteboardType, Data?)]) -> HistoryItem {
    let item = HistoryItem(contents: contents.map { HistoryItemContent(type: $0.0.rawValue, value: $0.1) })
    Storage.shared.context.insert(item)
    return item
  }

  func testPlainTextBecomesAClip() throws {
    let item = item([(.string, Data("hello".utf8))])
    item.application = "com.apple.Safari"
    item.pin = "b"

    let clip = try XCTUnwrap(SyncBridge.clip(for: item, modifiedAt: .now))
    XCTAssertEqual(clip.text, "hello")
    XCTAssertEqual(clip.id, Clip.id(for: "hello"))
    XCTAssertEqual(clip.sourceApp, "com.apple.Safari")
    XCTAssertEqual(clip.sourceDevice, .mac)
    XCTAssertTrue(clip.pinned)
  }

  func testRichTextSyncsItsPlainText() throws {
    let item = item([
      (.rtf, Data("{\\rtf1 hello}".utf8)),
      (.html, Data("<b>hello</b>".utf8)),
      (.string, Data("hello".utf8))
    ])
    XCTAssertEqual(SyncBridge.clip(for: item, modifiedAt: .now)?.text, "hello")
  }

  func testImagesDoNotSync() {
    let item = item([(.png, Data([0x89, 0x50, 0x4E, 0x47])), (.string, Data("caption".utf8))])
    XCTAssertNil(SyncBridge.clip(for: item, modifiedAt: .now))
    XCTAssertNil(SyncBridge.clipID(of: item))
  }

  func testFilesDoNotSync() {
    let url = URL(fileURLWithPath: "/tmp/report.pdf")
    let item = item([(.fileURL, url.dataRepresentation), (.string, Data("report.pdf".utf8))])
    XCTAssertNil(SyncBridge.clip(for: item, modifiedAt: .now))
  }

  func testEmptyTextDoesNotSync() {
    XCTAssertNil(SyncBridge.clip(for: item([(.string, Data())]), modifiedAt: .now))
  }

  func testUniversalClipboardCopiesComeFromIPhone() {
    let item = item([(.string, Data("from phone".utf8)), (.universalClipboard, Data())])
    XCTAssertEqual(SyncBridge.clip(for: item, modifiedAt: .now)?.sourceDevice, .iphone)
  }

  func testConcealedCopiesNeverReachHistory() {
    // Sync only sees items that Clipboard hands to History through its onNewCopy hooks.
    // A password manager's concealed copy must be dropped before that point with default settings.
    let savedIgnoredTypes = Defaults[.ignoredPasteboardTypes]
    defer {
      Defaults[.ignoredPasteboardTypes] = savedIgnoredTypes
      Clipboard.shared.clearHooks()
    }
    Defaults.reset(.ignoredPasteboardTypes)

    let hook = expectation(description: "Concealed copy reaches History")
    hook.isInverted = true
    Clipboard.shared.onNewCopy { _ in hook.fulfill() }
    Clipboard.shared.start()
    NSPasteboard.general.declareTypes([.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")], owner: nil)
    NSPasteboard.general.setString("hunter2", forType: .string)
    waitForExpectations(timeout: 2)
  }

  // MARK: - Collections and export

  func testCollectionsNeedSyncAndText() {
    let saved = Defaults[.iCloudSync]
    defer { Defaults[.iCloudSync] = saved }
    let text = item([(.string, Data("hello".utf8))])
    let image = item([(.png, Data([0x89, 0x50, 0x4E, 0x47]))])
    Defaults[.iCloudSync] = false
    XCTAssertFalse(SyncBridge.shared.canCollect(text))
    Defaults[.iCloudSync] = true
    XCTAssertTrue(SyncBridge.shared.canCollect(text))
    XCTAssertFalse(SyncBridge.shared.canCollect(image))
  }

  func testMembershipIgnoresUnknownCollections() {
    let hello = item([(.string, Data("hello".utf8))])
    let other = item([(.string, Data("other".utf8))])
    let collections = SyncedCollections.shared
    collections.update(
      collections: [ClipCollection(id: "col-a", name: "A", order: 1)],
      clips: [Clip(text: "hello", sourceDevice: .mac, collectionIDs: ["col-a", "col-deleted"])],
      isAvailable: true
    )
    defer { collections.update(collections: [], clips: [], isAvailable: false) }
    XCTAssertEqual(collections.collectionIDs(of: hello), ["col-a"])
    XCTAssertTrue(collections.isKept(hello))
    XCTAssertFalse(collections.isKept(other))
    XCTAssertEqual(collections.count(in: "col-a"), 1)
  }
}
