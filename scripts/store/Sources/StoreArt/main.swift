import AppKit
import ImageIO
import PastronautCore
import SwiftUI
import UniformTypeIdentifiers

// App Store pictures for Pastronaut, from screenshots taken with made-up clips only.
//
// Usage: swift run -c release StoreArt <raw dir> <out dir>
//   <raw dir>/<lang>/12-01-cards-light.png …                iPhone (SyncStepTests `storeShots12`, 1290 × 2796)
//   <raw dir>/mac/<lang>-light.png, preview-<lang>-light.png, queue-…, filter-…, iphone-…   Mac popup
//                                                                   (MaccyUITests `testPastronautReadmeShots`)
// Writes, per language (en, tr), opaque PNGs as App Store Connect requires:
//   iphone-1…10.png  1320 × 2868   (iPhone 6.9"; frames 1 and 2 are one panorama; Gallery.swift)
//   mac-1…5.png      2880 × 1800   (Mac; frames 1 and 2 are one panorama)
//   header.png       3840 × 1646   (product page header, 21:9)
//   search.png       3840 × 2560   (search result, 3:2)

// MARK: - Words

typealias Words = [String: String]

struct Caption {
  let eyebrow: Words
  let title: Words
  let subtitle: Words
  let color: Color
}

enum Brand {
  static let sky = Color(red: 0.529, green: 0.808, blue: 0.922)
  static let deepSky = Color(red: 0.118, green: 0.435, blue: 0.659)
  static let mistTop = Color(red: 0.957, green: 0.973, blue: 0.992)
  static let mistBottom = Color(red: 0.851, green: 0.922, blue: 0.976)
  static let navyTop = Color(red: 0.055, green: 0.086, blue: 0.133)
  static let navyBottom = Color(red: 0.102, green: 0.153, blue: 0.231)
  static let ink = Color(red: 0.086, green: 0.125, blue: 0.180)
  static let muted = Color(red: 0.333, green: 0.380, blue: 0.451)
  // Eyebrow colors: the kinds' own colors (ClipKind palette, light-mode values).
  static let link = Color(red: 0.137, green: 0.392, blue: 0.824)
  static let code = Color(red: 0.451, green: 0.286, blue: 0.816)
  static let email = Color(red: 0.043, green: 0.498, blue: 0.533)
  static let phone = Color(red: 0.165, green: 0.522, blue: 0.251)
  static let address = Color(red: 0.753, green: 0.341, blue: 0.059)
  static let text = Color(red: 0.369, green: 0.408, blue: 0.471)
}

let tagline: Words = ["en": "Every copy, one tap away.", "tr": "Her kopya, bir dokunuş uzağında."]
let heroLine: Words = ["en": "Clipboard history + paste keyboard\nfor iPhone and Mac",
                       "tr": "Pano geçmişi ve yapıştırma klavyesi\niPhone ve Mac için"]

// MARK: - Shared pieces

struct Background: View {
  var dark = false
  var body: some View {
    ZStack {
      LinearGradient(colors: dark ? [Brand.navyTop, Brand.navyBottom] : [Brand.mistTop, Brand.mistBottom],
                     startPoint: .top, endPoint: .bottom)
      // The orbit from the wordmark, large and faint.
      GeometryReader { geo in
        Ellipse()
          .stroke((dark ? Brand.sky : Brand.deepSky).opacity(0.10), lineWidth: geo.size.width / 600)
          .frame(width: geo.size.width * 1.1, height: geo.size.height * 0.42)
          .rotationEffect(.degrees(-14))
          .position(x: geo.size.width * 0.55, y: geo.size.height * 0.36)
      }
    }
  }
}

struct CaptionView: View {
  let caption: Caption
  let lang: String
  let scale: CGFloat
  var dark = false
  var alignment: HorizontalAlignment = .center

