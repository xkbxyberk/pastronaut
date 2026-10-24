import AppKit
import PastronautCore
import SwiftUI

// The iPhone gallery since 1.2: ten frames (App Store Connect's limit), each a whole phone with a clean status bar,
// a large caption and enlarged pieces of the real screen ("callouts"). One orbit line runs through all ten frames,
// so the set reads as one picture when it scrolls by.

let galleryWidth: CGFloat = 1320
let galleryHeight: CGFloat = 2868

/// A part of a screenshot shown larger next to the phone.
struct Callout {
  /// In screenshot pixels (1290 × 2796, status bar included).
  let rect: CGRect
  /// Where the Turkish screen differs (longer texts move things down).
  var rectTR: CGRect? = nil
  /// Width on the frame.
  let width: CGFloat
  /// Center on the frame.
  let center: CGPoint
  var tilt: Double = 0
}

struct GalleryFrame {
  let shot: String
  let caption: Caption
  let dark: Bool
  /// The phone's center x and top on the frame; width of the phone body.
  var phoneX: CGFloat = 660
  var phoneTop: CGFloat = 820
  var phoneWidth: CGFloat = 960
  var phoneTilt: Double = 0
  var callouts: [Callout] = []
}

// MARK: - Pieces

/// The background of the whole gallery: a soft gradient per frame, and one orbit line with a few stars that runs
/// across all frames (drawn in gallery coordinates, then shifted to this frame).
struct GalleryBackground: View {
  let index: Int
  let dark: Bool
  var frameCount = 10

  var body: some View {
    let offset = CGFloat(index) * galleryWidth
    ZStack {
      LinearGradient(colors: dark ? [Brand.navyTop, Brand.navyBottom] : [Brand.mistTop, Brand.mistBottom],
                     startPoint: .top, endPoint: .bottom)
      // A wide glow behind the phone.
      RadialGradient(colors: [(dark ? Brand.deepSky : Brand.sky).opacity(dark ? 0.35 : 0.45), .clear],
                     center: UnitPoint(x: 0.5, y: 0.62), startRadius: 40, endRadius: 980)
      Canvas { context, size in
        let total = galleryWidth * CGFloat(frameCount)
        var orbit = Path()
        let steps = 400
        for step in 0...steps {
          let x = total * CGFloat(step) / CGFloat(steps)
          // A slow wave between the caption and the phone.
          let y = 1520 + 330 * sin(x / total * .pi * 2 * 2.5 + 0.6) + 120 * sin(x / 900)
          let point = CGPoint(x: x - offset, y: y)
          step == 0 ? orbit.move(to: point) : orbit.addLine(to: point)
        }
        let line = (dark ? Brand.sky : Brand.deepSky).opacity(dark ? 0.32 : 0.22)
        context.stroke(orbit, with: .color(line), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        // Stars: fixed positions across the gallery.
        var seed: UInt64 = 0x5A5A_1234
        func random() -> CGFloat {
          seed = seed &* 6364136223846793005 &+ 1442695040888963407
          return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
        }
        for _ in 0..<160 {
          let x = random() * total - offset
          let y = random() * size.height
          let r = 2 + random() * 5
          guard x > -20, x < size.width + 20 else { continue }
          let star = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
          context.fill(star, with: .color((dark ? Color.white : Brand.deepSky).opacity(0.10 + random() * 0.25)))
        }
        // A small moon riding the orbit in every frame.
        let mx = total * (CGFloat(index) + 0.86) / CGFloat(frameCount)
        let my = 1520 + 330 * sin(mx / total * .pi * 2 * 2.5 + 0.6) + 120 * sin(mx / 900)
        context.fill(Path(ellipseIn: CGRect(x: mx - offset - 22, y: my - 22, width: 44, height: 44)),
                     with: .color(Color(red: 0.949, green: 0.647, blue: 0.255)))
      }
    }
  }
}

struct GalleryCaption: View {
  let caption: Caption
  let lang: String
  let dark: Bool

