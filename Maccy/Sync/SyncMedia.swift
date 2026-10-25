import AppKit
import Defaults
import PastronautCore
import UniformTypeIdentifiers

// Images, PDFs and files in iCloud sync (1.3), app icons for the iPhone, and the settings every device shares.
// The rules live in PastronautCore (ClipSync, MediaStore, MediaProcessing); this file connects them to Maccy's
// history. Plan: docs/pastronaut/PLAN-1.3.md.

extension NSPasteboard.PasteboardType {
  /// Stored with a history item whose image or files went to iCloud (or came from there): its clip ID
  /// (`ClipMedia.clipID`). A Finder copy's files can't be read again in a later session, so the ID is kept rather
  /// than worked out again.
  nonisolated static let pastronautMediaID = NSPasteboard.PasteboardType("com.xkbxyberk.pastronaut.media-id")
  nonisolated static let pdfDocument = NSPasteboard.PasteboardType(UTType.pdf.identifier)
  /// Stored with a history item whose image or files could not go to iCloud (too large, a folder, Images & Files
  /// off, a privacy filter): its row says so.
  nonisolated static let pastronautLocalOnly = NSPasteboard.PasteboardType("com.xkbxyberk.pastronaut.local-only")
}

extension Defaults.Keys {
  // Settings › Sync › Images & Files. These three are shared by every device (ClipSync.sharedSettings); this Mac
  // keeps a copy for the settings pane. The quality is this Mac's own.
  static let mediaSyncEnabled = Key<Bool>("pastronautMediaSync", default: MediaSettings().syncEnabled)
  static let mediaMaxItemBytes = Key<Int>("pastronautMediaMaxItemBytes", default: MediaSettings().maxItemBytes)
  static let mediaCloudBudgetBytes = Key<Int>("pastronautMediaCloudBudget", default: MediaSettings().cloudBudgetBytes)
  static let mediaQuality = Key<String>("pastronautMediaQuality", default: MediaQuality.optimized.rawValue)
}

extension HistoryItem {
  /// Types without a single byte: what Universal Clipboard leaves of a PDF or file copied in the iPhone's Files app.
  var hasNoData: Bool {
    !contents.isEmpty && contents.allSatisfy { $0.value?.isEmpty ?? true }
  }

  var isLocalOnlyMedia: Bool {
    contents.contains { $0.type == NSPasteboard.PasteboardType.pastronautLocalOnly.rawValue }
  }

  var pastronautMediaID: String? {
    contents.first { $0.type == NSPasteboard.PasteboardType.pastronautMediaID.rawValue }?.value
      .flatMap { String(data: $0, encoding: .utf8) }
  }

  /// A PDF copied as data (Preview's selection), not as a file.
  var pdfData: Data? {
    contents.first { $0.type == NSPasteboard.PasteboardType.pdfDocument.rawValue }?.value
  }
}

// MARK: - Copies on this Mac

