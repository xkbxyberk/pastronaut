import AppKit
import PastronautCore
import UniformTypeIdentifiers
import XCTest
@testable import Maccy

// Pastronaut 1.3: images, PDFs and files in iCloud sync, as the Mac reads and shows them.
@MainActor
class SyncMediaTests: XCTestCase {
  private var folder: URL!

  override func setUpWithError() throws {
    folder = FileManager.default.temporaryDirectory.appending(path: "sync-media-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: folder)
  }

  private func item(_ contents: [(NSPasteboard.PasteboardType, Data?)]) -> HistoryItem {
    let item = HistoryItem(contents: contents.map { HistoryItemContent(type: $0.0.rawValue, value: $0.1) })
    Storage.shared.context.insert(item)
    return item
  }

  private func source(files: [URL] = [], image: Data? = nil, pdf: Data? = nil) -> MediaCapture.Source {
    MediaCapture.Source(
      fileURLs: files, imageData: image, pdfData: pdf, sourceApp: nil, sourceAppName: nil,
      copiedAt: Date(timeIntervalSince1970: 1_700_000_000), pinned: false
    )
  }

  private func png(width: Int, height: Int) throws -> Data {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    NSColor.systemTeal.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    image.unlockFocus()
    let tiff = try XCTUnwrap(image.tiffRepresentation)
    return try XCTUnwrap(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
  }

  // MARK: - Reading what was copied

  func testFinderFilesAreReadWithTheirNames() throws {
    let report = folder.appending(path: "Report.pdf")
    let notes = folder.appending(path: "notes.txt")
    try Data("%PDF-1.4".utf8).write(to: report)
    try Data("hello".utf8).write(to: notes)

    let parts = try XCTUnwrap(MediaCapture.read(source(files: [report, notes]), quality: .optimized, maxBytes: 1_000))
    XCTAssertEqual(parts.map(\.name), ["Report.pdf", "notes.txt"])
    XCTAssertEqual(parts.map(\.type), [UTType.pdf.identifier, UTType.plainText.identifier])
    XCTAssertEqual(parts[1].data, Data("hello".utf8))
  }

  func testFoldersAndLargeFilesStayOnThisMac() throws {
    let big = folder.appending(path: "big.bin")
    try Data(count: 2_000).write(to: big)
    XCTAssertNil(MediaCapture.read(source(files: [big]), quality: .optimized, maxBytes: 1_000))
    XCTAssertNil(MediaCapture.read(source(files: [folder]), quality: .optimized, maxBytes: 10_000))
  }

  func testCopiedImagesAreSentAsHEICAndKeepTheirOriginalAsIdentity() throws {
    let original = try png(width: 600, height: 400)
    let parts = try XCTUnwrap(MediaCapture.read(source(image: original), quality: .optimized, maxBytes: 10_000_000))
    XCTAssertEqual(parts.count, 1)
    XCTAssertEqual(parts[0].original, original)
    XCTAssertTrue(parts[0].name.hasPrefix("Image "))
    // HEIC unless the PNG was already smaller.
    XCTAssertTrue([UTType.heic.identifier, UTType.png.identifier].contains(parts[0].type))
    XCTAssertLessThanOrEqual(parts[0].data.count, original.count)

    let kept = try XCTUnwrap(MediaCapture.read(source(image: original), quality: .original, maxBytes: 10_000_000))
    XCTAssertEqual(kept[0].data, original)
  }

  func testCopiedPDFDataBecomesADocument() throws {
    let parts = try XCTUnwrap(MediaCapture.read(source(pdf: Data("%PDF".utf8)), quality: .optimized, maxBytes: 100))
    XCTAssertTrue(parts[0].name.hasPrefix("Document ") && parts[0].name.hasSuffix(".pdf"))
  }

  /// Preview copies a PDF selection with a picture of it, which can be far over the limit (27 MB in the 1.3 E2E).
  func testAPDFCopiedWithAPictureOfItIsSentAsThePDF() throws {
    let picture = Data(repeating: 0, count: 5_000)
    let parts = try XCTUnwrap(MediaCapture.read(
      source(image: picture, pdf: Data("%PDF".utf8)), quality: .optimized, maxBytes: 1_000
    ))
    XCTAssertEqual(parts.count, 1)
    XCTAssertTrue(parts[0].name.hasSuffix(".pdf"))
  }

  // MARK: - Identity and titles

  func testMediaItemsAreFoundByTheIDTheyWereSentWith() {
    let image = item([(.png, Data([1, 2, 3]))])
    XCTAssertNil(SyncBridge.clipID(of: image))
    image.contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.pastronautMediaID.rawValue, value: Data("media-abc".utf8)))
    XCTAssertEqual(SyncBridge.clipID(of: image), "media-abc")
    XCTAssertEqual(image.pastronautMediaID, "media-abc")
    // Still not a text clip.
    XCTAssertNil(SyncBridge.clip(for: image, modifiedAt: .now))
  }

