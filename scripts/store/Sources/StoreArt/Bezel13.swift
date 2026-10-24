import AppKit
import ImageIO
import PastronautCore
import SwiftUI

// App Store pictures for 1.3 (APPSTORE.md §9): the real screenshots, status and menu bars included, inside Apple's
// product bezels (Apple Design Resources), whole and straight, with the caption above the device.
//
// Usage: swift run -c release StoreArt bezel13 <raw dir> <bezel dir> <out dir>
//   <raw dir>/<lang>/s13-<lang>-….png   iPhone (SyncStepTests `storeShots13`)
//   <raw dir>/mac/m13-<lang>-….png      Mac, the whole screen (MaccyUITests `testPastronaut13StoreShots`)
//   <bezel dir>: the PNGs from Apple's bezel downloads. Their license allows them only in mock-ups of apps for
//   Apple platforms; they are never committed or shared, so the folder lives outside git.
// Writes iphone-1…10.png (1320 × 2868), mac-1…6.png (2880 × 1800), header.png (3840 × 1646) and search.png
// (3840 × 2560) per language, opaque.

struct Bezel {
  let image: CGImage
  /// The screen opening, in the bezel's pixels, top-left origin.
  let screen: CGRect
  /// White where the device is (frame and screen), so a screenshot never shows past its rounded corners.
  let mask: CGImage

  init(_ url: URL) throws {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw NSError(domain: "StoreArt missing bezel \(url.lastPathComponent)", code: 6)
    }
    self.image = image
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    // Buffer rows run top down here.
    func clear(_ x: Int, _ y: Int) -> Bool { pixels[(y * width + x) * 4 + 3] < 255 }

    // The opening: along the middle row, then down a column a quarter in, clear of both the rounded corners and the
    // camera (notch or Dynamic Island).
    let middle = height / 2
    var left = width / 2, right = width / 2
    while left > 0 && clear(left - 1, middle) { left -= 1 }
    while right < width - 1 && clear(right + 1, middle) { right += 1 }
    let column = left + (right - left) / 4
    var top = middle, bottom = middle
    while top > 0 && clear(column, top - 1) { top -= 1 }
    while bottom < height - 1 && clear(column, bottom + 1) { bottom += 1 }
    screen = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)

    // Outside the device: clear pixels reachable from the edges.
    var outside = [Bool](repeating: false, count: width * height)
    var stack: [Int] = []
    for x in 0..<width { stack.append(x); stack.append((height - 1) * width + x) }
    for y in 0..<height { stack.append(y * width); stack.append(y * width + width - 1) }
    while let index = stack.popLast() {
      if outside[index] || pixels[index * 4 + 3] == 255 { continue }
      outside[index] = true
      let x = index % width, y = index / width
      if x > 0 { stack.append(index - 1) }
      if x < width - 1 { stack.append(index + 1) }
      if y > 0 { stack.append(index - width) }
      if y < height - 1 { stack.append(index + width) }
    }
    var gray = outside.map { $0 ? UInt8(0) : UInt8(255) }
    let maskContext = CGContext(data: &gray, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    mask = maskContext.makeImage()!
  }

  /// The device with `shot` on its screen, filled to the opening (a 1290 × 2796 iPhone shot loses under 2 pixels a
  /// side in a 1320 × 2868 opening).
  func device(showing shot: CGImage) -> CGImage {
    let width = image.width, height = image.height
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let full = CGRect(x: 0, y: 0, width: width, height: height)
    // CoreGraphics counts y from the bottom.
    let opening = CGRect(x: screen.minX, y: CGFloat(height) - screen.maxY, width: screen.width, height: screen.height)
    let scale = max(opening.width / CGFloat(shot.width), opening.height / CGFloat(shot.height))
    let size = CGSize(width: CGFloat(shot.width) * scale, height: CGFloat(shot.height) * scale)
    context.saveGState()
    context.clip(to: full, mask: mask)
    context.clip(to: opening.insetBy(dx: -2, dy: -2))
    context.interpolationQuality = .high
    context.draw(shot, in: CGRect(x: opening.midX - size.width / 2, y: opening.midY - size.height / 2,
                                  width: size.width, height: size.height))
    context.restoreGState()
    context.draw(image, in: full)
    return context.makeImage()!
  }
}

