import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// Turns copied or shared content (an image, a PDF, files) into a media clip, the same way on every device and in
/// every extension: the version that is sent, its kind, the text in it and a thumbnail. Storing the result and the
/// shared limits are the caller's (`MediaStore`, `ClipSync.allowsMedia`).
public enum MediaIntake {
  /// One file of the clip.
  public struct Part: Sendable {
    public var name: String
    /// Uniform type identifier of `data`.
    public var type: String
    /// The bytes that are kept and sent.
    public var data: Data
    /// What was copied, before conversion; names the clip, so copying it again finds the same one.
    public var original: Data

    public init(name: String, type: String, data: Data, original: Data? = nil) {
      self.name = name
      self.type = type
      self.data = data
      self.original = original ?? data
    }
  }

  public struct Prepared: Sendable {
    public var clip: Clip
    /// In the order of `clip.media.files`.
    public var files: [Data]
    public var thumbnail: Data?
  }

  /// An image as it is sent (`MediaQuality`); nil when it isn't an image or is larger than `maxBytes` after that.
  public static func image(_ data: Data, quality: MediaQuality, maxBytes: Int, copiedAt: Date = .now) -> Part? {
    guard let prepared = MediaProcessing.prepared(data, quality: quality), prepared.data.count <= maxBytes else {
      return nil
    }
    return Part(
      name: MediaProcessing.defaultName(forImageOfType: prepared.type, at: copiedAt), type: prepared.type,
      data: prepared.data, original: data
    )
  }

  /// A PDF copied as data, without a name of its own.
  public static func pdf(_ data: Data, name: String? = nil, copiedAt: Date = .now) -> Part {
    Part(
      name: name ?? MediaProcessing.defaultName(prefix: "Document", type: UTType.pdf.identifier, at: copiedAt),
      type: UTType.pdf.identifier, data: data
    )
  }

  /// A file with its name; its type comes from the name.
  public static func file(named name: String, data: Data) -> Part {
    Part(name: name, type: MediaProcessing.type(ofFileNamed: name), data: data)
  }

  /// The clip for these parts: one image is an image, one PDF a PDF, anything else files. The text in an image
  /// (Vision, on this device) or a PDF is read for search and the privacy filters.
  public static func prepare(
    _ parts: [Part],
    sourceApp: String? = nil,
    sourceAppName: String? = nil,
    device: Clip.Device,
    copiedAt: Date = .now,
    pinned: Bool = false,
    readsText: Bool = true
  ) async -> Prepared? {
    guard let first = parts.first else { return nil }
    let kind: Clip.Kind
    if parts.count == 1, MediaProcessing.isImage(first.type) {
      kind = .image
    } else if parts.count == 1, MediaProcessing.isPDF(first.type) {
      kind = .pdf
    } else {
      kind = .file
    }
    let size = kind == .image ? MediaProcessing.pixelSize(of: first.data) : nil
    var text: String?
    var thumbnail: Data?
    switch kind {
    case .image:
      if readsText, let image = MediaProcessing.cgImage(of: first.data) {
        text = try? await TextRecognition.text(in: image)
      }
      thumbnail = MediaProcessing.thumbnail(ofImage: first.data)
    case .pdf:
      text = readsText ? MediaProcessing.text(inPDF: first.data) : nil
      thumbnail = MediaProcessing.thumbnail(ofPDF: first.data)
    default:
      break
    }
    let media = ClipMedia(
      kind: kind, files: parts.map { ClipMedia.File(name: $0.name, type: $0.type, data: $0.data) },
      pixelWidth: size?.width, pixelHeight: size?.height, recognizedText: text
    )
    let clip = Clip(
      media: media, contentHashes: parts.map { ClipMedia.sha256($0.original) }, sourceApp: sourceApp,
      sourceAppName: sourceAppName, sourceDevice: device, firstCopiedAt: copiedAt, lastCopiedAt: copiedAt,
      pinned: pinned
    )
    return Prepared(clip: clip, files: parts.map(\.data), thumbnail: thumbnail)
  }

  /// Keeps a prepared clip's files and thumbnail in `store`.
  public static func store(_ prepared: Prepared, in store: MediaStore) throws {
    try store.store(prepared.files, for: prepared.clip)
    if let thumbnail = prepared.thumbnail {
      try store.storeThumbnail(thumbnail, for: prepared.clip.id)
    }
  }
}

// MARK: - From item providers (Paste button, Share, Action)