  func testMediaTitlesUseTheTextOrTheFileNames() {
    let file = ClipMedia.File(name: "Invoice.pdf", type: UTType.pdf.identifier, byteCount: 1, sha256: "x")
    let withText = Clip(media: ClipMedia(kind: .pdf, files: [file], recognizedText: "Invoice 42\nTotal"), contentHashes: ["a"], sourceDevice: .iphone)
    XCTAssertEqual(SyncBridge.mediaTitle(of: withText), "Invoice 42")
    let plain = Clip(media: ClipMedia(kind: .file, files: [file, file]), contentHashes: ["b"], sourceDevice: .iphone)
    XCTAssertEqual(SyncBridge.mediaTitle(of: plain), "Invoice.pdf, Invoice.pdf")
  }

  // MARK: - History limit

  func testTheHistoryLimitOnlyHidesCopiesFromOtherDevices() {
    let mine = item([(.string, Data("from this Mac".utf8))])
    let theirs = item([(.string, Data("from the iPhone".utf8)), (.pastronautFromIPhone, Data())])
    let pruned = SyncBridge.removals(of: [mine, theirs], pruning: true)
    XCTAssertEqual(pruned.delete, [Clip.id(for: "from this Mac")])
    XCTAssertEqual(pruned.dismiss, [Clip.id(for: "from the iPhone")])

    // Deleting by hand removes both everywhere.
    let deleted = SyncBridge.removals(of: [mine, theirs], pruning: false)
    XCTAssertEqual(deleted.delete.count, 2)
    XCTAssertTrue(deleted.dismiss.isEmpty)
  }

  func testClipsPinnedInICloudAreKeptWithoutAPinKey() {
    let unpinnedHere = item([(.string, Data("pinned on the iPhone".utf8))])
    let other = item([(.string, Data("not pinned".utf8))])
    let pinned = Clip(text: "pinned on the iPhone", sourceDevice: .iphone, pinned: true)
    SyncedCollections.shared.update(collections: [], clips: [pinned, Clip(text: "not pinned", sourceDevice: .mac)], isAvailable: true)
    defer { SyncedCollections.shared.update(collections: [], clips: [], isAvailable: false) }
    XCTAssertTrue(SyncedCollections.shared.isKept(unpinnedHere))
    XCTAssertFalse(SyncedCollections.shared.isKept(other))
  }

  // MARK: - App icons

  func testAppIconsAreSmallPNGs() throws {
    let icon = NSWorkspace.shared.icon(forFile: "/System/Applications/TextEdit.app")
    let png = try XCTUnwrap(SyncBridge.iconPNG(icon))
    XCTAssertLessThanOrEqual(png.count, AppIcon.maxBytes)
    let rep = try XCTUnwrap(NSBitmapImageRep(data: png))
    XCTAssertEqual(rep.pixelsWide, AppIcon.side)
  }
}