struct Frame13: Sendable {
  let shot: String
  let eyebrow: Words
  let title: Words
  let dark: Bool
  /// iPhone: a sheet over a dimmed screen. The dimmed band above the sheet, which on a taller iPhone 18 reads as a
  /// grey stripe, takes the sheet's own color (`sheetBandCleaned`).
  var sheet = false
  /// Mac: no bezel, this part of the screen (pixels of the 2940 × 1912 shot) beside the caption, at its own size.
  var crop: CGRect? = nil
}

/// The part of the Mac screen the feature frames show: the right of the menu bar, the popup and what opens beside it.
let macFeatureCrop = CGRect(x: 1200, y: 0, width: 1740, height: 1660)

let iphoneFrames13: [Frame13] = [
  Frame13(shot: "01-mac-light", eyebrow: ["en": "SYNC", "tr": "EŞİTLE"],
          title: ["en": "Copy on your Mac,\npaste on your iPhone", "tr": "Mac'te kopyala,\niPhone'da yapıştır"], dark: false),
  Frame13(shot: "02-all-dark", eyebrow: ["en": "NEW", "tr": "YENİ"],
          title: ["en": "Photos, PDFs\nand files, too", "tr": "Fotoğraf, PDF\nve dosya da"], dark: true),
  Frame13(shot: "03-keyboard-copied-light", eyebrow: ["en": "PASTE", "tr": "YAPIŞTIR"],
          title: ["en": "Paste anything,\nin any app", "tr": "Her kopya,\nher uygulamada"], dark: false, sheet: true),
  Frame13(shot: "04-search-dark", eyebrow: ["en": "FIND", "tr": "BUL"],
          title: ["en": "Find the words\ninside pictures", "tr": "Resimdeki\nyazıyı bile bul"], dark: true),
  Frame13(shot: "05-filter-kinds-light", eyebrow: ["en": "FILTER", "tr": "SÜZ"],
          title: ["en": "Source, kind,\ncollection: one tap", "tr": "Kaynak, tür,\nkoleksiyon: tek dokunuş"], dark: false),
  Frame13(shot: "06-detail-poster-light", eyebrow: ["en": "LOOK", "tr": "BAK"],
          title: ["en": "Select text,\nmark up, save", "tr": "Yazıyı seç,\nişaretle, kaydet"], dark: false),
  Frame13(shot: "07-cards-dark", eyebrow: ["en": "SMART CARDS", "tr": "AKILLI KARTLAR"],
          title: ["en": "Every kind,\nits own card", "tr": "Her türe\nkendi kartı"], dark: true),
  Frame13(shot: "08-queue-dark", eyebrow: ["en": "QUEUE", "tr": "SIRA"],
          title: ["en": "Paste a list,\nin order", "tr": "Bir listeyi\nsırayla yapıştır"], dark: true, sheet: true),
  Frame13(shot: "09-clip-menu-light", eyebrow: ["en": "ORGANIZE", "tr": "DÜZENLE"],
          title: ["en": "Pin it, name it,\ncollect it", "tr": "Sabitle,\nadlandır, topla"], dark: false),
  Frame13(shot: "10-settings-privacy-light", eyebrow: ["en": "PRIVATE", "tr": "GİZLİ"],
          title: ["en": "No account.\nNo tracking.", "tr": "Hesap yok.\nİzleme yok."], dark: false, sheet: true)
]

let macFrames13: [Frame13] = [
  Frame13(shot: "01-popup", eyebrow: ["en": "PASTRONAUT", "tr": "PASTRONAUT"],
          title: ["en": "Your clipboard history, one click away", "tr": "Pano geçmişin, bir tık uzağında"], dark: false),
  // Frame 2 shows the Mac with the iPhone beside it: `MacAndPhone13`.
  Frame13(shot: "01-popup", eyebrow: ["en": "SYNC", "tr": "EŞİTLE"],
          title: ["en": "Copy on one, paste on the other", "tr": "Birinde kopyala, ötekinde yapıştır"], dark: false),
  Frame13(shot: "03-preview", eyebrow: ["en": "PREVIEW", "tr": "ÖNİZLE"],
          title: ["en": "Press Space\nto look closer", "tr": "Space'e bas,\nyakından bak"], dark: false, crop: macFeatureCrop),
  Frame13(shot: "04-filter-kinds", eyebrow: ["en": "FILTER", "tr": "SÜZ"],
          title: ["en": "Filter by device,\nkind or collection", "tr": "Cihaza, türe,\nkoleksiyona\ngöre süz"], dark: false, crop: macFeatureCrop),
  Frame13(shot: "05-search", eyebrow: ["en": "FIND", "tr": "BUL"],
          title: ["en": "Find screenshots\nby their words", "tr": "Ekran görüntüsünü\nyazısıyla bul"], dark: false, crop: macFeatureCrop),
  Frame13(shot: "06-queue", eyebrow: ["en": "QUEUE", "tr": "SIRA"],
          title: ["en": "Paste a list,\nin order", "tr": "Bir listeyi\nsırayla yapıştır"], dark: false, crop: macFeatureCrop)
]

