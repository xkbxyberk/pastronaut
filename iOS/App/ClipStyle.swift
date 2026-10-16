import PastronautCore
import SwiftUI
import UIKit

extension Color {
  /// Pins and pin actions (Gece palette).
  static let pin = Color("PinColor")
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

/// Rounded tile with the content type's symbol, or a swatch for colors.
struct ClipIcon: View {
  let content: ClipContent
  var size: CGFloat = 32

  var body: some View {
    RoundedRectangle(cornerRadius: size / 4, style: .continuous)
      .fill(Color.accentColor.opacity(0.14))
      .frame(width: size, height: size)
      .overlay {
        if case .color(let hex) = content, let swatch = Color(hex: hex) {
          RoundedRectangle(cornerRadius: size / 6, style: .continuous)
            .fill(swatch)
            .frame(width: size * 0.56, height: size * 0.56)
        } else {
          Image(systemName: content.symbolName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(Color.accentColor)
        }
      }
      .accessibilityHidden(true)
  }
}

/// "Mac · Safari · 2 min ago": where and when a clip was last copied.
struct ClipSourceLine: View {
  let clip: Clip

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: clip.isFromMac ? "laptopcomputer" : "iphone")
        .accessibilityLabel(clip.isFromMac ? Text(verbatim: "Mac") : Text(verbatim: "iPhone"))
      if let app = clip.sourceAppName {
        Text(verbatim: app)
        Text(verbatim: "·")
      }
      Text(clip.lastCopiedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
    .lineLimit(1)
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

// MARK: - Liquid Glass

extension View {
  /// Liquid Glass on iOS 26 and later, a material before it.
  @ViewBuilder
  func glassBackground<S: Shape>(in shape: S) -> some View {
    if #available(iOS 26.0, *) {
      glassEffect(.regular, in: shape)
    } else {
      background(.regularMaterial, in: shape)
    }
  }

  /// The main action of a screen: prominent glass on iOS 26 and later.
  @ViewBuilder
  func primaryActionStyle() -> some View {
    if #available(iOS 26.0, *) {
      buttonStyle(.glassProminent)
    } else {
      buttonStyle(.borderedProminent)
    }
  }

  /// Secondary actions: glass on iOS 26 and later.
  @ViewBuilder
  func secondaryActionStyle() -> some View {
    if #available(iOS 26.0, *) {
      buttonStyle(.glass)
    } else {
      buttonStyle(.bordered)
    }
  }
}

/// Brief confirmation, e.g. after copying.
struct Toast: View {
  let text: LocalizedStringKey
  var systemImage = "checkmark"

  var body: some View {
    Label(text, systemImage: systemImage)
      .font(.subheadline.weight(.semibold))
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
      .glassBackground(in: Capsule())
      .accessibilityAddTraits(.isStaticText)
  }
}

enum Haptics {
  @MainActor
  static func success() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }
}