extension SyncBridge {
  /// A copy that isn't plain text: an image, a PDF or files from Finder. It goes to iCloud when the shared
  /// settings allow it; otherwise it stays in this Mac's history only, as before 1.3.
  func didAddMedia(_ item: HistoryItem) {
    // A PDF or file from the iPhone's Files app: Universal Clipboard named its types but handed over no bytes at all,
    // and the row stayed empty (1.3 TestFlight). The copy comes by sync once the iPhone app saves it.
    if item.hasNoData {
      item.title = String(localized: "File from iPhone: open Pastronaut on the iPhone to bring it here", table: "Pastronaut")
      Task { @MainActor in
        if let decorator = History.shared.allItems.first(where: { $0.item == item }) {
          self.removeLocally(decorator)
        }
      }
      return
    }
    // A Universal Clipboard copy came from a device that syncs it itself. Its picture may already be here by sync:
    // then this row takes that one's place.
    guard !item.universalClipboard else {
      keepUniversalPicture(of: item)
      replaceSyncedTwin(with: item)
      return
    }
    if let id = item.pastronautMediaID {
      // Copied again: Maccy moved the earlier item's contents, ID included, into this one.
      let copiedAt = item.lastCopiedAt
      // Like text: a clip from the iPhone stays an iPhone clip when this Mac copies it again.
      let fromIPhone = item.isFromIPhone
      let app = item.application
      let appName = app.flatMap(Self.appName(for:))
      enqueue { sync in
        guard var copy = await sync.clip(withID: id) else { return }
        copy.lastCopiedAt = max(copy.lastCopiedAt, copiedAt)
        copy.modifiedAt = max(copy.modifiedAt, copiedAt)
        if !fromIPhone {
          copy.sourceDevice = .mac
          copy.sourceApp = app
          copy.sourceAppName = appName
        }
        await sync.recordCopy(copy)
      }
      return
    }
    // Copied in Finder: the new-copy notification (History.add) shows the file names, not a path.
    if !item.fileURLs.isEmpty {
      item.title = item.fileURLs.map(\.lastPathComponent).joined(separator: ", ")
    }
    let source = MediaCapture.Source(
      // By name: the history item keeps its contents in no particular order, and the clip's ID follows the order
      // of its files (the same Finder selection must give the same clip).
      fileURLs: item.fileURLs.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending },
      imageData: item.fileURLs.isEmpty ? item.imageData : nil,
      pdfData: item.pdfData,
      sourceApp: item.application,
      sourceAppName: item.application.flatMap(Self.appName(for:)),
      copiedAt: item.lastCopiedAt,
      pinned: item.pin != nil
    )
    guard source.hasMedia else { return }
    let quality = MediaQuality(rawValue: Defaults[.mediaQuality]) ?? .optimized
    let privacy = privacy
    let sync = sync
    Task { [weak self] in
      guard let clip = await MediaCapture.capture(source, quality: quality, privacy: privacy, sync: sync) else {
        self?.markLocalOnly(item)
        return
      }
      self?.finishCapture(clip, of: item)
    }
  }

  /// The row says the copy stays on this Mac.
  private func markLocalOnly(_ item: HistoryItem) {
    guard History.shared.allItems.contains(where: { $0.item == item }), !item.isLocalOnlyMedia,
          item.pastronautMediaID == nil else { return }
    item.contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.pastronautLocalOnly.rawValue, value: Data()))
    try? Storage.shared.context.save()
    refreshRow(of: item)
  }

  private func finishCapture(_ clip: Clip, of item: HistoryItem) {
    // Deleted while the files were read.
    guard History.shared.allItems.contains(where: { $0.item == item }), item.pastronautMediaID == nil else { return }
    item.contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.pastronautMediaID.rawValue, value: Data(clip.id.utf8)))
    // A picture copied in Finder: the row shows it (and pastes it into apps that take pictures), not only its path.
    if clip.kind == .image, item.imageData == nil, let file = clip.media?.files.first,
       let url = sync.media.fileURLs(for: clip).first, let data = try? Data(contentsOf: url) {
      // The title stays the file's name (didAddMedia), as for every Finder copy.
      item.contents.append(HistoryItemContent(type: file.type, value: data))
      refreshRow(of: item)
    } else if clip.kind == .pdf, item.imageData == nil, let picture = pagePicture(of: clip) {
      // A PDF copied in Finder: the row shows its first page, as for a PDF copied in Preview.
      item.contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: picture))
      refreshRow(of: item)
    }
    try? Storage.shared.context.save()
    let isKept = item.pin != nil
    enqueue { sync in
      var copy = clip
      copy.pinned = isKept
      await sync.recordCopy(copy)
      try? await sync.sendNow()
    }
  }

  // MARK: - From other devices

  /// Adds a media clip from another device to this Mac's history. Images go in as image data (and PNG, which
  /// every app takes); PDFs and files as files in the sync store, so they paste as files.
  func insertMedia(_ clip: Clip) {
    guard let media = clip.media else { return }
    if clip.sourceDevice != .mac, let twin = universalTwin(of: clip) {
      // Universal Clipboard brought this picture first: that row becomes the clip's, instead of a second one.
      mark(twin, as: clip.id, title: clip.title)
      return
    }
    let urls = sync.media.fileURLs(for: clip)
    var contents: [HistoryItemContent] = []
    if clip.kind == .image, let file = media.files.first, let url = urls.first, let data = try? Data(contentsOf: url) {
      contents.append(HistoryItemContent(type: file.type, value: data))
      let type = NSPasteboard.PasteboardType(file.type)
      if type != .png, type != .tiff, let png = MediaProcessing.png(of: data) {
        contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: png))
      }
    } else {
      contents += urls.map {
        HistoryItemContent(type: NSPasteboard.PasteboardType.fileURL.rawValue, value: $0.dataRepresentation)
      }
      // A PDF shows its first page in the row and the preview, as a PDF copied in Preview does; it still pastes
      // as the PDF file.
      if clip.kind == .pdf, let picture = pagePicture(of: clip) {
        contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: picture))
      }
    }
    guard !contents.isEmpty else { return }
    contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.pastronautMediaID.rawValue, value: Data(clip.id.utf8)))
    if clip.sourceDevice != .mac {
      contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.pastronautFromIPhone.rawValue, value: Data()))
    }
    let item = HistoryItem(contents: contents)
    if #unavailable(macOS 15.0) {
      // Same requirement as Clipboard: on macOS 14 the item must be in storage before History.add.
      try? History.shared.insertIntoStorage(item)
    }
    item.application = clip.sourceApp
    item.firstCopiedAt = clip.firstCopiedAt
    item.lastCopiedAt = clip.lastCopiedAt
    if clip.pinned, let pin = HistoryItem.availablePins.randomElement() {
      item.pin = pin
    }
    item.title = clip.title ?? Self.mediaTitle(of: clip)
    History.shared.add(item)
  }

  // MARK: - One picture, two ways

  // An iPhone picture reaches the Mac by Universal Clipboard (the original) and by sync (the copy the clip was
  // made from, re-encoded): different bytes, so Maccy kept both, and the history showed it twice or more (1.3
  // TestFlight). The Universal Clipboard row stays, it has the original, and takes the clip's ID.

  /// Universal Clipboard hands an iPhone picture over as a file in the system's own container, which this
  /// sandboxed app can't open afterwards: the row showed only a path. The picture is on the clipboard now, so its
  /// bytes go into the row instead of the path.
  private func keepUniversalPicture(of item: HistoryItem) {
    let imageTypes = [NSPasteboard.PasteboardType.heic, .jpeg, .png, .tiff]
    guard !item.fileURLs.isEmpty,
          !item.contents.contains(where: { imageTypes.contains(NSPasteboard.PasteboardType($0.type)) }) else { return }
    let pasteboard = NSPasteboard.general
    // The picture's bytes: on the clipboard, or in the file while the copy still grants access to it (seconds).
    var picture: (type: NSPasteboard.PasteboardType, data: Data)?
    if let type = imageTypes.first(where: { pasteboard.data(forType: $0) != nil }), let data = pasteboard.data(forType: type) {
      picture = (type, data)
    } else if let url = item.fileURLs.first, let data = try? Data(contentsOf: url),
              let type = UTType(filenameExtension: url.pathExtension) {
      picture = (NSPasteboard.PasteboardType(type.identifier), data)
    }
    if let picture, MediaProcessing.pixelSize(of: picture.data) != nil {
      item.contents.removeAll { $0.type == NSPasteboard.PasteboardType.fileURL.rawValue }
      item.contents.append(HistoryItemContent(type: picture.type.rawValue, value: picture.data))
      item.title = item.generateTitle()
      try? Storage.shared.context.save()
      refreshRow(of: item)
      return
    }
    // A picture from the Photos app, or a PDF or file from the Files app, comes as a file in the system's own
    // folder for Universal Clipboard, which this sandboxed app may open for a moment at most: the row would be a
    // bare path. The copy itself comes by sync once the iPhone app saves it (⌘V still pastes it from the system
    // clipboard meanwhile).
    let systemCopy = item.fileURLs.allSatisfy { $0.path.contains("/group.com.apple.coreservices.useractivityd/") }
    guard systemCopy else { return }
    // The new-copy notification (History.add) reads the title after this hook: not a path.
    let pictures = item.fileURLs.allSatisfy { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true }
    // It also says when it comes: iPhone lets Pastronaut read the clipboard only while it is open.
    item.title = pictures
      ? String(localized: "Picture from iPhone: open Pastronaut on the iPhone to bring it here", table: "Pastronaut")
      : String(localized: "File from iPhone: open Pastronaut on the iPhone to bring it here", table: "Pastronaut")
    Task { @MainActor in
      if let decorator = History.shared.allItems.first(where: { $0.item == item }) {
        self.removeLocally(decorator)
      }
    }
  }

  /// Text from the iPhone that is only the name of a file this Mac copied in Finder (Universal Clipboard takes the
  /// name across): not a clip of its own here.
  func isFileNameEcho(_ clip: Clip) -> Bool {
    guard clip.sourceDevice != .mac else { return false }
    return History.shared.allItems.contains { decorator in
      let item = decorator.item
      guard !item.universalClipboard, !item.fileURLs.isEmpty,
            abs(item.lastCopiedAt.timeIntervalSince(clip.firstCopiedAt)) <= ClipMedia.pictureTwinWindow else { return false }
      let files = item.fileURLs.map { ClipMedia.File(name: $0.lastPathComponent, type: "", byteCount: 0, sha256: "") }
      return ClipMedia(kind: .file, files: files).isNamed(by: clip.text)
    }
  }

  /// A Universal Clipboard row of the same picture not yet tied to a clip.
  private func universalTwin(of clip: Clip) -> HistoryItem? {
    guard let media = clip.media, let url = sync.media.fileURLs(for: clip).first,
          let clipData = try? Data(contentsOf: url) else { return nil }
    return History.shared.allItems.map(\.item).first { item in
      guard item.universalClipboard, item.pastronautMediaID == nil, let data = item.imageData,
            let size = MediaProcessing.pixelSize(of: data),
            media.isSamePicture(width: size.width, height: size.height, copiedAt: item.lastCopiedAt, as: clip.firstCopiedAt)
      else { return false }
      return MediaProcessing.isSamePicture(data, clipData)
    }
  }

  /// The same picture is in the history already: by sync from the iPhone, or this Mac's own copy coming back (the
  /// iPhone pasted it from the keyboard, and Universal Clipboard brought it here again). From the iPhone: the new
  /// Universal Clipboard row takes that clip's ID, pin and title, and the synced row leaves this Mac only. This Mac's
  /// own: the new row goes and the earlier one moves to the top.
  private func replaceSyncedTwin(with item: HistoryItem) {
    guard let data = item.imageData, let size = MediaProcessing.pixelSize(of: data) else { return }
    let twin = History.shared.allItems.first { decorator in
      let other = decorator.item
      guard other != item, !other.universalClipboard, other.pastronautMediaID != nil,
            let otherData = other.imageData, let otherSize = MediaProcessing.pixelSize(of: otherData) else { return false }
      let synced = ClipMedia(kind: .image, files: [], pixelWidth: otherSize.width, pixelHeight: otherSize.height)
      guard synced.isSamePicture(width: size.width, height: size.height, copiedAt: item.lastCopiedAt, as: other.lastCopiedAt)
        || synced.isSamePicture(width: size.width, height: size.height, copiedAt: item.lastCopiedAt, as: other.firstCopiedAt)
      else { return false }
      return MediaProcessing.isSamePicture(data, otherData)
    }
    guard let twin, let id = twin.item.pastronautMediaID else { return }
    guard twin.item.isFromIPhone else {
      let copiedAt = item.lastCopiedAt
      // After History.add has finished with the new row.
      Task { @MainActor in
        if let duplicate = History.shared.allItems.first(where: { $0.item == item }) { self.removeLocally(duplicate) }
        twin.item.lastCopiedAt = max(twin.item.lastCopiedAt, copiedAt)
        History.shared.reorder(twin)
      }
      return
    }
    mark(item, as: id, title: twin.item.title.isEmpty ? nil : twin.item.title)
    if twin.item.pin != nil, item.pin == nil { item.pin = twin.item.pin }
    // After History.add has finished with the new row.
    Task { @MainActor in
      self.removeLocally(twin)
    }
  }

  /// A row whose contents changed after it was first shown: its thumbnail is made again.
  private func refreshRow(of item: HistoryItem) {
    Task { @MainActor in
      item.clearDecodedImageCache()
      guard let decorator = History.shared.allItems.first(where: { $0.item == item }) else { return }
      decorator.cleanupImages()
      decorator.ensureThumbnailImage()
    }
  }

  private func mark(_ item: HistoryItem, as clipID: String, title: String?) {
    item.contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.pastronautMediaID.rawValue, value: Data(clipID.utf8)))
    if !item.contents.contains(where: { $0.type == NSPasteboard.PasteboardType.pastronautFromIPhone.rawValue }) {
      item.contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.pastronautFromIPhone.rawValue, value: Data()))
    }
    if let title { item.title = title }
    try? Storage.shared.context.save()
  }

  /// The first page of a PDF clip, from its file in the sync store.
  private func pagePicture(of clip: Clip) -> Data? {
    sync.media.fileURLs(for: clip).first.flatMap { try? Data(contentsOf: $0) }.flatMap { MediaProcessing.pagePicture(ofPDF: $0) }
  }

  /// What a media clip shows without a title of its own (`ClipMedia.caption`, the same on the iPhone). A picture
  /// copied without a name and without text in it goes by its size.
  nonisolated static func mediaTitle(of clip: Clip) -> String {
    guard let media = clip.media else { return "" }
    if media.kind == .image, media.recognizedText == nil, media.files.allSatisfy({ MediaProcessing.isDefaultName($0.name) }),
       let width = media.pixelWidth, let height = media.pixelHeight {
      return pictureTitle(width: width, height: height)
    }
    return media.caption
  }

  /// "Picture 1944 × 1222": a picture's row without a name or text.
  nonisolated static func pictureTitle(width: Int, height: Int) -> String {
    String(localized: "Picture \(width) × \(height)", table: "Pastronaut")
  }

  // MARK: - App icons

  /// Sends an app's icon once, so the iPhone can show where this Mac's clips came from.
  func publishIcon(for bundleIdentifier: String?) {
    guard let bundleIdentifier, !publishedIcons.contains(bundleIdentifier),
          let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
    publishedIcons.insert(bundleIdentifier)
    guard let png = Self.iconPNG(NSWorkspace.shared.icon(forFile: url.path)) else { return }
    let icon = AppIcon(bundleIdentifier: bundleIdentifier, name: Self.appName(for: bundleIdentifier), png: png)
    enqueue { await $0.publishAppIcon(icon) }
  }

  static func iconPNG(_ image: NSImage, side: Int = AppIcon.side) -> Data? {
    guard let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
      hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]), png.count <= AppIcon.maxBytes else {
      return nil
    }
    return png
  }

  // MARK: - Settings every device shares

  /// This Mac's copy of the shared settings (Sync › Privacy, Sync › Images & Files).
  var localSharedSettings: SharedSyncSettings {
    SharedSyncSettings(
      privacy: privacy,
      media: MediaSettings(
        syncEnabled: Defaults[.mediaSyncEnabled],
        maxItemBytes: Defaults[.mediaMaxItemBytes],
        cloudBudgetBytes: Defaults[.mediaCloudBudgetBytes]
      )
    )
  }

  /// After sync starts. iCloud's settings win, unless nobody ever changed them there: then this Mac's switches
  /// (set before 1.3, when they were this Mac's own) become everyone's.
  func reconcileSharedSettings() async {
    let shared = await sync.sharedSettings
    let local = localSharedSettings
    if shared.modifiedAt == nil {
      if local.privacy != shared.privacy || local.media != shared.media {
        await sync.updateSharedSettings { $0.privacy = local.privacy; $0.media = local.media }
      }
    } else {
      applySharedSettings(shared)
    }
  }

  /// A switch changed here: every device follows. Setting the values another device sent changes nothing.
  func sendSharedSettings() async {
    guard Defaults[.iCloudSync] else { return }
    let local = localSharedSettings
    await sync.updateSharedSettings { $0.privacy = local.privacy; $0.media = local.media }
  }

  /// Another device changed the shared settings: the switches here follow.
  func applySharedSettings(_ settings: SharedSyncSettings) {
    if Defaults[.syncSkipOneTimeCodes] != settings.skipOneTimeCodes { Defaults[.syncSkipOneTimeCodes] = settings.skipOneTimeCodes }
    if Defaults[.syncSkipCardNumbers] != settings.skipCardNumbers { Defaults[.syncSkipCardNumbers] = settings.skipCardNumbers }
    if Defaults[.syncPinnedOnly] != settings.pinnedOnly { Defaults[.syncPinnedOnly] = settings.pinnedOnly }
    if Defaults[.mediaSyncEnabled] != settings.media.syncEnabled { Defaults[.mediaSyncEnabled] = settings.media.syncEnabled }
    if Defaults[.mediaMaxItemBytes] != settings.media.maxItemBytes { Defaults[.mediaMaxItemBytes] = settings.media.maxItemBytes }
    if Defaults[.mediaCloudBudgetBytes] != settings.media.cloudBudgetBytes {
      Defaults[.mediaCloudBudgetBytes] = settings.media.cloudBudgetBytes
    }
  }
}

