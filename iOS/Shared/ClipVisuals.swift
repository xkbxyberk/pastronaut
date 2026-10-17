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
  /// Same symbols and colors as the Mac popup (`ClipKind` in PastronautCore).
  var symbolName: String { kind.symbolName }

  var kindName: LocalizedStringKey {
    switch self {
    case .link: "Link"
    case .email: "Email"
    case .phone: "Phone"
    case .color: "Color"
    case .address: "Address"
    case .code: "Code"
    case .text: "Text"
    }
  }

  var usesMonospacedFont: Bool {
    switch self {
    case .link, .code, .color: true
    case .email, .phone, .address, .text: false
    }
  }
}

extension Clip {
  var content: ClipContent { ClipContent(text) }

  var isFromMac: Bool { sourceDevice == .mac }

  /// For list rows: surrounding blank lines (common when copying from Notes) would waste a preview line.
  var preview: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// The kind's symbol in the kind's color on a soft circle of that color, or a swatch for colors. `glass` makes the
/// circle tinted Liquid Glass on iOS 26 and later (list rows).
struct ClipIcon: View {
  let content: ClipContent
  var size: CGFloat = 32
  var glass = false

  var body: some View {
    Group {
      if glass, #available(iOS 26.0, *) {
        symbol
          .frame(width: size, height: size)
          .glassEffect(.regular.tint(content.kind.tint.opacity(0.22)), in: Circle())
      } else {
        symbol
          .frame(width: size, height: size)
          .background(content.kind.tint.opacity(0.16), in: Circle())
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
        .foregroundStyle(content.kind.tint)
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
