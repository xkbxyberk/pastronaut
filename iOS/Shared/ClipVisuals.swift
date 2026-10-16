import PastronautCore
import SwiftUI

// Shared by the app and the keyboard extension (both targets compile this file).

extension Color {
  /// Pins and pin actions (Gece palette).
  static let pin = Color("PinColor")
  /// Text and symbols on an accent fill: white in light mode, night blue on the dark-mode sky blue.
  static let onAccent = Color("AccentForeground")
}

extension ClipContent {
  var symbolName: String {
    switch self {
    case .link: "link"
    case .email: "envelope"
    case .phone: "phone"
    case .color: "paintpalette"
    case .code: "chevron.left.forwardslash.chevron.right"
    case .text: "text.alignleft"
    }
  }

  var kindName: LocalizedStringKey {
    switch self {
    case .link: "Link"
    case .email: "Email"
    case .phone: "Phone"
    case .color: "Color"
    case .code: "Code"
    case .text: "Text"
    }
  }

  var usesMonospacedFont: Bool {
    switch self {
    case .link, .code, .color: true
    case .email, .phone, .text: false
    }
  }
}

extension Clip {
  var content: ClipContent { ClipContent(text) }

  var isFromMac: Bool { sourceDevice == .mac }

  /// For list rows: surrounding blank lines (common when copying from Notes) would waste a preview line.
  var preview: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// The content type's symbol, or a swatch for colors. `glass` puts it in a tinted Liquid Glass circle on
/// iOS 26 and later (list rows); otherwise a soft rounded tile (keyboard keys, older systems).
struct ClipIcon: View {
  let content: ClipContent
  var size: CGFloat = 32
  var glass = false

  var body: some View {
    Group {
      if glass, #available(iOS 26.0, *) {
        symbol
          .frame(width: size, height: size)
          .glassEffect(.regular.tint(Color.accentColor.opacity(0.28)), in: Circle())
      } else {
        symbol
          .frame(width: size, height: size)
          .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: size / 4, style: .continuous))
      }
    }
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private var symbol: some View {
    if case .color(let hex) = content, let swatch = Color(hex: hex) {
      Circle()
        .fill(swatch)
        .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
        .frame(width: size * 0.56, height: size * 0.56)
    } else {
      Image(systemName: content.symbolName)
        .font(.system(size: size * 0.42, weight: .semibold))
        .foregroundStyle(Color.accentColor)
    }
  }
}

extension Color {
  /// `#RGB`, `#RRGGBB` or `#RRGGBBAA`.
  init?(hex: String) {
    var digits = hex.dropFirst().map(String.init)
    if digits.count == 3 { digits = digits.flatMap { [$0, $0] } }
    guard digits.count == 6 || digits.count == 8, let value = UInt64(digits.joined(), radix: 16) else { return nil }
    let hasAlpha = digits.count == 8
    let shifted = hasAlpha ? value : value << 8 | 0xFF
    self.init(
      .sRGB,
      red: Double((shifted >> 24) & 0xFF) / 255,
      green: Double((shifted >> 16) & 0xFF) / 255,
      blue: Double((shifted >> 8) & 0xFF) / 255,
      opacity: Double(shifted & 0xFF) / 255
    )
  }
}