  var body: some View {
    VStack(spacing: 0) {
      Text(caption.eyebrow[lang] ?? "")
        .font(.system(size: 38, weight: .heavy))
        .tracking(5)
        .foregroundStyle(dark ? Brand.navyTop : .white)
        .padding(.horizontal, 30)
        .padding(.vertical, 12)
        .background(dark ? Brand.sky : caption.color, in: Capsule())
        .padding(.bottom, 34)
      Text(caption.title[lang] ?? "")
        .font(.system(size: 118, weight: .heavy))
        .tracking(-1.5)
        .lineSpacing(0)
        .foregroundStyle(dark ? Color.white : Brand.ink)
        .fixedSize(horizontal: false, vertical: true)
        .minimumScaleFactor(0.8)
      Text(caption.subtitle[lang] ?? "")
        .font(.system(size: 50, weight: .medium))
        .foregroundStyle(dark ? Brand.sky.opacity(0.92) : Brand.muted)
        .padding(.top, 28)
        .fixedSize(horizontal: false, vertical: true)
    }
    .multilineTextAlignment(.center)
    .frame(width: 1200)
  }
}

/// A phone body drawn from simple shapes (not a picture of a real device), with the screenshot inside and a clean
/// status bar in place of the real one.
struct PhoneBody: View {
  let screen: NSImage
  let width: CGFloat
  let dark: Bool

  var body: some View {
    let bezel = width * 0.034
    let screenWidth = width - bezel * 2
    let screenHeight = screenWidth * screen.size.height / screen.size.width
    let height = screenHeight + bezel * 2
    let scale = screenWidth / screen.size.width
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: width * 0.155, style: .continuous)
        .fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.06), Color(white: 0.16)],
                             startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(RoundedRectangle(cornerRadius: width * 0.155, style: .continuous)
          .strokeBorder(Color(white: 0.42), lineWidth: width * 0.006))
      ZStack(alignment: .top) {
        Image(nsImage: screen)
          .resizable()
          .interpolation(.high)
        // The real status bar (time, battery, Focus) gives way to a plain one.
        Rectangle()
          .fill(statusBarColor)
          .frame(height: 162 * scale)
        HStack {
          Text(verbatim: "9:41")
            .font(.system(size: 50 * scale * 1.0, weight: .semibold))
            .padding(.leading, 150 * scale)
          Spacer()
          HStack(spacing: 18 * scale) {
            Image(systemName: "cellularbars")
            Image(systemName: "wifi")
            Image(systemName: "battery.100")
          }
          .font(.system(size: 44 * scale, weight: .semibold))
          .padding(.trailing, 100 * scale)
        }
        .foregroundStyle(statusBarInk)
        .frame(height: 162 * scale)
        .padding(.top, 8 * scale)
        Capsule()
          .fill(.black)
          .frame(width: 375 * scale, height: 112 * scale)
          .padding(.top, 34 * scale)
      }
      .frame(width: screenWidth, height: screenHeight)
      .clipShape(RoundedRectangle(cornerRadius: width * 0.125, style: .continuous))
      .padding(.top, bezel)
    }
    .frame(width: width, height: height)
    .shadow(color: .black.opacity(dark ? 0.6 : 0.28), radius: width / 16, y: width / 30)
  }

  private var statusBarColor: Color {
    Color(nsColor: screen.color(atX: 40, y: 200) ?? (dark ? .black : .white))
  }

  private var statusBarInk: Color {
    let base = screen.color(atX: 40, y: 200)?.usingColorSpace(.sRGB)
    let luminance = (base?.redComponent ?? 1) * 0.3 + (base?.greenComponent ?? 1) * 0.59 + (base?.blueComponent ?? 1) * 0.11
    return luminance < 0.5 ? .white : .black
  }
}

struct CalloutView: View {
  let image: NSImage
  let callout: Callout
  let dark: Bool
  let lang: String

  var body: some View {
    let rect = lang == "tr" ? callout.rectTR ?? callout.rect : callout.rect
    let part = image.cropped(to: rect)
    let height = callout.width * rect.height / rect.width
    Image(nsImage: part)
      .resizable()
      .interpolation(.high)
      .frame(width: callout.width, height: height)
      .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous)
        .strokeBorder(Color.white.opacity(dark ? 0.25 : 0.9), lineWidth: 6))
      .shadow(color: .black.opacity(dark ? 0.55 : 0.25), radius: 40, y: 22)
      .rotationEffect(.degrees(callout.tilt))
      .position(callout.center)
  }
}

