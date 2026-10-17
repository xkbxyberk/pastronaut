import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// What a history item is, for the colored icons the Mac popup, the iPhone app and the keyboard share. Images and
/// files exist only on the Mac; colors show their own swatch instead of a tint.
public enum ClipKind: String, CaseIterable, Sendable {
  case text, link, code, email, phone, address, color, image, file

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

  /// Hex RGB pairs (light, dark). `color` has none: it shows the clip's own color.
  static let palette: [ClipKind: (Int, Int)] = [
    .text: (0x5E6878, 0xA3ADBB),
    .link: (0x2364D2, 0x7FB0FF),
    .code: (0x7349D0, 0xB9A1FF),
    .email: (0x0B7F88, 0x56D3CC),
    .phone: (0x2A8540, 0x72D98A),
    .address: (0xC0570F, 0xFFAA5C),
    .image: (0xB23A7A, 0xF28BC4),
    .file: (0x8A6A2E, 0xD9B872)
  ]
}

public extension Color {
  /// A color that follows light and dark mode, from two hex RGB values.
  static func pastronaut(light: Int, dark: Int) -> Color {
    func components(_ hex: Int) -> (CGFloat, CGFloat, CGFloat) {
      (CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255)
    }
    let l = components(light), d = components(dark)
    #if canImport(UIKit)
    return Color(UIColor { traits in
      let c = traits.userInterfaceStyle == .dark ? d : l
      return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    })
    #else
    return Color(NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.darkAqua, .aqua, .vibrantDark, .vibrantLight]).map { $0 == .darkAqua || $0 == .vibrantDark } ?? false
      let c = isDark ? d : l
      return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
    })
    #endif
  }
}