  var body: some View {
    VStack(alignment: alignment, spacing: 0) {
      Text(caption.eyebrow[lang] ?? "")
        .font(.system(size: 40 * scale, weight: .heavy))
        .tracking(4 * scale)
        .foregroundStyle(dark ? Brand.sky : caption.color)
        .padding(.bottom, 22 * scale)
      Text(caption.title[lang] ?? "")
        .font(.system(size: 104 * scale, weight: .bold))
        .lineSpacing(2 * scale)
        .foregroundStyle(dark ? Color.white : Brand.ink)
        .fixedSize(horizontal: false, vertical: true)
      Text(caption.subtitle[lang] ?? "")
        .font(.system(size: 46 * scale, weight: .medium))
        .foregroundStyle(dark ? Brand.sky.opacity(0.9) : Brand.muted)
        .padding(.top, 26 * scale)
        .fixedSize(horizontal: false, vertical: true)
    }
    .multilineTextAlignment(alignment == .center ? .center : .leading)
  }
}

/// A screen or window picture with rounded corners and a soft shadow.
struct Shot: View {
  let image: NSImage
  let width: CGFloat
  var radius: CGFloat = 80
  var dark = false

  var body: some View {
    Image(nsImage: image)
      .resizable()
      .interpolation(.high)
      .frame(width: width, height: width * image.size.height / image.size.width)
      .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
        .strokeBorder((dark ? Color.white : Brand.ink).opacity(0.10), lineWidth: max(2, width / 400)))
      .shadow(color: .black.opacity(dark ? 0.55 : 0.20), radius: width / 22, y: width / 50)
  }
}

// iPhone frames: Gallery.swift.

// MARK: - Mac frames (2880 × 1800)

struct MacFrame: View {
  let caption: Caption
  let lang: String
  let window: NSImage

  var body: some View {
    ZStack(alignment: .topLeading) {
      Background()
      CaptionView(caption: caption, lang: lang, scale: 1.25, alignment: .leading)
        .frame(width: 940, alignment: .leading)
        .position(x: 180 + 470, y: 900)
      let width: CGFloat = min(1660, 1500 * window.size.width / window.size.height)
      Shot(image: window, width: width, radius: 40)
        .position(x: 2880 - 120 - width / 2, y: 900)
    }
    .frame(width: 2880, height: 1800)
    .clipped()
  }
}

/// Mac frames 1 and 2 as one picture: the Mac window and the iPhone side by side across the seam.
struct MacPanorama: View {
  let lang: String
  let mac: NSImage
  let iphone: NSImage

  static let first = Caption(
    eyebrow: ["en": "PASTRONAUT", "tr": "PASTRONAUT"],
    title: ["en": "Your clipboard,\non Mac and iPhone", "tr": "Panon, Mac'te\nve iPhone'da"],
    subtitle: ["en": "Everything you copy, one shortcut away.", "tr": "Kopyaladığın her şey bir kısayol uzağında."],
    color: Brand.link)
  static let second = Caption(
    eyebrow: ["en": "SYNC", "tr": "EŞİTLE"],
    title: ["en": "Copy on one,\npaste on the other", "tr": "Birinde kopyala,\nötekinde yapıştır"],
    subtitle: ["en": "Through your own private iCloud.", "tr": "Kendi özel iCloud'un üzerinden."],
    color: Brand.email)

  var body: some View {
    ZStack(alignment: .topLeading) {
      Background()
      CaptionView(caption: Self.first, lang: lang, scale: 1.25, alignment: .leading)
        .frame(width: 1000, alignment: .leading)
        .position(x: 180 + 500, y: 760)
      Shot(image: mac, width: 1300, radius: 44)
        .position(x: 2700, y: 960)
      Shot(image: iphone, width: 760, radius: 70)
        .position(x: 3620, y: 300 + 760 * iphone.size.height / iphone.size.width / 2)
      CaptionView(caption: Self.second, lang: lang, scale: 1.25, alignment: .leading)
        .frame(width: 1000, alignment: .leading)
        .position(x: 4250 + 500, y: 760)
    }
    .frame(width: 5760, height: 1800)
    .clipped()
  }
}

