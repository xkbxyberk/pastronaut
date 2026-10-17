import CoreText
import Foundation

// Turns "Pastr" and "naut" (Unbounded, weight 700) into outlines and places the helmet "o" between them, with the
// measurements of design 1a. Units: 1 em = 100. y grows downwards, baseline at y = 0.
// usage: swift wordmark.swift Unbounded.ttf out-dir

let args = CommandLine.arguments
let fontURL = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])

guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
      let base = descriptors.first else { fatalError("font not readable") }
let wghtTag = 0x77676874 // 'wght'
let attributes: [CFString: Any] = [kCTFontVariationAttribute: [wghtTag: 700]]
let descriptor = CTFontDescriptorCreateCopyWithAttributes(base, attributes as CFDictionary)
let font = CTFontCreateWithFontDescriptor(descriptor, 100, nil)

let tracking: CGFloat = -1 // letter-spacing -0.01em

struct Outline {
  var commands: [String] = []
  var minX = CGFloat.infinity, maxX = -CGFloat.infinity, minY = CGFloat.infinity, maxY = -CGFloat.infinity

  mutating func note(_ p: CGPoint) {
    minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y)
  }

  static func f(_ v: CGFloat) -> String {
    let r = (v * 100).rounded() / 100
    return r == r.rounded() ? String(Int(r)) : String(format: "%.2f", r)
  }

  mutating func append(_ path: CGPath, dx: CGFloat) {
    // Font paths have y up; flip to y down around the baseline.
    func t(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + dx, y: -p.y) }
    path.applyWithBlock { element in
      let e = element.pointee
      switch e.type {
      case .moveToPoint:
        let p = t(e.points[0]); note(p); commands.append("M\(Outline.f(p.x)) \(Outline.f(p.y))")
      case .addLineToPoint:
        let p = t(e.points[0]); note(p); commands.append("L\(Outline.f(p.x)) \(Outline.f(p.y))")
      case .addQuadCurveToPoint:
        let c = t(e.points[0]), p = t(e.points[1]); note(c); note(p)
        commands.append("Q\(Outline.f(c.x)) \(Outline.f(c.y)) \(Outline.f(p.x)) \(Outline.f(p.y))")
      case .addCurveToPoint:
        let c1 = t(e.points[0]), c2 = t(e.points[1]), p = t(e.points[2]); note(c1); note(c2); note(p)
        commands.append("C\(Outline.f(c1.x)) \(Outline.f(c1.y)) \(Outline.f(c2.x)) \(Outline.f(c2.y)) \(Outline.f(p.x)) \(Outline.f(p.y))")
      case .closeSubpath:
        commands.append("Z")
      @unknown default:
        break
      }
    }
  }
}

/// Appends the outlines of `text` starting at `x`; returns the pen position after the last letter (tracking included).
func draw(_ text: String, at x: CGFloat, into outline: inout Outline) -> CGFloat {
  let characters = Array(text.utf16)
  var glyphs = [CGGlyph](repeating: 0, count: characters.count)
  guard CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count) else { fatalError("missing glyphs") }
  var advances = [CGSize](repeating: .zero, count: glyphs.count)
  CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
  var pen = x
  for (glyph, advance) in zip(glyphs, advances) {
    if let path = CTFontCreatePathForGlyph(font, glyph, nil) {
      outline.append(path, dx: pen)
    }
    pen += advance.width + tracking
  }
  return pen
}

var outline = Outline()
let afterPastr = draw("Pastr", at: 0, into: &outline)
// The helmet box: 0.07em margin, 0.64em wide, 0.07em margin (design 1a), bottom on the baseline, 0.6em tall.
let boxX = afterPastr + 7
let helmetCenter = CGPoint(x: boxX + 32, y: -30)
let afterNaut = draw("naut", at: boxX + 64 + 7, into: &outline)
_ = afterNaut

