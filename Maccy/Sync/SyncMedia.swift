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
    // A Universal Clipboard copy came from a device that syncs it itself.
    guard !item.universalClipboard else { return }
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
    let source = MediaCapture.Source(
      fileURLs: item.fileURLs,
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
      guard let clip = await MediaCapture.capture(source, quality: quality, privacy: privacy, sync: sync) else { return }
      self?.finishCapture(clip, of: item)
    }
  }

  private func finishCapture(_ clip: Clip, of item: HistoryItem) {
    // Deleted while the files were read.
    guard History.shared.allItems.contains(where: { $0.item == item }), item.pastronautMediaID == nil else { return }
    item.contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.pastronautMediaID.rawValue, value: Data(clip.id.utf8)))
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

  /// What a media clip shows without a title of its own: the first line of its text, or its file names.
  nonisolated static func mediaTitle(of clip: Clip) -> String {
    if let line = clip.media?.recognizedText?.split(whereSeparator: \.isNewline).first {
      return String(line.prefix(Clip.maxTitleLength))
    }
    return clip.media?.files.map(\.name).joined(separator: ", ") ?? ""
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
    guard privacy.allows(prepared.clip.privacyText, pinned: prepared.clip.pinned),
          await sync.allowsMedia(prepared.clip),
          (try? MediaIntake.store(prepared, in: sync.media)) != nil else { return nil }
    return prepared.clip
  }

  /// The bytes to send. Files are read now: macOS lets this app read a file copied in Finder only while it runs
  /// (and asks once for Desktop, Documents and Downloads).
  static func read(_ source: Source, quality: MediaQuality, maxBytes: Int) -> [MediaIntake.Part]? {
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
    if let image = source.imageData {
      return MediaIntake.image(image, quality: quality, maxBytes: maxBytes, copiedAt: source.copiedAt).map { [$0] }
    }
    if let pdf = source.pdfData, pdf.count <= maxBytes {
      return [MediaIntake.pdf(pdf, copiedAt: source.copiedAt)]
    }
    return nil
  }
}
