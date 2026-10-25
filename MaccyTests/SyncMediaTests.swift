import AppKit
import Defaults
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

  /// Settings › Appearance › Picture and PDF rows: a picture row shows its picture, the kind's icon or neither, and
  /// always a name ("Picture 64 × 32" when it has none).
  func testPictureRowsFollowTheChosenStyle() throws {
    let image = NSImage(size: NSSize(width: 64, height: 32), flipped: false) { rect in
      NSColor.systemTeal.setFill()
      rect.fill()
      return true
    }
    let png = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation))?.representation(using: .png, properties: [:]))
    let picture = item([(.png, png)])
    let pdf = item([(.pdf, Data("%PDF-1.4".utf8)), (.png, png)])
    pdf.title = "Fatura Ekim.pdf"
    let text = item([(.string, Data("plain text".utf8))])
    defer { Defaults.reset(.mediaRowStyle) }

    Defaults[.mediaRowStyle] = .previewAndName
    var row = try XCTUnwrap(ClipRowInfo(HistoryItemDecorator(picture)))
    XCTAssertEqual(row.kind, .image)
    XCTAssertTrue(row.showsPicture)
    XCTAssertFalse(row.showsIcon)
    XCTAssertEqual(row.name, SyncBridge.pictureTitle(width: 64, height: 32))
    row = try XCTUnwrap(ClipRowInfo(HistoryItemDecorator(pdf)))
    XCTAssertEqual(row.kind, .pdf)
    XCTAssertNil(row.name, "its own title shows")

    Defaults[.mediaRowStyle] = .iconAndName
    row = try XCTUnwrap(ClipRowInfo(HistoryItemDecorator(picture)))
    XCTAssertFalse(row.showsPicture)
    XCTAssertTrue(row.showsIcon)

    Defaults[.mediaRowStyle] = .nameOnly
    row = try XCTUnwrap(ClipRowInfo(HistoryItemDecorator(picture)))
    XCTAssertFalse(row.showsPicture)
    XCTAssertFalse(row.showsIcon)
    // Text keeps its icon whatever is chosen.
    XCTAssertTrue(try XCTUnwrap(ClipRowInfo(HistoryItemDecorator(text))).showsIcon)
  }

  /// iOS never says which app a copy came from: an iPhone row shows the iPhone where the app icon would be, not a
  /// question mark. A Mac row, or an iPhone row that names its app, doesn't.
  func testIPhoneRowsShowTheIPhoneInsteadOfAnUnknownApp() throws {
    let fromIPhone = item([(.string, Data("from the iPhone".utf8)), (.pastronautFromIPhone, Data())])
    XCTAssertTrue(try XCTUnwrap(ClipRowInfo(HistoryItemDecorator(fromIPhone))).showsIPhoneBadge)
    let named = item([(.string, Data("named app".utf8)), (.pastronautFromIPhone, Data())])
    named.application = "com.apple.mobilesafari"
    XCTAssertFalse(try XCTUnwrap(ClipRowInfo(HistoryItemDecorator(named))).showsIPhoneBadge)
    let mac = item([(.string, Data("from this Mac".utf8))])
    XCTAssertFalse(try XCTUnwrap(ClipRowInfo(HistoryItemDecorator(mac))).showsIPhoneBadge)
  }

  /// A picture synced without a name and without text goes by its size; one with a name by its name.
  func testUnnamedPicturesGoByTheirSize() {
    let unnamed = ClipMedia.File(name: "Image 2026-10-25 at 02.45.12.heic", type: UTType.heic.identifier, byteCount: 1, sha256: "x")
    let clip = Clip(media: ClipMedia(kind: .image, files: [unnamed], pixelWidth: 1944, pixelHeight: 1222),
                    contentHashes: ["d"], sourceDevice: .iphone)
    XCTAssertEqual(SyncBridge.mediaTitle(of: clip), SyncBridge.pictureTitle(width: 1944, height: 1222))
    let named = ClipMedia.File(name: "ekran resmi.heic", type: UTType.heic.identifier, byteCount: 1, sha256: "x")
    let namedClip = Clip(media: ClipMedia(kind: .image, files: [named], pixelWidth: 10, pixelHeight: 10),
                         contentHashes: ["e"], sourceDevice: .iphone)
    XCTAssertEqual(SyncBridge.mediaTitle(of: namedClip), "ekran resmi.heic")
  }

  /// A PDF from the iPhone's Files app came by Universal Clipboard as types without bytes, an empty row (1.3).
  func testACopyWithoutBytesIsNotARow() {
    let remote = NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")
    XCTAssertTrue(item([(NSPasteboard.PasteboardType("com.apple.DocumentManager.FINode.File"), nil),
                        (.fileURL, nil), (remote, nil)]).hasNoData)
    XCTAssertTrue(item([(.fileURL, Data())]).hasNoData)
    XCTAssertFalse(item([(.fileURL, Data("file:///a.pdf".utf8)), (remote, nil)]).hasNoData)
    XCTAssertFalse(item([]).hasNoData)
  }

  func testMediaTitlesUseTheTextOrTheFileNames() {
    let file = ClipMedia.File(name: "Invoice.pdf", type: UTType.pdf.identifier, byteCount: 1, sha256: "x")
    // A named PDF goes by its name, as Finder shows it; one copied without a name by its text (1.3 copy matrix).
    let named = Clip(media: ClipMedia(kind: .pdf, files: [file], recognizedText: "Invoice 42\nTotal"), contentHashes: ["a"], sourceDevice: .iphone)
    XCTAssertEqual(SyncBridge.mediaTitle(of: named), "Invoice.pdf")
    let unnamed = ClipMedia.File(name: "Document 2026-10-25 at 01.19.36.pdf", type: UTType.pdf.identifier, byteCount: 1, sha256: "x")
    let withText = Clip(media: ClipMedia(kind: .pdf, files: [unnamed], recognizedText: "Invoice 42\nTotal"), contentHashes: ["c"], sourceDevice: .iphone)
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
