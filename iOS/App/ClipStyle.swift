import PastronautCore
import SwiftUI
import UIKit

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