struct Caption13: View {
  let frame: Frame13
  let lang: String
  var size: CGFloat = 104
  var alignment: HorizontalAlignment = .center

  var body: some View {
    VStack(alignment: alignment, spacing: 0) {
      Text(frame.eyebrow[lang] ?? "")
        .font(.system(size: size * 0.38, weight: .heavy))
        .tracking(size * 0.04)
        .foregroundStyle(frame.dark ? Brand.sky : Brand.deepSky)
        .padding(.bottom, size * 0.22)
      Text(frame.title[lang] ?? "")
        .font(.system(size: size, weight: .bold))
        .foregroundStyle(frame.dark ? Color.white : Brand.ink)
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// Mac feature frame: the caption on the left, a part of the real screen on the right, without a bezel.
struct MacFeature13: View {
  let frame: Frame13
  let lang: String
  let part: CGImage

  var body: some View {
    let height: CGFloat = 1600
    let width = height * CGFloat(part.width) / CGFloat(part.height)
    ZStack(alignment: .topLeading) {
      Background()
      Caption13(frame: frame, lang: lang, size: 92, alignment: .leading)
        .frame(width: 2880 - width - 300, alignment: .leading)
        .position(x: 150 + (2880 - width - 300) / 2, y: 900)
      Image(decorative: part, scale: 1)
        .resizable()
        .interpolation(.high)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(Brand.ink.opacity(0.10), lineWidth: 3))
        .shadow(color: .black.opacity(0.20), radius: 60, y: 24)
        .position(x: 2880 - 90 - width / 2, y: 900)
    }
    .frame(width: 2880, height: 1800)
  }
}

/// A sheet screenshot with the dimmed band above the sheet in the sheet's own color. The status bar's glyphs keep
/// their edges: a pixel mixed from glyph and backdrop is mixed again from glyph and sheet color.
func sheetBandCleaned(_ shot: CGImage) -> CGImage {
  let width = shot.width, height = shot.height
  var pixels = [UInt8](repeating: 0, count: width * height * 4)
  let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  context.draw(shot, in: CGRect(x: 0, y: 0, width: width, height: height))
  func color(_ x: Int, _ y: Int) -> [Double] { let i = (y * width + x) * 4; return (0..<3).map { Double(pixels[i + $0]) } }
  // The band: rows of one color from the top, down the middle (between the time and the status icons; at the
  // sides the sheet's rounded corners start lower).
  let backdrop = color(40, 0)
  var sheetTop = 0
  while sheetTop < height / 4 && color(width / 2, sheetTop) == backdrop { sheetTop += 1 }
  guard sheetTop > 0, sheetTop < height / 4 else { return shot }
  let sheet = color(width / 2, sheetTop + 30)
  let light = backdrop.reduce(0, +) / 3 > 100
  let glyph: Double = light ? 0 : 255
  func set(_ x: Int, _ y: Int, _ value: [Double]) {
    let i = (y * width + x) * 4
    for c in 0..<3 { pixels[i + c] = UInt8(max(0, min(255, value[c].rounded()))) }
  }
  // The sheet's shadow lies in the last rows above it: those rows go to the edge pass below.
  let edge = max(0, sheetTop - 6)
  for y in 0..<edge {
    for x in 0..<width {
      let p = color(x, y)
      // How much of the backdrop is in this pixel (1 = only backdrop, 0 = only glyph), from its brightness.
      let mix = (0..<3).map { c in backdrop[c] == glyph ? 1 : max(0, min(1, (p[c] - glyph) / (backdrop[c] - glyph))) }
      let share = mix.reduce(0, +) / 3
      set(x, y, (0..<3).map { p[$0] + (sheet[$0] - backdrop[$0]) * share })
    }
  }
  // The sheet's rounded top corners and its edge: what lies between backdrop and sheet color, or is the edge's
  // shadow (darker than the backdrop, grey), becomes sheet.
  let span = (0..<3).map { sheet[$0] - backdrop[$0] }
  let length = span.map { $0 * $0 }.reduce(0, +)
  // Also the sheet's top edge, a few rows across.
  for y in edge..<min(height, sheetTop + 100) {
    for x in 0..<width where x < 320 || x > width - 320 || y < sheetTop + 4 {
      let p = color(x, y)
      let offset = (0..<3).map { p[$0] - backdrop[$0] }
      let t = length > 0 ? (0..<3).map { offset[$0] * span[$0] }.reduce(0, +) / length : 0
      let off = (0..<3).map { offset[$0] - span[$0] * t }.map { $0 * $0 }.reduce(0, +)
      if t > -1.5, t < 1.1, off < 64 { set(x, y, sheet) }
    }
  }
  return context.makeImage() ?? shot
}

/// iPhone frame: the caption, then the whole device, centered.
struct PhoneFrame13: View {
  let frame: Frame13
  let lang: String
  let device: CGImage

  var body: some View {
    let height: CGFloat = 2180
    let width = height * CGFloat(device.width) / CGFloat(device.height)
    ZStack(alignment: .top) {
      Background(dark: frame.dark)
      Caption13(frame: frame, lang: lang)
        .frame(width: 1180, height: 520)
        .position(x: 660, y: 120 + 260)
      Image(decorative: device, scale: 1)
        .resizable()
        .interpolation(.high)
        .frame(width: width, height: height)
        .position(x: 660, y: 2868 - 90 - height / 2)
    }
    .frame(width: 1320, height: 2868)
  }
}

/// Mac frame: the caption, then the whole MacBook.
struct MacFrame13: View {
  let frame: Frame13
  let lang: String
  let device: CGImage

  var body: some View {
    let width: CGFloat = 2360
    let height = width * CGFloat(device.height) / CGFloat(device.width)
    ZStack(alignment: .top) {
      Background()
      Caption13(frame: frame, lang: lang, size: 96)
        .frame(width: 2700, height: 260)
        .position(x: 1440, y: 80 + 130)
      Image(decorative: device, scale: 1)
        .resizable()
        .interpolation(.high)
        .frame(width: width, height: height)
        .position(x: 1440, y: 1800 - 50 - height / 2)
    }
    .frame(width: 2880, height: 1800)
  }
}

/// Mac frame 2: the MacBook and, in front of it on the right, the iPhone with the same clips, both true to size.
struct MacAndPhone13: View {
  let frame: Frame13
  let lang: String
  let mac: CGImage
  let phone: CGImage
  /// iPhone width over MacBook width, as the real devices (about 7.8 cm and 30.4 cm).
  let phoneToMac: CGFloat

  var body: some View {
    let macWidth: CGFloat = 2200
    let macHeight = macWidth * CGFloat(mac.height) / CGFloat(mac.width)
    let phoneWidth = macWidth * phoneToMac
    let phoneHeight = phoneWidth * CGFloat(phone.height) / CGFloat(phone.width)
    ZStack(alignment: .top) {
      Background()
      Caption13(frame: frame, lang: lang, size: 96)
        .frame(width: 2700, height: 260)
        .position(x: 1440, y: 80 + 130)
      Image(decorative: mac, scale: 1)
        .resizable()
        .interpolation(.high)
        .frame(width: macWidth, height: macHeight)
        .position(x: 1290, y: 1800 - 50 - macHeight / 2)
      Image(decorative: phone, scale: 1)
        .resizable()
        .interpolation(.high)
        .frame(width: phoneWidth, height: phoneHeight)
        .position(x: 1290 + macWidth / 2 + phoneWidth * 0.05, y: 1800 - 40 - phoneHeight / 2)
    }
    .frame(width: 2880, height: 1800)
  }
}

@MainActor
func runBezel13(raw: URL, bezels: URL, out: URL) throws {
  let phoneLight = try Bezel(bezels.appending(path: "iPhone 18 Pro Max - Silver - Portrait.png"))
  let phoneDark = try Bezel(bezels.appending(path: "iPhone 18 Pro Max - Black - Portrait.png"))
  let macBezel = try Bezel(bezels.appending(path: macBezelFile13))
  func shot(_ path: String) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(raw.appending(path: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw NSError(domain: "StoreArt missing \(path)", code: 5)
    }
    return image
  }
  for lang in ["en", "tr"] {
    let dir = out.appending(path: lang)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for (index, frame) in iphoneFrames13.enumerated() {
      let bezel = frame.dark ? phoneDark : phoneLight
      let raw = try shot("\(lang)/s13-\(lang)-\(frame.shot).png")
      let device = bezel.device(showing: frame.sheet ? sheetBandCleaned(raw) : raw)
      try writeOpaque(try render(PhoneFrame13(frame: frame, lang: lang, device: device), width: 1320, height: 2868),
                      to: dir.appending(path: "iphone-\(index + 1).png"))
    }
    for (index, frame) in macFrames13.enumerated() {
      let screen = try shot("mac/m13-\(lang)-\(frame.shot).png")
      let view: AnyView
      if let crop = frame.crop {
        guard let part = screen.cropping(to: crop) else { throw NSError(domain: "StoreArt crop", code: 7) }
        try writeOpaque(try render(MacFeature13(frame: frame, lang: lang, part: part), width: 2880, height: 1800),
                        to: dir.appending(path: "mac-\(index + 1).png"))
        continue
      }
      let mac = macBezel.device(showing: screen)
      if index == 1 {
        let phone = phoneLight.device(showing: try shot("\(lang)/s13-\(lang)-01-mac-light.png"))
        // Picture widths that make the two bodies as wide as the real devices.
        let ratio = phoneWidthCM13 / macWidthCM13
          * (bodyWidth13(macBezel) / CGFloat(macBezel.image.width))
          * (CGFloat(phoneLight.image.width) / bodyWidth13(phoneLight))
        view = AnyView(MacAndPhone13(frame: frame, lang: lang, mac: mac, phone: phone, phoneToMac: ratio))
      } else {
        view = AnyView(MacFrame13(frame: frame, lang: lang, device: mac))
      }
      try writeOpaque(try render(view, width: 2880, height: 1800), to: dir.appending(path: "mac-\(index + 1).png"))
    }
  }
  try runArt13(raw: raw, bezels: bezels, out: out)
}

// MARK: - Sizes for Mac frame 2

let macBezelFile13 = "MacBook Air M5 13-inch Sky Blue.png"
/// Real widths: iPhone 18 Pro Max and MacBook Air 13".
let phoneWidthCM13: CGFloat = 7.8
let macWidthCM13: CGFloat = 30.4

/// The device's own width in its bezel picture (the picture has a clear margin).
func bodyWidth13(_ bezel: Bezel) -> CGFloat {
  let width = bezel.image.width, height = bezel.image.height
  guard let data = bezel.mask.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return CGFloat(width) }
  let row = bezel.mask.bytesPerRow
  var minX = width, maxX = 0
  for y in stride(from: 0, to: height, by: 8) {
    for x in 0..<width where bytes[y * row + x] > 0 {
      minX = min(minX, x)
      maxX = max(maxX, x)
    }
  }
  return CGFloat(max(1, maxX - minX + 1))
}

// MARK: - Header and search result (iOS 27 and later; can change without a new version)

/// What 1.3 adds to the pills: pictures and the text in them.
let pills13: [(Words, Color, String)] = [
  (["en": "Paste keyboard", "tr": "Yapıştırma klavyesi"], Brand.code, "keyboard"),
  (["en": "Photos & PDFs", "tr": "Fotoğraf ve PDF"], Brand.address, "photo.on.rectangle"),
  (["en": "Text in pictures", "tr": "Resimdeki yazı"], Brand.link, "text.viewfinder"),
  (["en": "Mac sync", "tr": "Mac'le eşitleme"], Brand.email, "laptopcomputer.and.iphone")
]

/// A whole iPhone, straight, at `height`.
struct Phone13: View {
  let device: CGImage
  let height: CGFloat