// MARK: - Reading a copy

/// Turns what was copied into a media clip, off the main thread, and keeps its files in the sync store.
nonisolated enum MediaCapture {
  struct Source: Sendable {
    var fileURLs: [URL]
    var imageData: Data?
    var pdfData: Data?
    var sourceApp: String?
    var sourceAppName: String?
    var copiedAt: Date
    var pinned: Bool

    var hasMedia: Bool { !fileURLs.isEmpty || imageData != nil || pdfData != nil }
  }

  /// The clip, with its files and thumbnail in the store; nil when it may not go to iCloud (too large, budget
  /// full, sync off, a privacy filter, a folder) or can't be read.
  @concurrent
  static func capture(_ source: Source, quality: MediaQuality, privacy: PrivacyOptions, sync: ClipSync) async -> Clip? {
    let settings = await sync.sharedSettings.media
    guard settings.syncEnabled, let parts = read(source, quality: quality, maxBytes: settings.maxItemBytes),
          let prepared = await MediaIntake.prepare(
            parts, sourceApp: source.sourceApp, sourceAppName: source.sourceAppName, device: .mac,
            copiedAt: source.copiedAt, pinned: source.pinned
          ) else {
      return nil
    }
    // Pinned or not: with "Sync pinned items only" the copy is kept for sync but stays on this Mac until it is
    // pinned (the sync layer holds it back). The files can only be read now.
    guard privacy.allows(prepared.clip.privacyText, pinned: true),
          await sync.allowsMedia(prepared.clip),
          (try? MediaIntake.store(prepared, in: sync.media)) != nil else { return nil }
    return prepared.clip
  }

  /// A picture file larger than this isn't read to be made smaller.
  static let maxPictureFileBytes = 200 * MediaSettings.megabyte

  /// The bytes to send. Files are read now: macOS lets this app read a file copied in Finder only while it runs
  /// (and asks once for Desktop, Documents and Downloads).
  static func read(_ source: Source, quality: MediaQuality, maxBytes: Int) -> [MediaIntake.Part]? {
    // One picture copied in Finder (a screenshot on the Desktop): sent as a picture, optimized like any other, so
    // the iPhone shows it and a 12 MB PNG isn't kept back by the size limit for files.
    if source.fileURLs.count == 1, let url = source.fileURLs.first,
       let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
       let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size <= Self.maxPictureFileBytes,
       let data = try? Data(contentsOf: url),
       var part = MediaIntake.image(data, quality: quality, maxBytes: maxBytes, copiedAt: source.copiedAt) {
      let ext = UTType(part.type)?.preferredFilenameExtension ?? url.pathExtension
      part.name = url.deletingPathExtension().lastPathComponent + "." + ext
      return [part]
    }
    if !source.fileURLs.isEmpty {
      var total = 0
      for url in source.fileURLs {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        // Folders, packages and unreadable files stay on this Mac.
        guard values?.isRegularFile == true, let size = values?.fileSize else { return nil }
        total += size
        guard total <= maxBytes else { return nil }
      }
      var parts: [MediaIntake.Part] = []
      for url in source.fileURLs {
        guard let data = try? Data(contentsOf: url) else { return nil }
        parts.append(MediaIntake.file(named: url.lastPathComponent, data: data))
      }
      return parts
    }
    // A PDF first: Preview copies a PDF selection with a picture of it, often far larger than the PDF.
    if let pdf = source.pdfData, pdf.count <= maxBytes {
      return [MediaIntake.pdf(pdf, copiedAt: source.copiedAt)]
    }
    if let image = source.imageData {
      return MediaIntake.image(image, quality: quality, maxBytes: maxBytes, copiedAt: source.copiedAt).map { [$0] }
    }
    return nil
  }
}