struct GalleryFrameView: View {
  let index: Int
  let frame: GalleryFrame
  let lang: String
  let screen: NSImage

  var body: some View {
    ZStack(alignment: .topLeading) {
      GalleryBackground(index: index, dark: frame.dark)
      GalleryCaption(caption: frame.caption, lang: lang, dark: frame.dark)
        .position(x: galleryWidth / 2, y: 430)
      let phone = PhoneBody(screen: screen, width: frame.phoneWidth, dark: frame.dark)
      phone
        .rotationEffect(.degrees(frame.phoneTilt))
        .position(x: frame.phoneX, y: frame.phoneTop + phoneHeight / 2)
      ForEach(Array(frame.callouts.enumerated()), id: \.offset) { _, callout in
        CalloutView(image: screen, callout: callout, dark: frame.dark, lang: lang)
      }
    }
    .frame(width: galleryWidth, height: galleryHeight)
    .clipped()
  }

  private var phoneHeight: CGFloat {
    let bezel = frame.phoneWidth * 0.034
    let screenWidth = frame.phoneWidth - bezel * 2
    return screenWidth * screen.size.height / screen.size.width + bezel * 2
  }
}

/// Frames 1 and 2 as one picture: the phone in front, the Mac window behind it crossing the seam.
struct GalleryPanorama: View {
  let lang: String
  let phone: NSImage
  let mac: NSImage
  let macPhone: NSImage

  static let first = Caption(
    eyebrow: ["en": "PASTRONAUT", "tr": "PASTRONAUT"],
    title: ["en": "Your clipboard,\non iPhone and Mac", "tr": "Panon, iPhone'da\nve Mac'te"],
    subtitle: ["en": "Every copy, one tap away in any app.", "tr": "Her kopya, her uygulamada bir dokunuş uzağında."],
    color: Brand.link)
  static let second = Caption(
    eyebrow: ["en": "SYNC", "tr": "EŞİTLE"],
    title: ["en": "Copy on your Mac,\npaste on your iPhone", "tr": "Mac'te kopyala,\niPhone'da yapıştır"],
    subtitle: ["en": "Through your own private iCloud.", "tr": "Kendi özel iCloud'un üzerinden."],
    color: Brand.email)

  var body: some View {
    ZStack(alignment: .topLeading) {
      HStack(spacing: 0) {
        GalleryBackground(index: 0, dark: false).frame(width: galleryWidth)
        GalleryBackground(index: 1, dark: false).frame(width: galleryWidth)
      }
      GalleryCaption(caption: Self.first, lang: lang, dark: false)
        .position(x: galleryWidth / 2, y: 430)
      GalleryCaption(caption: Self.second, lang: lang, dark: false)
        .position(x: galleryWidth * 1.5, y: 430)
      // The Mac popup as a window across the seam.
      Shot(image: mac, width: 1560, radius: 46)
        .position(x: 1560, y: 1640)
      PhoneBody(screen: phone, width: 900, dark: false)
        .position(x: 640, y: 1840)
      PhoneBody(screen: macPhone, width: 720, dark: true)
        .rotationEffect(.degrees(4))
        .position(x: 2240, y: 2050)
    }
    .frame(width: galleryWidth * 2, height: galleryHeight)
    .clipped()
  }
}

// MARK: - Image helpers

extension NSImage {
  /// The color of one pixel (x, y from the top left, in image pixels).
  func color(atX x: Int, y: Int) -> NSColor? {
    guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let rep = NSBitmapImageRep(cgImage: cg)
    return rep.colorAt(x: x, y: y)
  }

  func cropped(to rect: CGRect) -> NSImage {
    guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil), let part = cg.cropping(to: rect) else {
      return self
    }
    return NSImage(cgImage: part, size: NSSize(width: part.width, height: part.height))
  }
}

// MARK: - The ten frames (1 and 2 are the panorama)