// Helmet artwork from the app icon (100-unit box, centre 50,44), scaled so the helmet (r 27) is 0.6em wide.
let unit: CGFloat = 0.6 * 100 / 54
func helmetPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
  CGPoint(x: helmetCenter.x + (x - 50) * unit, y: helmetCenter.y + (y - 44) * unit)
}
// The orbit reaches furthest; include it in the bounds.
for p in [helmetPoint(9.63, 57.58), helmetPoint(90.37, 34.42), helmetPoint(88.6, 30.0)] { outline.note(p) }

let width = outline.maxX
let top = outline.minY
let bottom = outline.maxY
let textPath = outline.commands.joined(separator: " ")

let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font), xHeight = CTFontGetXHeight(font)
let json: [String: Any] = [
  "textPath": textPath,
  "helmetCenter": [helmetCenter.x, helmetCenter.y],
  "unit": unit,
  "minX": outline.minX, "width": width, "top": top, "bottom": bottom,
  "fontAscent": ascent, "fontDescent": descent, "xHeight": xHeight
]
let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
try data.write(to: outDir.appending(path: "wordmark.json"))

// SVG previews (light and dark), the same drawing the app does.
func svg(dark: Bool) -> String {
  let ink = dark ? "#F7FBFD" : "#0E2236"
  let sky = dark ? "#87CEEB" : "#1E6FA8"
  let amber = dark ? "#F2A541" : "#E8992A"
  let visor = dark ? "#0B1A29" : "#0E2236"
  let stroke = dark ? "" : " stroke=\"#0E2236\" stroke-width=\"4\""
  let pad: CGFloat = 4
  let vbX = outline.minX - pad, vbY = top - pad, vbW = width - outline.minX + 2 * pad, vbH = bottom - top + 2 * pad
  let s = unit
  let tx = helmetCenter.x - 50 * s, ty = helmetCenter.y - 44 * s
  return """
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="\(Outline.f(vbX)) \(Outline.f(vbY)) \(Outline.f(vbW)) \(Outline.f(vbH))">
    <title>Pastronaut</title>
    <path d="\(textPath)" fill="\(ink)"/>
    <g transform="translate(\(Outline.f(tx)) \(Outline.f(ty))) scale(\(String(format: "%.5f", s)))">
      <path d="M9.63 57.58 A42 11 -16 0 1 90.37 34.42" fill="none" stroke="\(sky)" stroke-width="6" stroke-linecap="round" opacity="0.7"/>
      <rect x="17.5" y="36" width="8" height="17" rx="4" fill="\(sky)"/>
      <rect x="74.5" y="36" width="8" height="17" rx="4" fill="\(sky)"/>
      <circle cx="50" cy="44" r="27" fill="#F7FBFD"\(stroke)/>
      <rect x="30" y="30.5" width="40" height="28" rx="13.5" fill="\(visor)"/>
      <path d="M34 40 Q38 34 47 33.5" fill="none" stroke="#87CEEB" stroke-width="2.4" stroke-linecap="round"/>
      <rect x="43.5" y="36" width="13" height="18" rx="2.4" fill="\(amber)"/>
      <rect x="46.6" y="34" width="6.8" height="4.2" rx="1.4" fill="#F7FBFD"/>
      <path d="M9.63 57.58 A42 11 -16 0 0 90.37 34.42" fill="none" stroke="\(sky)" stroke-width="6" stroke-linecap="round"/>
      <circle cx="88.6" cy="35.4" r="6.5" fill="\(amber)"/>
    </g>
  </svg>

  """
}
try svg(dark: false).write(to: outDir.appending(path: "pastronaut-wordmark-light.svg"), atomically: true, encoding: .utf8)
try svg(dark: true).write(to: outDir.appending(path: "pastronaut-wordmark-dark.svg"), atomically: true, encoding: .utf8)
print("commands \(outline.commands.count) width \(width) top \(top) bottom \(bottom) xHeight \(xHeight) helmet \(helmetCenter)")
