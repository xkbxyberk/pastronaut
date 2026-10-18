import AppKit
import ImageIO
import PastronautCore
import SwiftUI
import UniformTypeIdentifiers

// Usage: swift run StoreArt <raw dir> <out dir>
// <raw dir>/<lang>/<n>-<name>-<light|dark>.png are device screenshots (1290 × 2796) from SyncStepTests `storeShots`.
// Writes <out dir>/<lang>/screenshot-<n>.png (1320 × 2868) and <out dir>/<lang>/header-universal.png (5244 × 2950),
// opaque PNGs as App Store Connect requires.

struct Frame {
  let number: Int
  let file: String
  let dark: Bool
  /// The whole screen, scaled to fit (keyboard frames); otherwise the top of the screen, bleeding off the bottom.
  var fit = false
  let title: [String: String]
  let subtitle: [String: String]
}

// The iPhone's own job first (a clipboard keyboard); the Mac app last, as an extra.
let frames: [Frame] = [
  Frame(number: 1, file: "0-keyboard-light", dark: false, fit: true,
        title: ["en": "Paste anything\nin one tap", "tr": "Her kopya\ntek dokunuşla"],
        subtitle: ["en": "Your clipboard history as a keyboard, in every app.",
                   "tr": "Pano geçmişin, her uygulamada klavyende."]),
  Frame(number: 2, file: "1-cards-light", dark: false,
        title: ["en": "Smart cards\nfor every kind", "tr": "Her türe\nakıllı kart"],
        subtitle: ["en": "Maps for addresses, previews for links, colored code.",
                   "tr": "Adrese harita, bağlantıya önizleme, koda renk."]),
  Frame(number: 3, file: "4-collection-light", dark: false,
        title: ["en": "Pin and collect\nwhat you reuse", "tr": "Sabitle,\nkoleksiyonla"],
        subtitle: ["en": "Addresses, snippets and links, together.", "tr": "Adresler, parçacıklar, bağlantılar bir arada."]),
  Frame(number: 4, file: "2-keyboard-dark", dark: true, fit: true,
        title: ["en": "Find any copy\nin seconds", "tr": "Aradığını\nsaniyede bul"],
        subtitle: ["en": "Search by text, kind or date.", "tr": "Metne, türe ya da tarihe göre ara."]),
  Frame(number: 5, file: "5-list-light", dark: false,
        title: ["en": "Private\nby design", "tr": "Gizlilik\nöncelikli"],
        subtitle: ["en": "No account. No tracking. No ads.", "tr": "Hesap yok. İzleme yok. Reklam yok."]),
  Frame(number: 6, file: "6-mac-dark", dark: true,
        title: ["en": "Also on\nyour Mac", "tr": "Mac'inde\nde"],
        subtitle: ["en": "Your Mac copies arrive on their own.", "tr": "Mac kopyaların kendiliğinden gelir."])
]

let tagline = ["en": "Every copy, one tap away.", "tr": "Her kopya, bir dokunuş uzağında."]

// MARK: - Colors

enum Brand {
  static let deepSky = Color(red: 0.118, green: 0.435, blue: 0.659)
  static let sky = Color(red: 0.529, green: 0.808, blue: 0.922)
  static let navyTop = Color(red: 0.055, green: 0.086, blue: 0.133)
  static let navyBottom = Color(red: 0.090, green: 0.133, blue: 0.200)
  static let mistTop = Color(red: 0.925, green: 0.961, blue: 0.992)
  static let mistBottom = Color(red: 0.800, green: 0.902, blue: 0.965)
  static let ink = Color(red: 0.086, green: 0.125, blue: 0.180)
}

// MARK: - Views

/// An orbit like the one around the helmet in the wordmark, as a quiet background motif.
struct Orbit: View {
  let color: Color
  var body: some View {
    Ellipse()
      .stroke(color, lineWidth: 6)
      .rotationEffect(.degrees(-16))
  }
}

struct ScreenshotFrame: View {
  let frame: Frame
  let lang: String
  let shot: NSImage