/// Shots from SyncStepTests `storeShots12`, in `<raw>/<lang>/12-…png`.
let galleryFrames: [GalleryFrame] = [
  GalleryFrame(shot: "12-04-keyboard-light", caption: Caption(
    eyebrow: ["en": "PASTE", "tr": "YAPIŞTIR"],
    title: ["en": "Paste anything,\nin any app", "tr": "Her kopya,\nher uygulamada"],
    subtitle: ["en": "Your history as a keyboard. Tap to type.", "tr": "Geçmişin klavyende. Dokun, yazsın."],
    color: Brand.code), dark: false,
    callouts: [
      Callout(rect: CGRect(x: 24, y: 1625, width: 1242, height: 420), width: 1200, center: CGPoint(x: 660, y: 1930), tilt: -2)
    ]),
  GalleryFrame(shot: "12-09-queue-dark", caption: Caption(
    eyebrow: ["en": "QUEUE", "tr": "SIRA"],
    title: ["en": "Paste a list,\nin order", "tr": "Bir listeyi\nsırayla yapıştır"],
    subtitle: ["en": "Select clips, then each tap types the next.", "tr": "Öğeleri seç; her dokunuş sıradakini yazar."],
    color: Brand.address), dark: true,
    callouts: [
      Callout(rect: CGRect(x: 20, y: 1625, width: 1250, height: 170), width: 1220, center: CGPoint(x: 660, y: 1880), tilt: -2)
    ]),
  GalleryFrame(shot: "12-02-cards-dark", caption: Caption(
    eyebrow: ["en": "SMART CARDS", "tr": "AKILLI KARTLAR"],
    title: ["en": "Every kind,\nits own card", "tr": "Her türe\nkendi kartı"],
    subtitle: ["en": "Maps, page previews, colored code, titles.", "tr": "Harita, sayfa önizlemesi, renkli kod, başlık."],
    color: Brand.phone), dark: true,
    callouts: [
      Callout(rect: CGRect(x: 655, y: 1180, width: 600, height: 470), width: 600, center: CGPoint(x: 1010, y: 1640), tilt: 4),
      Callout(rect: CGRect(x: 35, y: 1670, width: 600, height: 450), width: 600, center: CGPoint(x: 320, y: 2230), tilt: -4)
    ]),
  GalleryFrame(shot: "12-05-scan-menu-light", caption: Caption(
    eyebrow: ["en": "SCAN", "tr": "TARA"],
    title: ["en": "Scan text with\nyour camera", "tr": "Kamerayla\nmetin tara"],
    subtitle: ["en": "Touch and hold +. Read right on your iPhone.", "tr": "+'ya basılı tut. Metin iPhone'unda okunur."],
    color: Brand.link), dark: false,
    callouts: [
      Callout(rect: CGRect(x: 540, y: 2428, width: 660, height: 236), width: 860, center: CGPoint(x: 780, y: 2330), tilt: -3)
    ]),
  GalleryFrame(shot: "12-06-clip-menu-light", caption: Caption(
    eyebrow: ["en": "TITLES", "tr": "BAŞLIKLAR"],
    title: ["en": "Name it, edit it,\nfind it again", "tr": "Adını koy,\ndüzenle, bul"],
    subtitle: ["en": "Add a title, edit text, show it in history.", "tr": "Başlık ekle, metni düzenle, geçmişte göster."],
    color: Brand.address), dark: false,
    callouts: [
      Callout(rect: CGRect(x: 480, y: 1600, width: 760, height: 620), width: 820, center: CGPoint(x: 880, y: 2000), tilt: 3)
    ]),
  GalleryFrame(shot: "12-10-search-dark", caption: Caption(
    eyebrow: ["en": "FIND", "tr": "BUL"],
    title: ["en": "Find any copy\nin seconds", "tr": "Aradığını\nsaniyede bul"],
    subtitle: ["en": "Search by text, title, kind or date.", "tr": "Metne, başlığa, türe ya da tarihe göre ara."],
    color: Brand.email), dark: true,
    callouts: [
      Callout(rect: CGRect(x: 20, y: 220, width: 760, height: 1190), width: 640, center: CGPoint(x: 990, y: 1640), tilt: 3)
    ]),
  GalleryFrame(shot: "12-08-select-more-light", caption: Caption(
    eyebrow: ["en": "ORGANIZE", "tr": "DÜZENLE"],
    title: ["en": "Collect, combine,\nexport", "tr": "Topla, birleştir,\ndışa aktar"],
    subtitle: ["en": "Pins, collections, many clips joined into one.", "tr": "Sabitle, koleksiyonla, öğeleri tek metinde birleştir."],
    color: Brand.code), dark: false,
    callouts: [
      Callout(rect: CGRect(x: 35, y: 1705, width: 600, height: 470), width: 540, center: CGPoint(x: 1040, y: 1620), tilt: 4),
      Callout(rect: CGRect(x: 90, y: 2400, width: 740, height: 300), width: 900, center: CGPoint(x: 580, y: 2380), tilt: -3)
    ]),
  GalleryFrame(shot: "12-14-settings-privacy-light", caption: Caption(
    eyebrow: ["en": "PRIVATE", "tr": "GİZLİ"],
    title: ["en": "No account.\nNo tracking.", "tr": "Hesap yok.\nİzleme yok."],
    subtitle: ["en": "Face ID lock, hidden while recording, your iCloud.", "tr": "Face ID kilidi, kayıtta gizlenir, kendi iCloud'un."],
    color: Brand.text), dark: false,
    callouts: [
      Callout(rect: CGRect(x: 60, y: 1900, width: 1220, height: 720), rectTR: CGRect(x: 60, y: 1975, width: 1220, height: 770), width: 1180, center: CGPoint(x: 660, y: 2240))
    ]),
]

