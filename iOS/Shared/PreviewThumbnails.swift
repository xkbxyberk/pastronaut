import ImageIO
import PastronautCore
import UIKit

/// Where the app keeps link and map previews (`PreviewStore`): in the App Group, so the keyboard can show small
/// versions of them. Caches, so iOS may clear it; never synced.
enum PreviewCache {
  static var directory: URL {
    if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PastronautIDs.appGroup) {
      return container.appending(path: "Library/Caches/Previews")
    }
    return URL.cachesDirectory.appending(path: "Previews")
  }

  static func imageURL(for clipID: String) -> URL {
    directory.appending(path: "\(clipID).jpg")
  }
}

/// Small preview pictures for the keyboard, decoded straight at thumbnail size so a page image never costs the
/// extension more than a few kilobytes.
final class PreviewThumbnails: @unchecked Sendable {
  static let shared = PreviewThumbnails()

  private let cache = NSCache<NSString, UIImage>()
  /// Clips known to have no picture, so the file system isn't asked again on every render.
  private let missing = NSCache<NSString, NSNumber>()

  private init() {
    cache.countLimit = 120
  }

  private let titles = NSCache<NSString, NSString>()

  /// The page's name the app found for a link, if any.
  func title(for clipID: String) -> String? {
    let key = clipID as NSString
    if let hit = titles.object(forKey: key) { return hit.length == 0 ? nil : hit as String }
    struct Stored: Decodable { var title: String? }
    let url = PreviewCache.directory.appending(path: "\(clipID).json")
    let title = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }?.title
    titles.setObject((title ?? "") as NSString, forKey: key)
    return title
  }

  func image(for clipID: String, pixels: Int = 96) -> UIImage? {
    let key = clipID as NSString
    if let hit = cache.object(forKey: key) { return hit }
    if missing.object(forKey: key) != nil { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: pixels
    ]
    guard let source = CGImageSourceCreateWithURL(PreviewCache.imageURL(for: clipID) as CFURL, nil),
          let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      missing.setObject(true, forKey: key)
      return nil
    }
    let image = UIImage(cgImage: thumbnail)
    cache.setObject(image, forKey: key)
    return image
  }
}
