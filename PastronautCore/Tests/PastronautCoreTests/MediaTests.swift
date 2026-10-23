import CloudKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PastronautCore

/// Images, PDFs and files (1.3): the model, encryption, iCloud records, the store on the device, image work, and
/// the mirror's rules for what may go to iCloud.
@Suite struct MediaTests {
  let key = SyncKey(data: Data(repeating: 7, count: 32))!
  let date = Date(timeIntervalSince1970: 1_700_000_000)

  func imageClip(
    bytes: Int = 1_000,
    content: String = "screenshot",
    recognizedText: String? = nil,
    lastCopiedAt: Date? = nil
  ) -> Clip {
    let file = ClipMedia.File(name: "Shot.heic", type: "public.heic", byteCount: bytes, sha256: String(repeating: "a", count: 64))
    let media = ClipMedia(kind: .image, files: [file], pixelWidth: 1200, pixelHeight: 800, recognizedText: recognizedText)
    return Clip(
      media: media, contentHashes: [ClipMedia.sha256(Data(content.utf8))], sourceApp: "com.apple.Safari",
      sourceAppName: "Safari", sourceDevice: .mac, firstCopiedAt: date, lastCopiedAt: lastCopiedAt
    )
  }

  // MARK: - Model

  @Test func mediaClipsHaveTheirOwnIDsAndNoText() throws {
    let clip = imageClip()
    #expect(clip.id.hasPrefix("media-"))
    #expect(ClipMedia.isMediaID(clip.id))
    #expect(clip.text.isEmpty)
    #expect(clip.kind == .image)
    #expect(clip.isMedia)
    #expect(imageClip().id == clip.id)
    #expect(imageClip(content: "another").id != clip.id)
    #expect(!Clip(text: "hello", sourceDevice: .mac).isMedia)
  }