// MARK: - Header (3840 × 1646) and search result (3840 × 2560), same craft as the gallery

/// Gradient, glow, one orbit line and stars, for the wide pictures.
struct WideBackground: View {
  let dark: Bool

  var body: some View {
    ZStack {
      LinearGradient(colors: dark ? [Brand.navyTop, Brand.navyBottom] : [Brand.mistTop, Brand.mistBottom],
                     startPoint: .top, endPoint: .bottom)
      RadialGradient(colors: [(dark ? Brand.deepSky : Brand.sky).opacity(dark ? 0.40 : 0.50), .clear],
                     center: .center, startRadius: 60, endRadius: 1700)
      Canvas { context, size in
        var orbit = Path()
        for step in 0...300 {
          let x = size.width * CGFloat(step) / 300
          let y = size.height * 0.56 + size.height * 0.20 * sin(x / size.width * .pi * 2 + 0.9)
          step == 0 ? orbit.move(to: CGPoint(x: x, y: y)) : orbit.addLine(to: CGPoint(x: x, y: y))
        }
        context.stroke(orbit, with: .color((dark ? Brand.sky : Brand.deepSky).opacity(dark ? 0.30 : 0.20)),
                       style: StrokeStyle(lineWidth: 8, lineCap: .round))
        var seed: UInt64 = 0x1234_5A5A
        func random() -> CGFloat {
          seed = seed &* 6364136223846793005 &+ 1442695040888963407
          return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
        }
        for _ in 0..<90 {
          let r = 2 + random() * 5
          let rect = CGRect(x: random() * size.width - r, y: random() * size.height - r, width: r * 2, height: r * 2)
          context.fill(Path(ellipseIn: rect), with: .color((dark ? Color.white : Brand.deepSky).opacity(0.10 + random() * 0.25)))
        }
      }
    }
  }
}

/// A row of colored pills naming what the app does.
struct FeaturePills: View {
  let lang: String
  var dark = false
  var size: CGFloat = 44
  /// Pills per row.
  var perRow = 4
  var items = Self.items