  var body: some View {
    Image(decorative: device, scale: 1)
      .resizable()
      .interpolation(.high)
      .frame(width: height * CGFloat(device.width) / CGFloat(device.height), height: height)
  }
}

/// Product page header, 3840 × 1646 (21:9), dark. The message sits in the centered safe area (1646 × 661); two
/// iPhones on each side are decoration that narrow screens may cut.
struct Header13: View {
  let lang: String
  /// Left pair, then right pair.
  let phones: [CGImage]

  var body: some View {
    let height: CGFloat = 1180
    ZStack(alignment: .topLeading) {
      WideBackground(dark: true)
      Phone13(device: phones[0], height: height).position(x: 300, y: 823 + 40)
      Phone13(device: phones[1], height: height).position(x: 860, y: 823 - 40)
      Phone13(device: phones[2], height: height).position(x: 3840 - 860, y: 823 - 40)
      Phone13(device: phones[3], height: height).position(x: 3840 - 300, y: 823 + 40)
      VStack(spacing: 40) {
        PastronautWordmark(size: 128).environment(\.colorScheme, .dark)
        Text(tagline[lang] ?? "")
          .font(.system(size: 88, weight: .heavy))
          .tracking(-1)
          .foregroundStyle(.white)
        FeaturePills(lang: lang, dark: true, size: 30, items: pills13)
      }
      .position(x: 1920, y: 823)
    }
    .frame(width: 3840, height: 1646)
    .clipped()
  }
}

/// Search result picture, 3840 × 2560 (3:2), light. Everything that matters is in the centered safe area
/// (2168 × 1030): what the app is on the left, two iPhones on the right.
struct Search13: View {
  let lang: String
  let phones: [CGImage]