  var body: some View {
    let dark = frame.dark
    ZStack(alignment: .top) {
      LinearGradient(colors: dark ? [Brand.navyTop, Brand.navyBottom] : [Brand.mistTop, Brand.mistBottom],
                     startPoint: .top, endPoint: .bottom)
      Orbit(color: (dark ? Brand.sky : Brand.deepSky).opacity(0.10))
        .frame(width: 2300, height: 900)
        .offset(x: 520, y: 380)
      VStack(spacing: 0) {
        // The app's own header already shows the wordmark, so the caption starts the frame.
        Spacer().frame(height: 210)
        Text(frame.title[lang] ?? "")
          .font(.system(size: 112, weight: .bold, design: .default))
          .multilineTextAlignment(.center)
          .lineSpacing(4)
          .foregroundStyle(dark ? Color.white : Brand.ink)
          .fixedSize(horizontal: false, vertical: true)
        Text(frame.subtitle[lang] ?? "")
          .font(.system(size: 50, weight: .medium))
          .multilineTextAlignment(.center)
          .foregroundStyle(dark ? Brand.sky : Brand.deepSky)
          .padding(.top, 30)
          .padding(.horizontal, 90)
        Spacer(minLength: 0)
      }
      .frame(width: 1320)
      // The screenshot without its status bar: whole (fit) or bleeding off the bottom edge.
      let width: CGFloat = frame.fit ? (2868 - 760 - 60) * shot.size.width / shot.size.height : 1110
      Image(nsImage: shot)
        .resizable()
        .frame(width: width, height: width * shot.size.height / shot.size.width)
        .clipShape(RoundedRectangle(cornerRadius: 86, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 86, style: .continuous)
          .strokeBorder((dark ? Color.white : Brand.ink).opacity(0.10), lineWidth: 4))
        .shadow(color: .black.opacity(dark ? 0.55 : 0.22), radius: 50, y: 24)
        .offset(y: 760)
    }
    .frame(width: 1320, height: 2868)
    .clipped()
  }
}

struct HeaderArt: View {
  let lang: String
  let left: NSImage
  let right: NSImage

  var body: some View {
    ZStack {
      LinearGradient(colors: [Brand.navyTop, Brand.navyBottom], startPoint: .top, endPoint: .bottom)
      Orbit(color: Brand.sky.opacity(0.14))
        .frame(width: 3900, height: 1250)
        .offset(y: -150)
      // Real screens at the sides, outside the safe area: decoration that may be cropped.
      phone(left).rotationEffect(.degrees(-8)).offset(x: -1780, y: 620)
      phone(right).rotationEffect(.degrees(8)).offset(x: 1780, y: 620)
      // Inside the centered safe area (about 1402 × 962, a little above the middle).
      VStack(spacing: 70) {
        PastronautWordmark(size: 150)
          .environment(\.colorScheme, .dark)
        Text(tagline[lang] ?? "")
          .font(.system(size: 92, weight: .semibold))
          .foregroundStyle(.white)
          .multilineTextAlignment(.center)
      }
      .offset(y: -160)
    }
    .frame(width: 5244, height: 2950)
    .clipped()
  }

  private func phone(_ image: NSImage) -> some View {
    Image(nsImage: image)
      .resizable()
      .frame(width: 1000, height: 1000 * image.size.height / image.size.width)
      .clipShape(RoundedRectangle(cornerRadius: 80, style: .continuous))
      .shadow(color: .black.opacity(0.6), radius: 60, y: 30)
  }
}

// MARK: - Output

/// The device screenshot without its status bar (time and focus icons aren't part of the app).
func loadShot(_ url: URL) -> NSImage? {
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
  let statusBar = 150
  guard let cropped = image.cropping(to: CGRect(x: 0, y: statusBar, width: image.width, height: image.height - statusBar))
  else { return nil }
  return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
}

@MainActor
func write(_ view: some View, width: Int, height: Int, to url: URL) throws {
  let renderer = ImageRenderer(content: view.environment(\.locale, Locale(identifier: "en")))
  renderer.scale = 1
  renderer.proposedSize = ProposedViewSize(width: CGFloat(width), height: CGFloat(height))
  guard let rendered = renderer.cgImage else { throw NSError(domain: "StoreArt", code: 1) }
  // Opaque: no alpha channel (App Store Connect rejects transparency).
  guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    throw NSError(domain: "StoreArt", code: 2)
  }
  context.setFillColor(CGColor(gray: 0, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
  context.draw(rendered, in: CGRect(x: 0, y: 0, width: width, height: height))
  guard let opaque = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    throw NSError(domain: "StoreArt", code: 3)
  }
  CGImageDestinationAddImage(destination, opaque, nil)
  guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "StoreArt", code: 4) }
}

@MainActor
func run() throws {
  let arguments = CommandLine.arguments
  guard arguments.count == 3 else {
    print("usage: StoreArt <raw dir> <out dir>")
    exit(2)
  }
  let raw = URL(fileURLWithPath: arguments[1])
  let out = URL(fileURLWithPath: arguments[2])
  for lang in ["en", "tr"] {
    let dir = out.appending(path: lang)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var shots: [Int: NSImage] = [:]
    for frame in frames {
      guard let shot = loadShot(raw.appending(path: "\(lang)/\(frame.file).png")) else {
        print("missing \(lang)/\(frame.file).png")
        continue
      }
      shots[frame.number] = shot
      try write(ScreenshotFrame(frame: frame, lang: lang, shot: shot), width: 1320, height: 2868,
                to: dir.appending(path: "screenshot-\(frame.number).png"))
      print("wrote \(lang)/screenshot-\(frame.number).png")
    }
    if let left = shots[1], let right = shots[2] {
      try write(HeaderArt(lang: lang, left: left, right: right), width: 5244, height: 2950,
                to: dir.appending(path: "header-universal.png"))
      print("wrote \(lang)/header-universal.png")
    }
  }
}

try MainActor.assumeIsolated { try run() }
