import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// What a history item is, for the colored icons the Mac popup, the iPhone app and the keyboard share. Colors show
/// their own swatch instead of a tint.
public enum ClipKind: String, CaseIterable, Sendable {
  case text, link, code, email, phone, address, color, image, pdf, file

  public var symbolName: String {
    switch self {
    case .text: "text.alignleft"
    case .link: "link"
    case .code: "chevron.left.forwardslash.chevron.right"
    case .email: "envelope"
    case .phone: "phone"
    case .address: "mappin.and.ellipse"
    case .color: "paintpalette"
    case .image: "photo"
    case .pdf: "doc.richtext"
    case .file: "doc"
    }
  }

  /// The kind's color: deeper in light mode, lighter in dark mode, so the symbol keeps its contrast on both.
  public var tint: Color {
    let (light, dark) = Self.palette[self] ?? (0x5E6878, 0xA3ADBB)
    return Color.pastronaut(light: light, dark: dark)
  }

  /// The light-mode color in both modes, for a symbol on a white circle (a selected row).
  public var deepTint: Color {
    let (light, _) = Self.palette[self] ?? (0x5E6878, 0xA3ADBB)
    return Color.pastronaut(light: light, dark: light)
  }

  /// The band along the bottom of a card or keyboard tile: the kind's color, faint (1.3). The label on it uses
  /// `tint`, which keeps at least 4.5:1 on it in both modes.
  public var strip: Color {
    let (light, dark) = Self.palette[self] ?? (0x4F5868, 0xA3ADBB)
    return Color.pastronaut(light: light, dark: dark, lightOpacity: 0.13, darkOpacity: 0.2)
  }

  /// Hex RGB pairs (light, dark). `color` has none: it shows the clip's own color. The light colors are deep
  /// enough for small text on their own `strip`.
  static let palette: [ClipKind: (Int, Int)] = [
    .text: (0x4F5868, 0xA3ADBB),
    .link: (0x1F5BC0, 0x7FB0FF),
    .code: (0x6A40C6, 0xB9A1FF),
    .email: (0x08686F, 0x56D3CC),
    .phone: (0x1F6E33, 0x72D98A),
    .address: (0xA34A0C, 0xFFAA5C),
    .image: (0xA8336F, 0xF28BC4),
    .pdf: (0xA8381F, 0xFF8F7A),
    .file: (0x74581F, 0xD9B872)
  ]
}

public extension Color {
  /// A color that follows light and dark mode, from two hex RGB values, each with its own opacity.
  static func pastronaut(light: Int, dark: Int, lightOpacity: CGFloat = 1, darkOpacity: CGFloat = 1) -> Color {
    func components(_ hex: Int) -> (CGFloat, CGFloat, CGFloat) {
      (CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255)
    }
    let l = components(light), d = components(dark)
    #if canImport(UIKit)
    return Color(UIColor { traits in
      let isDark = traits.userInterfaceStyle == .dark
      let c = isDark ? d : l
      return UIColor(red: c.0, green: c.1, blue: c.2, alpha: isDark ? darkOpacity : lightOpacity)
    })
    #else
    return Color(NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.darkAqua, .aqua, .vibrantDark, .vibrantLight]).map { $0 == .darkAqua || $0 == .vibrantDark } ?? false
      let c = isDark ? d : l
      return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: isDark ? darkOpacity : lightOpacity)
    })
    #endif
  }
}

public extension ClipCollection {
  /// A color of the collection's own, the same on every device: picked from its ID, so nothing is stored or synced.
  var tint: Color {
    let (light, dark) = Self.tints[tintIndex]
    return Color.pastronaut(light: light, dark: dark)
  }

  /// The light-mode color in both modes, for text on a white key.
  var deepTint: Color {
    Color.pastronaut(light: Self.tints[tintIndex].0, dark: Self.tints[tintIndex].0)
  }

  /// First letter of the name, upper-cased the Turkish way ("iş" → "İ").
  var initial: String {
    let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "?"
    return first.uppercased(with: Locale(identifier: "tr_TR"))
  }

  internal var tintIndex: Int {
    let hash = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
    return hash % Self.tints.count
  }

  internal static let tints: [(Int, Int)] = [
    (0xC0570F, 0xFFAA5C), (0x2364D2, 0x7FB0FF), (0x7349D0, 0xB9A1FF), (0x0B7F88, 0x56D3CC),
    (0x2A8540, 0x72D98A), (0xB23A7A, 0xF28BC4), (0x8A6A2E, 0xD9B872), (0x5E6878, 0xA3ADBB)
  ]
}