  static let line: Words = ["en": "Clipboard history\n+ paste keyboard", "tr": "Pano geçmişi ve\nyapıştırma klavyesi"]
  static let sub: Words = ["en": "Text, photos, PDFs and files.\niPhone and Mac, in your own iCloud.",
                           "tr": "Metin, fotoğraf, PDF ve dosya.\niPhone ve Mac, kendi iCloud'unda."]

  var body: some View {
    // A margin inside the safe area, so nothing touches its edge.
    let height: CGFloat = 950
    let phoneWidth = height * CGFloat(phones[0].width) / CGFloat(phones[0].height)
    ZStack(alignment: .topLeading) {
      WideBackground(dark: false)
      VStack(alignment: .leading, spacing: 0) {
        PastronautWordmark(size: 88).environment(\.colorScheme, .light)
          .padding(.bottom, 34)
        Text(Self.line[lang] ?? "")
          .font(.system(size: 92, weight: .heavy))
          .tracking(-1.5)
          .foregroundStyle(Brand.ink)
          .fixedSize()
        Text(Self.sub[lang] ?? "")
          .font(.system(size: 44, weight: .medium))
          .foregroundStyle(Brand.muted)
          .padding(.top, 22)
          .fixedSize()
        FeaturePills(lang: lang, size: 34, perRow: 2, items: pills13)
          .padding(.top, 40)
      }
      .frame(width: 1100, alignment: .leading)
      .position(x: 836 + 70 + 550, y: 1280)
      Phone13(device: phones[0], height: height).position(x: 3004 - 50 - phoneWidth * 1.5 - 30, y: 1280)
      Phone13(device: phones[1], height: height).position(x: 3004 - 50 - phoneWidth / 2, y: 1280)
    }
    .frame(width: 3840, height: 2560)
    .clipped()
  }
}

@MainActor
func runArt13(raw: URL, bezels: URL, out: URL) throws {
  let phoneLight = try Bezel(bezels.appending(path: "iPhone 18 Pro Max - Silver - Portrait.png"))
  let phoneDark = try Bezel(bezels.appending(path: "iPhone 18 Pro Max - Black - Portrait.png"))
  for lang in ["en", "tr"] {
    func phone(_ name: String, sheet: Bool = false) throws -> CGImage {
      let path = "\(lang)/s13-\(lang)-\(name).png"
      guard let source = CGImageSourceCreateWithURL(raw.appending(path: path) as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "StoreArt missing \(path)", code: 5)
      }
      let bezel = name.hasSuffix("dark") ? phoneDark : phoneLight
      return bezel.device(showing: sheet ? sheetBandCleaned(image) : image)
    }
    let dir = out.appending(path: lang)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let header = Header13(lang: lang, phones: [
      try phone("04-search-dark"), try phone("02-all-dark"), try phone("07-cards-dark"), try phone("08-queue-dark", sheet: true)
    ])
    try writeOpaque(try render(header, width: 3840, height: 1646), to: dir.appending(path: "header.png"))
    let search = Search13(lang: lang, phones: [try phone("02-all-light"), try phone("06-detail-poster-light")])
    try writeOpaque(try render(search, width: 3840, height: 2560), to: dir.appending(path: "search.png"))
  }
}