  static let items: [(Words, Color, String)] = [
    (["en": "Paste keyboard", "tr": "Yapıştırma klavyesi"], Brand.code, "keyboard"),
    (["en": "Smart cards", "tr": "Akıllı kartlar"], Brand.phone, "rectangle.grid.2x2"),
    (["en": "Scan text", "tr": "Metin tarama"], Brand.link, "text.viewfinder"),
    (["en": "Mac sync", "tr": "Mac'le eşitleme"], Brand.email, "laptopcomputer.and.iphone")
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: size * 0.4) {
      ForEach(Array(stride(from: 0, to: items.count, by: perRow)), id: \.self) { start in
        HStack(spacing: size * 0.4) {
          ForEach(Array(items[start..<min(start + perRow, items.count)].enumerated()), id: \.offset) { _, item in
            pill(item)
          }
        }
      }
    }
    .fixedSize()
  }

  private func pill(_ item: (Words, Color, String)) -> some View {
        Label {
          Text(item.0[lang] ?? "")
        } icon: {
          Image(systemName: item.2)
        }
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, size * 0.6)
        .padding(.vertical, size * 0.34)
        .background(item.1, in: Capsule())
  }
}

/// Product page header: the message in the centered safe area (1646 × 661), real screens at the sides.
struct HeaderArt2: View {
  let lang: String
  let mac: NSImage
  let cards: NSImage
  let queue: NSImage

  var body: some View {
    ZStack(alignment: .topLeading) {
      WideBackground(dark: true)
      Shot(image: mac, width: 1000, radius: 36, dark: true)
        .rotationEffect(.degrees(-7))
        .position(x: 560, y: 900)
      PhoneBody(screen: queue, width: 620, dark: true)
        .rotationEffect(.degrees(-4))
        .position(x: 3000, y: 1180)
      PhoneBody(screen: cards, width: 660, dark: true)
        .rotationEffect(.degrees(7))
        .position(x: 3500, y: 960)
      VStack(spacing: 40) {
        PastronautWordmark(size: 128).environment(\.colorScheme, .dark)
        Text(tagline[lang] ?? "")
          .font(.system(size: 88, weight: .heavy))
          .tracking(-1)
          .foregroundStyle(.white)
        FeaturePills(lang: lang, dark: true, size: 34)
      }
      .position(x: 1920, y: 823)
    }
    .frame(width: 3840, height: 1646)
    .clipped()
  }
}

/// Search result picture: "state the obvious" inside the centered safe area (2168 × 1030): what it is on the
/// left, the app on the right; the Mac window behind may be cropped.
struct SearchArt2: View {
  let lang: String
  let cards: NSImage
  let keyboard: NSImage
  let mac: NSImage

  static let line: Words = ["en": "Clipboard history\n+ paste keyboard", "tr": "Pano geçmişi ve\nyapıştırma klavyesi"]
  static let sub: Words = ["en": "for iPhone and Mac, synced in your iCloud",
                           "tr": "iPhone ve Mac için, iCloud'unda eşitlenir"]

  var body: some View {
    ZStack(alignment: .topLeading) {
      WideBackground(dark: false)
      Shot(image: mac, width: 1250, radius: 40)
        .rotationEffect(.degrees(-4))
        .opacity(0.9)
        .position(x: 3260, y: 1180)
      VStack(alignment: .leading, spacing: 0) {
        PastronautWordmark(size: 104).environment(\.colorScheme, .light)
          .padding(.bottom, 44)
        Text(Self.line[lang] ?? "")
          .font(.system(size: 108, weight: .heavy))
          .tracking(-1.5)
          .foregroundStyle(Brand.ink)
          .fixedSize()
        Text(Self.sub[lang] ?? "")
          .font(.system(size: 54, weight: .medium))
          .foregroundStyle(Brand.muted)
          .padding(.top, 26)
          .fixedSize()
        FeaturePills(lang: lang, size: 40, perRow: 2)
          .padding(.top, 54)
      }
      .frame(width: 1180, alignment: .leading)
      .position(x: 900 + 590, y: 1280)
      PhoneBody(screen: cards, width: 450, dark: false)
        .rotationEffect(.degrees(-3))
        .position(x: 2350, y: 1280)
      PhoneBody(screen: keyboard, width: 450, dark: false)
        .rotationEffect(.degrees(4))
        .position(x: 2735, y: 1285)
    }
    .frame(width: 3840, height: 2560)
    .clipped()
  }
}