extension MediaIntake {
  /// Plain text or a web link, when that is what was handed over.
  public static func text(from providers: [NSItemProvider]) async -> String? {
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
         let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
         let url = webURL(fromURLItem: item), !url.isFileURL {
        return url.absoluteString
      }
      if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
         !provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
         let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
        return text
      }
    }
    return nil
  }

  /// The link in a URL item. Copies from Safari and other apps arrive as a property list (`bplist00…`) holding the
  /// address, not as its bytes: read as bytes, the list itself became the "link" (seen in 1.3 with Paste).
  static func webURL(fromURLItem item: Any) -> URL? {
    if let url = item as? URL { return url }
    guard let data = item as? Data else { return nil }
    if let list = try? PropertyListSerialization.propertyList(from: data, format: nil) {
      return firstURL(in: list)
    }
    guard let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
      return nil
    }
    return Self.url(string)
  }

  /// The first string in a property list (arrays, dictionaries, a keyed archive's objects) that is an address.
  private static func firstURL(in list: Any) -> URL? {
    switch list {
    case let string as String: return url(string)
    case let array as [Any]: return array.lazy.compactMap(firstURL(in:)).first
    case let dictionary as [String: Any]:
      // A keyed archive keeps its strings in "$objects", in order.
      if let objects = dictionary["$objects"] { return firstURL(in: objects) }
      return dictionary.values.lazy.compactMap(firstURL(in:)).first
    default: return nil
    }
  }

  private static func url(_ string: String) -> URL? {
    guard let url = URL(string: string), let scheme = url.scheme, !scheme.isEmpty, string.count > scheme.count + 1
    else { return nil }
    return url
  }

  /// Images, PDFs and other files from item providers, as parts of one clip. Images are prepared (`MediaQuality`);
  /// anything larger than `maxBytes` in all is left out.
  public static func parts(from providers: [NSItemProvider], quality: MediaQuality, maxBytes: Int) async -> [Part] {
    var parts: [Part] = []
    var total = 0
    for provider in providers {
      guard let part = await part(from: provider, quality: quality, maxBytes: maxBytes - total) else { continue }
      total += part.data.count
      parts.append(part)
    }
    return parts
  }

  static func part(from provider: NSItemProvider, quality: MediaQuality, maxBytes: Int) async -> Part? {
    let types = provider.registeredTypeIdentifiers.compactMap(UTType.init)
    if let pdf = types.first(where: { $0.conforms(to: .pdf) }), let data = await data(of: provider, type: pdf),
       data.count <= maxBytes {
      return MediaIntake.pdf(data, name: provider.suggestedName.map { $0.hasSuffix(".pdf") ? $0 : $0 + ".pdf" })
    }
    if let image = types.first(where: { $0.conforms(to: .image) }), let data = await data(of: provider, type: image) {
      return MediaIntake.image(data, quality: quality, maxBytes: maxBytes)
    }
    // Any other file (a document, a film): as it is, with its name.
    if let type = types.first(where: { $0.conforms(to: .data) && !$0.conforms(to: .text) }),
       let (data, name) = await file(of: provider, type: type), data.count <= maxBytes {
      return MediaIntake.file(named: name, data: data)
    }
    return nil
  }

  private static func data(of provider: NSItemProvider, type: UTType) async -> Data? {
    await withCheckedContinuation { continuation in
      _ = provider.loadDataRepresentation(for: type) { data, _ in continuation.resume(returning: data) }
    }
  }

  private static func file(of provider: NSItemProvider, type: UTType) async -> (Data, String)? {
    let suggestedName = provider.suggestedName
    return await withCheckedContinuation { continuation in
      _ = provider.loadFileRepresentation(for: type, openInPlace: false) { url, _, _ in
        guard let url, let data = try? Data(contentsOf: url) else { return continuation.resume(returning: nil) }
        let name = suggestedName.map { name in
          (name as NSString).pathExtension.isEmpty ? name + "." + url.pathExtension : name
        } ?? url.lastPathComponent
        continuation.resume(returning: (data, name))
      }
    }
  }

  /// Scanned pages as one PDF, each page the size of its image.
  public static func pdf(from pages: [CGImage]) -> Data? {
    guard !pages.isEmpty else { return nil }
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
      return nil
    }
    for page in pages {
      // 72 points per inch at the scan's pixel size reads as a normal page in any viewer when scaled to fit.
      let scale = 612 / CGFloat(max(page.width, 1))
      var box = CGRect(x: 0, y: 0, width: CGFloat(page.width) * scale, height: CGFloat(page.height) * scale)
      context.beginPage(mediaBox: &box)
      context.draw(page, in: box)
      context.endPage()
    }
    context.closePDF()
    return data as Data
  }
}