let macFrames: [(file: String, caption: Caption)] = [
  ("preview", Caption(
    eyebrow: ["en": "PREVIEW", "tr": "ÖNİZLE"],
    title: ["en": "Press Space\nto look closer", "tr": "Space'e bas,\nyakından bak"],
    subtitle: ["en": "Colored code, color swatches, maps and links.", "tr": "Renkli kod, renk örnekleri, harita ve bağlantılar."],
    color: Brand.code)),
  ("queue", Caption(
    eyebrow: ["en": "QUEUE", "tr": "SIRA"],
    title: ["en": "Paste a list,\nin order", "tr": "Bir listeyi\nsırayla yapıştır"],
    subtitle: ["en": "Select a few, then every ⌘V pastes the next.", "tr": "Birkaçını seç, her ⌘V sıradakini yapıştırır."],
    color: Brand.address)),
  ("filter", Caption(
    eyebrow: ["en": "FIND", "tr": "BUL"],
    title: ["en": "Type a filter,\nfind it fast", "tr": "Süzgeci yaz,\nhemen bul"],
    subtitle: ["en": "type:code, app:Safari, date:yesterday.", "tr": "tür:kod, uygulama:Safari, tarih:dün."],
    color: Brand.email))
]

// MARK: - Header (3840 × 1646) and search result (3840 × 2560)

struct HeaderArt: View {
  let lang: String
  let mac: NSImage
  let iphone: NSImage

  var body: some View {
    ZStack {
      Background(dark: true)
      // Real screens at the sides; the centered safe area (1646 × 661) holds the message.
      Shot(image: mac, width: 900, radius: 30, dark: true)
        .rotationEffect(.degrees(-6))
        .position(x: 560, y: 1000)
      Shot(image: iphone, width: 640, radius: 56, dark: true)
        .rotationEffect(.degrees(6))
        .position(x: 3300, y: 1150)
      VStack(spacing: 46) {
        PastronautWordmark(size: 120).environment(\.colorScheme, .dark)
        Text(tagline[lang] ?? "")
          .font(.system(size: 76, weight: .semibold))
          .foregroundStyle(.white)
      }
      .position(x: 1920, y: 823)
    }
    .frame(width: 3840, height: 1646)
    .clipped()
  }
}

struct SearchArt: View {
  let lang: String
  let keyboard: NSImage
  let cards: NSImage
  let mac: NSImage

  var body: some View {
    ZStack {
      Background()
      // "State the obvious": what it is, in the centered safe area (2168 × 1030), with the real screens.
      VStack(spacing: 30) {
        PastronautWordmark(size: 92).environment(\.colorScheme, .light)
        Text(heroLine[lang] ?? "")
          .font(.system(size: 72, weight: .bold))
          .foregroundStyle(Brand.ink)
          .multilineTextAlignment(.center)
      }
      .position(x: 1920, y: 960)
      HStack(alignment: .top, spacing: 70) {
        Shot(image: keyboard, width: 560, radius: 52)
        Shot(image: mac, width: 1000, radius: 32)
        Shot(image: cards, width: 560, radius: 52)
      }
      .position(x: 1920, y: 1250 + 1000 * mac.size.height / mac.size.width / 2)
    }
    .frame(width: 3840, height: 2560)
    .clipped()
  }
}

// MARK: - Output

func load(_ url: URL, cropTop: Int = 0) -> NSImage? {
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
        let cropped = image.cropping(to: CGRect(x: 0, y: cropTop, width: image.width, height: image.height - cropTop))
  else { return nil }
  return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
}

@MainActor
func render(_ view: some View, width: Int, height: Int) throws -> CGImage {
  let renderer = ImageRenderer(content: view)
  renderer.scale = 1
  renderer.proposedSize = ProposedViewSize(width: CGFloat(width), height: CGFloat(height))
  guard let image = renderer.cgImage else { throw NSError(domain: "StoreArt", code: 1) }
  return image
}

