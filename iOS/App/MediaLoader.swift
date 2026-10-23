import PastronautCore
import UIKit
import UniformTypeIdentifiers

/// Images, PDFs and files handed to the app: by the system Paste button, the clipboard, Markup or a scan.
enum MediaLoader {
  /// Item providers handed over by the system. Each is only read once, off the main thread.
  struct Providers: @unchecked Sendable {
    let items: [NSItemProvider]
  }

  static func text(from providers: Providers) async -> String? {
    await MediaIntake.text(from: providers.items)
  }

  static func parts(from providers: Providers, quality: MediaQuality, maxBytes: Int) async -> [MediaIntake.Part] {
    await MediaIntake.parts(from: providers.items, quality: quality, maxBytes: maxBytes)
  }

  static func pdf(from pages: [CGImage]) -> Data? {
    MediaIntake.pdf(from: pages)
  }

  /// Checks the clipboard's types without reading it, so no paste prompt appears.
  static func hasMedia(_ pasteboard: UIPasteboard) -> Bool {
    pasteboard.hasImages || pasteboard.contains(pasteboardTypes: [UTType.pdf.identifier])
  }

  /// The image or PDF on the clipboard. Reading it may show the paste prompt, as reading text does.
  static func parts(from pasteboard: UIPasteboard, quality: MediaQuality, maxBytes: Int) -> [MediaIntake.Part] {
    if let pdf = pasteboard.data(forPasteboardType: UTType.pdf.identifier), pdf.count <= maxBytes {
      return [MediaIntake.pdf(pdf)]
    }
    for type in [UTType.heic, .png, .jpeg, .gif, .tiff] {
      if let data = pasteboard.data(forPasteboardType: type.identifier),
         let part = MediaIntake.image(data, quality: quality, maxBytes: maxBytes) {
        return [part]
      }
    }
    if let image = pasteboard.image, let data = image.pngData(),
       let part = MediaIntake.image(data, quality: quality, maxBytes: maxBytes) {
      return [part]
    }
    return []
  }
}
