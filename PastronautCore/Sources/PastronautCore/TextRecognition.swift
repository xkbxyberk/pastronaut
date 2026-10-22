import CoreGraphics
import Foundation
import Vision

/// Text in an image (a scanned page, later a synced picture), read on the device with Vision. Nothing leaves it.
public enum TextRecognition {
  public enum Failure: Error {
    case nothingFound
  }

  /// The languages Vision can read on this system, best first: the person's own languages, then Turkish and
  /// English, which most of Pastronaut's people write in.
  public static func languages(preferred: [String] = Locale.preferredLanguages) -> [String] {
    let supported = (try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? []
    var result: [String] = []
    for wanted in preferred + ["tr-TR", "en-US"] {
      let base = wanted.split(separator: "-").first.map(String.init) ?? wanted
      if let match = supported.first(where: { $0 == wanted }) ?? supported.first(where: { $0.hasPrefix(base + "-") }),
         !result.contains(match) {
        result.append(match)
      }
    }
    return result.isEmpty ? Array(supported.prefix(1)) : result
  }

  /// Whether this system reads Turkish (it depends on the OS version).
  public static var readsTurkish: Bool {
    ((try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? []).contains { $0.hasPrefix("tr") }
  }

  /// The lines found in `image`, top to bottom, joined with line breaks. Runs off the calling actor.
  public static func text(in image: CGImage, languages: [String] = languages()) async throws -> String {
    try await Task.detached(priority: .userInitiated) {
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      request.recognitionLanguages = languages
      // Synchronous: the results are on the request when it returns.
      try VNImageRequestHandler(cgImage: image).perform([request])
      // Vision's y axis points up: a larger y is higher on the page.
      let lines = (request.results ?? [])
        .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        .compactMap { $0.topCandidates(1).first?.string }
      guard !lines.isEmpty else { throw Failure.nothingFound }
      return lines.joined(separator: "\n")
    }.value
  }

  /// Every page of a scan, in order, with a blank line between pages. Pages without text are skipped.
  public static func text(inPages pages: [CGImage], languages: [String] = languages()) async -> String? {
    var texts: [String] = []
    for page in pages {
      if let text = try? await text(in: page, languages: languages) {
        texts.append(text)
      }
    }
    return texts.isEmpty ? nil : texts.joined(separator: "\n\n")
  }
}