/// Writes `rect` of `image` as an opaque PNG (App Store Connect rejects alpha channels).
func writeOpaque(_ image: CGImage, rect: CGRect? = nil, to url: URL) throws {
  let rect = rect ?? CGRect(x: 0, y: 0, width: image.width, height: image.height)
  guard let part = image.cropping(to: rect),
        let context = CGContext(data: nil, width: part.width, height: part.height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    throw NSError(domain: "StoreArt", code: 2)
  }
  context.setFillColor(CGColor(gray: 1, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: part.width, height: part.height))
  context.draw(part, in: CGRect(x: 0, y: 0, width: part.width, height: part.height))
  guard let opaque = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    throw NSError(domain: "StoreArt", code: 3)
  }
  CGImageDestinationAddImage(destination, opaque, nil)
  guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "StoreArt", code: 4) }
  print("wrote \(url.deletingLastPathComponent().lastPathComponent)/\(url.lastPathComponent) \(part.width)×\(part.height)")
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
  let statusBar = 150 // iPhone status bar (time, Focus icons) is not part of the app.

  for lang in ["en", "tr"] {
    let dir = out.appending(path: lang)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    func phone(_ name: String) throws -> NSImage {
      guard let image = load(raw.appending(path: "\(lang)/\(name).png"), cropTop: statusBar) else {
        throw NSError(domain: "StoreArt missing \(lang)/\(name)", code: 5)
      }
      return image
    }
    func mac(_ name: String) throws -> NSImage {
      guard let image = load(raw.appending(path: "mac/\(name).png")) else {
        throw NSError(domain: "StoreArt missing mac/\(name)", code: 5)
      }
      return image
    }
    let macList = try mac("\(lang)-light")
    let cardsLight = try phone("12-01-cards-light")

    // iPhone (since 1.2): panorama (frames 1–2), then eight frames; App Store Connect takes up to ten.
    func full(_ name: String) throws -> NSImage {
      guard let image = load(raw.appending(path: "\(lang)/\(name).png")) else {
        throw NSError(domain: "StoreArt missing \(lang)/\(name)", code: 5)
      }
      return image
    }
    let panorama = try render(
      GalleryPanorama(lang: lang, phone: try full("12-01-cards-light"), mac: macList, macPhone: try full("12-12-mac-dark")),
      width: 2640, height: 2868)
    try writeOpaque(panorama, rect: CGRect(x: 0, y: 0, width: 1320, height: 2868), to: dir.appending(path: "iphone-1.png"))
    try writeOpaque(panorama, rect: CGRect(x: 1320, y: 0, width: 1320, height: 2868), to: dir.appending(path: "iphone-2.png"))
    for (offset, frame) in galleryFrames.enumerated() {
      let view = GalleryFrameView(index: offset + 2, frame: frame, lang: lang, screen: try full(frame.shot))
      try writeOpaque(try render(view, width: 1320, height: 2868), to: dir.appending(path: "iphone-\(offset + 3).png"))
    }

    // Mac: panorama (frames 1–2), then three frames.
    let macPanorama = try render(MacPanorama(lang: lang, mac: macList, iphone: cardsLight), width: 5760, height: 1800)
    try writeOpaque(macPanorama, rect: CGRect(x: 0, y: 0, width: 2880, height: 1800), to: dir.appending(path: "mac-1.png"))
    try writeOpaque(macPanorama, rect: CGRect(x: 2880, y: 0, width: 2880, height: 1800), to: dir.appending(path: "mac-2.png"))
    for (index, frame) in macFrames.enumerated() {
      let view = MacFrame(caption: frame.caption, lang: lang, window: try mac("\(frame.file)-\(lang)-light"))
      try writeOpaque(try render(view, width: 2880, height: 1800), to: dir.appending(path: "mac-\(index + 3).png"))
    }

    // Header and search result.
    try writeOpaque(try render(HeaderArt(lang: lang, mac: macList, iphone: cardsLight), width: 3840, height: 1646),
                    to: dir.appending(path: "header.png"))
    try writeOpaque(try render(SearchArt(lang: lang, keyboard: try phone("12-04-keyboard-light"), cards: cardsLight, mac: macList),
                               width: 3840, height: 2560),
                    to: dir.appending(path: "search.png"))
  }
}

try MainActor.assumeIsolated { try run() }
