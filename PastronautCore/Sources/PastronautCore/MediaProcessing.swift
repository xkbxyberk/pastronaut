import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// Image and PDF work both apps share: the version of an image that is sent, thumbnails, and the text in a PDF.
/// ImageIO and CoreGraphics only, so it runs the same on the Mac, the iPhone and in tests.
public enum MediaProcessing {
  public struct PreparedImage: Sendable {
    public var data: Data
    /// Uniform type identifier of `data`.
    public var type: String
    public var pixelWidth: Int
    public var pixelHeight: Int
  }

  /// Width and height as shown (EXIF orientation applied).
  public static func pixelSize(of imageData: Data) -> (width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else {
      return nil
    }
    let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
    return (5...8).contains(orientation) ? (height, width) : (width, height)
  }

  /// The image as it is sent. Optimized: HEIC, at most `MediaQuality.maxLongEdge` on the long edge, unless the
  /// original is already smaller (or animated, which conversion would flatten). Original: as copied.
  public static func prepared(_ imageData: Data, quality: MediaQuality) -> PreparedImage? {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
          let type = CGImageSourceGetType(source) as String?,
          let size = pixelSize(of: imageData) else {
      return nil
    }
    let original = PreparedImage(data: imageData, type: type, pixelWidth: size.width, pixelHeight: size.height)
    guard quality == .optimized, CGImageSourceGetCount(source) == 1 else { return original }

    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: min(max(size.width, size.height), MediaQuality.maxLongEdge),
      kCGImageSourceCreateThumbnailWithTransform: true
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
          let heic = encode(image, as: .heic, quality: 0.8) else {
      return original
    }
    let fits = max(size.width, size.height) <= MediaQuality.maxLongEdge
    if fits && imageData.count <= heic.count { return original }
    return PreparedImage(data: heic, type: UTType.heic.identifier, pixelWidth: image.width, pixelHeight: image.height)
  }

  /// A JPEG of at most `maxBytes` (it goes in an encrypted CloudKit field), shrinking until it fits.
  public static func thumbnail(ofImage imageData: Data, maxBytes: Int = MediaRecord.maxThumbnailBytes) -> Data? {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
    for side in [480, 360, 240, 160] {
      let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: side,
        kCGImageSourceCreateThumbnailWithTransform: true
      ]
      guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
      if let data = smallJPEG(of: image, maxBytes: maxBytes) { return data }
    }
    return nil
  }

  /// The first page of a PDF on white, as a JPEG of at most `maxBytes`.
  public static func thumbnail(ofPDF pdfData: Data, maxBytes: Int = MediaRecord.maxThumbnailBytes) -> Data? {
    guard let provider = CGDataProvider(data: pdfData as CFData),
          let document = CGPDFDocument(provider),
          let page = document.page(at: 1) else {
      return nil
    }
    let box = page.getBoxRect(.cropBox)
    guard box.width > 0, box.height > 0 else { return nil }
    for side in [480, 360, 240, 160] {
      let scale = CGFloat(side) / max(box.width, box.height)
      let width = Int(box.width * scale), height = Int(box.height * scale)
      guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      ) else { return nil }
      context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
      context.scaleBy(x: scale, y: scale)
      context.translateBy(x: -box.minX, y: -box.minY)
      context.drawPDFPage(page)
      guard let image = context.makeImage() else { return nil }
      if let data = smallJPEG(of: image, maxBytes: maxBytes) { return data }
    }
    return nil
  }

  /// The text of a PDF, for search and the privacy filters; nil when it has none (a scan without OCR).
  public static func text(inPDF pdfData: Data) -> String? {
    let text = PDFDocument(data: pdfData)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return text.isEmpty ? nil : text
  }

  /// The uniform type identifier for a file name, "public.data" when unknown.
  public static func type(ofFileNamed name: String) -> String {
    UTType(filenameExtension: (name as NSString).pathExtension)?.identifier ?? UTType.data.identifier
  }

  public static func isPDF(_ type: String) -> Bool {
    UTType(type)?.conforms(to: .pdf) ?? false
  }

  public static func isImage(_ type: String) -> Bool {
    UTType(type)?.conforms(to: .image) ?? false
  }

  /// A file name for an image copied without one ("Image 2026-10-23 at 10.42.08.heic").
  public static func defaultName(forImageOfType type: String, at date: Date = .now) -> String {
    defaultName(prefix: "Image", type: type, at: date)
  }

  /// A file name for content copied without one: "<prefix> 2026-10-23 at 10.42.08.<extension of type>".
  public static func defaultName(prefix: String, type: String, at date: Date = .now) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
    let ext = UTType(type)?.preferredFilenameExtension ?? "png"
    return "\(prefix) \(formatter.string(from: date)).\(ext)"
  }

  /// The image as PNG, for apps that don't take HEIC or JPEG from the pasteboard. Orientation applied.
  public static func png(of imageData: Data) -> Data? {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
          let size = pixelSize(of: imageData) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
      kCGImageSourceCreateThumbnailWithTransform: true
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return encode(image, as: .png, quality: 1)
  }

  /// A decoded image for text recognition.
  public static func cgImage(of imageData: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  }

  // MARK: - Encoding

  static func encode(_ image: CGImage, as type: UTType, quality: Double) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
      return nil
    }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    return CGImageDestinationFinalize(destination) ? data as Data : nil
  }

  private static func smallJPEG(of image: CGImage, maxBytes: Int) -> Data? {
    for quality in [0.7, 0.5, 0.35] {
      if let data = encode(image, as: .jpeg, quality: quality), data.count <= maxBytes { return data }
    }
    return nil
  }
}