  @Test func mediaClipsRoundTripAndOlderFilesStillRead() throws {
    let clip = imageClip(recognizedText: "Invoice 42")
    let data = try JSONEncoder().encode(clip)
    #expect(try JSONDecoder().decode(Clip.self, from: data) == clip)

    let text = Clip(text: "plain", sourceDevice: .iphone)
    var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(text)) as? [String: Any])
    json.removeValue(forKey: "media")
    let old = try JSONSerialization.data(withJSONObject: json)
    #expect(try JSONDecoder().decode(Clip.self, from: old) == text)
  }

  @Test func theRecognizedTextSurvivesAMergeWithAVersionWithoutIt() {
    let read = imageClip(recognizedText: "Gate B12")
    var newer = imageClip()
    newer.pinned = true
    newer.modifiedAt = date.addingTimeInterval(60)
    let merged = read.merged(with: newer)
    #expect(merged.pinned)
    #expect(merged.media?.recognizedText == "Gate B12")
    #expect(merged.privacyText == "Gate B12")
  }

  // MARK: - Encryption

  @Test func filesOpenOnlyWithTheAccountKeyAndForTheirClip() throws {
    let cipher = MediaCipher(syncKey: key)
    let data = Data("bytes of a picture".utf8)
    let sealed = try cipher.seal(data, clipID: "media-1")
    #expect(sealed.starts(with: Data("PTM1".utf8)))
    #expect(sealed.range(of: data) == nil)
    #expect(try cipher.open(sealed, clipID: "media-1") == data)
    #expect(throws: (any Error).self) { try cipher.open(sealed, clipID: "media-2") }
    let other = MediaCipher(syncKey: SyncKey(data: Data(repeating: 8, count: 32))!)
    #expect(throws: (any Error).self) { try other.open(sealed, clipID: "media-1") }
    #expect(throws: MediaCipher.Failure.notMedia) { try cipher.open(Data("plain".utf8), clipID: "media-1") }
  }

  // MARK: - Records

  @Test func mediaRecordRoundTripKeepsEverythingEncrypted() throws {
    var clip = imageClip(recognizedText: "Boarding pass")
    clip.setTitle("Flight", at: date)
    clip.collectionIDs = ["col-a"]
    let thumbnail = Data(repeating: 1, count: 2_000)
    let record = MediaRecord.record(for: clip, key: key, thumbnail: thumbnail)

    #expect(record.recordType == "Media")
    #expect(record.recordID.zoneID == ClipRecord.zoneID)
    #expect(record.recordID.recordName == key.recordName(forClipID: clip.id))
    for field in ["clipID", "info", "thumbnail", "sourceApp", "sourceAppName", "collections", "title"] {
      #expect(record[field] == nil, "\(field) must not be plain")
    }
    #expect(MediaRecord.thumbnail(of: record) == thumbnail)
    #expect(record["files"] == nil)
    #expect(try #require(MediaRecord.clip(from: record)) == clip)
    // Clients before 1.3 read only "Clip" records.
    #expect(ClipRecord.clip(from: record) == nil)
  }

  @Test func filesGoUpOnlyWhenGiven() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: "media-asset-\(UUID().uuidString)")
    try Data([1, 2, 3]).write(to: file)
    let clip = imageClip()
    let first = MediaRecord.record(for: clip, key: key, encryptedFiles: [file])
    #expect((first["files"] as? [CKAsset])?.count == 1)
    #expect(MediaRecord.encryptedFileURLs(of: first) == [file])

    // A later save (a pin) is built on the server record's system fields and leaves the files alone.
    let base = try #require(ClipRecord.record(fromSystemFields: ClipRecord.systemFields(of: first)))
    let later = MediaRecord.record(for: clip, key: key, updating: base)
    #expect(later.changedKeys().contains("files") == false)
    #expect(MediaRecord.encryptedFileURLs(of: later) == nil)
  }

  @Test func oversizedThumbnailsAndLongTextAreTrimmed() throws {
    let long = String(repeating: "word ", count: 10_000)
    let record = MediaRecord.record(
      for: imageClip(recognizedText: long), key: key, thumbnail: Data(count: MediaRecord.maxThumbnailBytes + 1)
    )
    #expect(MediaRecord.thumbnail(of: record) == nil)
    let read = try #require(MediaRecord.clip(from: record))
    #expect(read.media?.recognizedText?.count == MediaRecord.maxRecognizedTextLength)
  }

  @Test func recordsWithoutAMediaIDAreIgnored() {
    let record = MediaRecord.record(for: imageClip(), key: key)
    record.encryptedValues["clipID"] = Clip.id(for: "text")
    #expect(MediaRecord.clip(from: record) == nil)
  }

  @Test func appIconsAreKeyedAndEncrypted() throws {
    let icon = AppIcon(bundleIdentifier: "com.apple.Safari", name: "Safari", png: Data(repeating: 2, count: 500), modifiedAt: date)
    let record = AppIconRecord.record(for: icon, key: key)
    #expect(record.recordID.recordName.hasPrefix("a-"))
    #expect(record.recordID.recordName.count == 66)
    #expect(!record.recordID.recordName.contains("Safari"))
    #expect(record["bundleIdentifier"] == nil && record["png"] == nil)
    #expect(AppIconRecord.icon(from: record) == icon)

    record.encryptedValues["png"] = Data(count: AppIcon.maxBytes + 1)
    #expect(AppIconRecord.icon(from: record) == nil)
  }

  @Test func sharedSettingsSitNextToTheKey() throws {
    let record = CKRecord(recordType: SettingsRecord.recordType, recordID: SettingsRecord.recordID)
    record.encryptedValues["idKey"] = key.data
    #expect(SettingsRecord.sharedSettings(from: record) == nil)

    var settings = SharedSyncSettings(privacy: PrivacyOptions(skipOneTimeCodes: true), modifiedAt: date)
    settings.media.cloudBudgetBytes = 2 * MediaSettings.gigabyte
    SettingsRecord.write(settings, into: record)
    #expect(record["shared"] == nil)
    #expect(SettingsRecord.sharedSettings(from: record) == settings)
    #expect(SettingsRecord.key(from: record) == key)
  }

  @Test func settingsAndMediaWrittenByOtherVersionsStillRead() throws {
    let older = Data(#"{"skipOneTimeCodes":true}"#.utf8)
    let settings = try JSONDecoder().decode(SharedSyncSettings.self, from: older)
    #expect(settings.skipOneTimeCodes)
    #expect(settings.media == MediaSettings())
    #expect(settings.modifiedAt == nil)

    let later = Data(#"{"kind":"hologram","files":[{"name":"a","type":"public.data","byteCount":1,"sha256":"x"}],"future":1}"#.utf8)
    let media = try JSONDecoder().decode(ClipMedia.self, from: later)
    #expect(media.kind == .file)
    #expect(media.files.count == 1)
  }

  @Test func theNewestSharedSettingsWin() {
    let defaults = SharedSyncSettings()
    var changed = SharedSyncSettings(privacy: PrivacyOptions(pinnedOnly: true), modifiedAt: date)
    #expect(defaults.merged(with: changed) == changed)
    #expect(changed.merged(with: defaults) == changed)
    var newer = changed
    newer.media.syncEnabled = false
    newer.modifiedAt = date.addingTimeInterval(1)
    #expect(changed.merged(with: newer) == newer)
    changed.modifiedAt = date.addingTimeInterval(2)
    #expect(newer.merged(with: changed) == changed)
  }

  /// The catch-up fetch names the fields it wants; a field missing from that list would read as empty.
  @Test func theCatchUpFetchAsksForEveryFieldButTheFiles() throws {
    var clip = Clip(text: "t", sourceApp: "a", sourceAppName: "A", sourceDevice: .mac, pinned: true, collectionIDs: ["col-1"])
    clip.setTitle("T", at: date)
    var media = imageClip()
    media.setTitle("M", at: date)
    media.collectionIDs = ["col-1"]
    let settings = CKRecord(recordType: SettingsRecord.recordType, recordID: SettingsRecord.recordID)
    settings.encryptedValues["idKey"] = key.data
    SettingsRecord.write(SharedSyncSettings(), into: settings)
    let file = FileManager.default.temporaryDirectory.appending(path: "catch-up-\(UUID().uuidString)")
    try Data([1]).write(to: file)
    let records = [
      ClipRecord.record(for: clip, key: key),
      CollectionRecord.record(for: ClipCollection(id: "col-1", name: "Work", order: 1, createdAt: date)),
      settings,
      MediaRecord.record(for: media, key: key, thumbnail: Data([1]), encryptedFiles: [file]),
      AppIconRecord.record(for: AppIcon(bundleIdentifier: "b", name: "B", png: Data([1])), key: key)
    ]
    let asked = Set(ClipSync.catchUpKeys)
    for record in records {
      let missing = Set(record.allKeys()).subtracting(asked).subtracting(["files"])
      #expect(missing.isEmpty, "\(record.recordType) fields missing from the catch-up: \(missing.sorted())")
    }
    #expect(!asked.contains("files"))
  }

  // MARK: - Store

  func store() -> MediaStore {
    MediaStore(directory: FileManager.default.temporaryDirectory.appending(path: "media-\(UUID().uuidString)"))
  }

  func clip(files: [(name: String, data: Data)]) -> Clip {
    let media = ClipMedia(kind: .file, files: files.map {
      ClipMedia.File(name: $0.name, type: MediaProcessing.type(ofFileNamed: $0.name), data: $0.data)
    })
    return Clip(media: media, contentHashes: files.map { ClipMedia.sha256($0.data) }, sourceDevice: .mac)
  }

  @Test func filesKeepTheirNamesInTheirClipsFolder() throws {
    let store = store()
    let clip = clip(files: [("Invoice.pdf", Data("pdf".utf8)), ("Invoice.pdf", Data("other".utf8)), ("../x", Data([1]))])
    #expect(!store.hasFiles(for: clip))
    try store.store([Data("pdf".utf8), Data("other".utf8), Data([1])], for: clip)
    #expect(store.hasFiles(for: clip))
    let urls = store.fileURLs(for: clip)
    #expect(urls.map(\.lastPathComponent) == ["Invoice.pdf", "Invoice.pdf", "..-x"].map { $0 == "..-x" ? "file-3" : $0 })
    #expect(urls.allSatisfy { $0.path.hasPrefix(store.directory.appending(path: clip.id).path) })
    #expect(try Data(contentsOf: urls[1]) == Data("other".utf8))
    #expect(MediaStore.safeName("a/b:c", index: 0) == "a-b-c")
    #expect(MediaStore.safeName("  ", index: 4) == "file-5")
  }

  @Test func encryptedCopiesComeBackAsTheSameFiles() throws {
    let sender = store(), receiver = store()
    let cipher = MediaCipher(syncKey: key)
    let bytes = Data((0..<5_000).map { UInt8($0 % 251) })
    let photo = clip(files: [("Photo.png", bytes)])
    try sender.store([bytes], for: photo)

    let copies = try #require(sender.encryptedCopies(of: photo, recordName: "c-abc", cipher: cipher))
    #expect(copies.count == 1)
    #expect(try Data(contentsOf: copies[0]) != bytes)
    #expect(receiver.storeDownloaded(copies, for: photo, cipher: cipher))
    #expect(try Data(contentsOf: receiver.fileURLs(for: photo)[0]) == bytes)

    // A file that doesn't match its hash is not kept.
    let tampered = clip(files: [("Photo.png", Data([9]))])
    let other = store()
    #expect(!other.storeDownloaded(copies, for: tampered, cipher: cipher))
    #expect(!other.hasFiles(for: tampered))

    sender.removeEncryptedCopies(recordName: "c-abc")
    #expect(!FileManager.default.fileExists(atPath: copies[0].path))
  }

  @Test func pruningKeepsOnlyMirroredClips() throws {
    let store = store()
    let kept = clip(files: [("a.txt", Data("a".utf8))])
    let gone = clip(files: [("b.txt", Data("b".utf8))])
    try store.store([Data("a".utf8)], for: kept)
    try store.store([Data("b".utf8)], for: gone)
    try store.storeThumbnail(Data([1]), for: gone.id)
    #expect(store.prune(keeping: [kept.id]) == 1)
    #expect(store.hasFiles(for: kept))
    #expect(!store.hasFiles(for: gone))
    #expect(store.thumbnail(for: gone.id) == nil)
    #expect(store.totalBytes == 1)
  }

  // MARK: - Images and PDFs

  func png(width: Int, height: Int) -> Data {
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    for step in 0..<20 {
      context.setFillColor(CGColor(red: CGFloat(step) / 20, green: 0.4, blue: 1 - CGFloat(step) / 20, alpha: 1))
      context.fill(CGRect(x: step * width / 20, y: 0, width: width / 20 + 1, height: height))
    }
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
  }

  func pdf(text: String) -> Data {
    let data = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 300, height: 400)
    let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, nil)!
    context.beginPDFPage(nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text))
    context.textPosition = CGPoint(x: 20, y: 300)
    CTLineDraw(line, context)
    context.endPDFPage()
    context.closePDF()
    return data as Data
  }

  @Test func optimizedImagesAreHEICAndAtMost4096Pixels() throws {
    let original = png(width: 5_000, height: 3_000)
    #expect(MediaProcessing.pixelSize(of: original)! == (5_000, 3_000))

    let optimized = try #require(MediaProcessing.prepared(original, quality: .optimized))
    #expect(optimized.type == UTType.heic.identifier)
    #expect(optimized.pixelWidth == 4_096)
    #expect(optimized.data.count < original.count)

    let kept = try #require(MediaProcessing.prepared(original, quality: .original))
    #expect(kept.data == original)
    #expect(kept.type == UTType.png.identifier)
  }

  @Test func thumbnailsFitTheEncryptedField() throws {
    let thumbnail = try #require(MediaProcessing.thumbnail(ofImage: png(width: 3_000, height: 2_000)))
    #expect(thumbnail.count <= MediaRecord.maxThumbnailBytes)
    let size = try #require(MediaProcessing.pixelSize(of: thumbnail))
    #expect(max(size.width, size.height) <= 480)

    let page = try #require(MediaProcessing.thumbnail(ofPDF: pdf(text: "Hello")))
    #expect(page.count <= MediaRecord.maxThumbnailBytes)
  }

  @Test func pdfTextIsReadForSearch() {
    #expect(MediaProcessing.text(inPDF: pdf(text: "Fatura 2026"))?.contains("Fatura 2026") == true)
    #expect(MediaProcessing.text(inPDF: Data("not a pdf".utf8)) == nil)
    #expect(MediaProcessing.isPDF(MediaProcessing.type(ofFileNamed: "a.PDF")))
    #expect(MediaProcessing.isImage("public.heic"))
    #expect(MediaProcessing.type(ofFileNamed: "noextension") == "public.data")
  }

  // MARK: - What goes to iCloud

  typealias State = ClipSync.PersistedState

  func state(budget: Int = 10_000, maxItem: Int = 5_000, syncing: Bool = true) -> State {
    var state = State()
    state.key = key
    state.sharedSettings.media = MediaSettings(syncEnabled: syncing, maxItemBytes: maxItem, cloudBudgetBytes: budget)
    return state
  }

  @Test func mediaWithinTheLimitsGoesToICloud() {
    var state = state()
    let clip = imageClip(bytes: 4_000)
    let ok1 = state.stage(clip, policy: .default)
    #expect(ok1)
    #expect(state.entries[clip.id]?.isLocalOnly == false)
    #expect(state.mediaBytesInCloud() == 4_000)
  }

  @Test func tooLargeFullOrSwitchedOffMediaStaysOnTheDevice() {
    var big = state()
    let large = imageClip(bytes: 6_000)
    let ok2 = big.stage(large, policy: .default)
    #expect(ok2)
    #expect(big.entries[large.id]?.isLocalOnly == true)

    var full = state(budget: 5_000)
    let ok3 = full.stage(imageClip(bytes: 3_000, content: "one"), policy: .default)
    #expect(ok3)
    let second = imageClip(bytes: 3_000, content: "two")
    let ok4 = full.stage(second, policy: .default)
    #expect(ok4)
    #expect(full.entries[second.id]?.isLocalOnly == true)
    #expect(full.mediaBytesInCloud() == 3_000)

    var off = state(syncing: false)
    let any = imageClip(bytes: 10)
    let ok5 = off.stage(any, policy: .default)
    #expect(ok5)
    #expect(off.entries[any.id]?.isLocalOnly == true)
    // Text is not affected by the media settings.
    let text = Clip(text: "hello", sourceDevice: .mac)
    let ok6 = off.stage(text, policy: .default)
    #expect(ok6)
    #expect(off.entries[text.id]?.isLocalOnly == false)
  }

  @Test func theTextInAnImageGoesThroughThePrivacyFilters() {
    var state = state()
    let code = imageClip(content: "sms", recognizedText: "Your code is 482913")
    let ok7 = state.stage(code, policy: .default, privacy: PrivacyOptions(skipOneTimeCodes: true))
    #expect(ok7)
    #expect(state.entries[code.id]?.isLocalOnly == true)
  }

  @Test func uploadingAgainFillsTheBudgetNewestFirst() {
    var state = state(budget: 5_000)
    let old = imageClip(bytes: 3_000, content: "old", lastCopiedAt: date)
    let new = imageClip(bytes: 3_000, content: "new", lastCopiedAt: date.addingTimeInterval(60))
    for clip in [old, new] {
      state.entries[clip.id] = ClipSync.MirrorEntry(clip: clip, systemFields: nil, isLocalOnly: true)
    }
    let released = state.releaseLocalOnly()
    #expect(released.clips == [new.id])
    #expect(state.entries[old.id]?.isLocalOnly == true)
  }

  @Test func clipsHiddenOnTheMacComeBackOnlyWhenCopiedAgain() {
    var state = state()
    let clip = imageClip(bytes: 100, lastCopiedAt: date)
    let ok8 = state.stage(clip, policy: .default)
    #expect(ok8)
    state.dismiss([clip.id], at: date.addingTimeInterval(10))
    #expect(state.entries[clip.id] != nil)
    let ok9 = state.reveals(clip)
    #expect(!ok9)

    var pinnedElsewhere = clip
    pinnedElsewhere.pinned = true
    let ok10 = state.reveals(pinnedElsewhere)
    #expect(!ok10)

    var copiedLater = clip
    copiedLater.lastCopiedAt = date.addingTimeInterval(20)
    let ok11 = state.reveals(copiedLater)
    #expect(ok11)
    #expect(state.entries[clip.id]?.dismissedAt == nil)
  }

  @Test func copyingAHiddenClipHereShowsItAgain() {
    var state = state()
    let clip = Clip(text: "from the iPhone", sourceDevice: .iphone, firstCopiedAt: date)
    let ok12 = state.stage(clip, policy: .default)
    #expect(ok12)
    state.dismiss([clip.id], at: date.addingTimeInterval(10))
    let copy = Clip(text: "from the iPhone", sourceDevice: .mac, firstCopiedAt: date.addingTimeInterval(20))
    let existing = state.entries[clip.id]!.clip
    let ok13 = state.stage(existing.copiedAgain(copy), policy: .default, isCapture: true)
    #expect(ok13)
    #expect(state.entries[clip.id]?.dismissedAt == nil)
  }
}
