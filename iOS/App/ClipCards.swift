import PastronautCore
import SwiftUI
import UIKit

// The history as cards (previews on): two columns of tiles that are all the same size, so rows line up. Each kind
// fills the tile's top with its own content (page image, map, code, color, text); what it is, when it was copied
// and where it came from sit along the bottom. With previews off the history is a list (HistoryView.row).

/// Two equal columns of equal tiles.
struct CardGrid<Card: View>: View {
  let clips: [Clip]
  @ViewBuilder let card: (Clip) -> Card

  var body: some View {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
      ForEach(clips, id: \.id, content: card)
    }
  }
}

struct ClipCard: View {
  let clip: Clip
  var isEditing = false
  var isSelected = false
  /// Briefly outlined after "Show in History".
  var isHighlighted = false
  var isLocalOnly = false
  let onTap: () -> Void
  @Environment(\.openURL) private var openURL
  /// Every tile has this height; it grows with Dynamic Type so text still fits.
  @ScaledMetric(relativeTo: .body) private var height: CGFloat = 176

  private var content: ClipContent { clip.content }
  private var preview: PreviewStore.Preview? { PreviewStore.shared.preview(for: clip) }
  private var action: CardAction? { isEditing ? nil : CardAction(content) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: onTap) {
        VStack(alignment: .leading, spacing: 0) {
          media
          main
            // Room for the selection circle in the corner.
            .padding(.trailing, isEditing ? 26 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      if let action {
        Button {
          openURL(action.url)
        } label: {
          Label(action.title, systemImage: action.systemImage)
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .foregroundStyle(.white)
            .background(content.kind.deepTint, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
      }
      footer
        .padding(.horizontal, 12)
        .frame(height: 30)
    }
    .frame(height: height)
    .foregroundStyle(foreground)
    .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay {
      if isEditing || isHighlighted {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(isSelected || isHighlighted ? Color.accentColor : Color.clear, lineWidth: 3)
      }
    }
    .overlay(alignment: .topTrailing) {
      if isEditing {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
          .background(Circle().fill(.background).padding(2))
          .padding(10)
      }
    }
    .task(id: clip.id) { await PreviewStore.shared.load(clip) }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    // The card is one element for VoiceOver, so its Call / Write Email / Get Directions button is an action on it.
    .accessibilityActions {
      if let action {
        Button(action.title) { openURL(action.url) }
      }
    }
  }

  // MARK: - Parts

  /// The picture along the top: a page image or a map, edge to edge.
  @ViewBuilder
  private var media: some View {
    switch content {
    case .address:
      if let image = preview?.image {
        picture(image, height: 64)
      } else if PreviewStore.isEnabled {
        ZStack {
          Color(red: 0.93, green: 0.91, blue: 0.87)
          Image(systemName: "mappin.circle.fill")
            .font(.title2)
            .foregroundStyle(ClipKind.address.deepTint)
        }
        .frame(height: 64)
      }
    case .link:
      if let image = preview?.image {
        picture(image, height: 92)
      }
    default:
      EmptyView()
    }
  }

  private func picture(_ image: UIImage, height: CGFloat) -> some View {
    Image(uiImage: image)
      .resizable()
      .scaledToFill()
      .frame(height: height)
      .frame(maxWidth: .infinity)
      .clipped()
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var main: some View {
    switch content {
    case .link(let url):
      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: clip.title ?? preview?.title ?? url.host() ?? url.absoluteString)
          .font(.subheadline.weight(.semibold))
          .lineLimit(preview?.image == nil ? 4 : 2)
        Text(verbatim: url.host() ?? url.absoluteString)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .padding(.horizontal, 12)
      .padding(.top, 10)
    case .code:
      VStack(alignment: .leading, spacing: 6) {
        Text(verbatim: clip.title ?? CodeHighlighter.language(of: clip.text).title.uppercased())
          .font(.caption2.weight(.bold))
          .foregroundStyle(CodeTheme.label)
          .lineLimit(1)
        Text(CodeTheme.attributed(clip.text))
          .font(.system(.caption, design: .monospaced))
      }
      .padding(12)
      .fadingBottom()
    case .color(let hex):
      VStack(alignment: .leading, spacing: 2) {
        Spacer(minLength: 0)
        if let title = clip.title {
          Text(verbatim: title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
        }
        Text(verbatim: hex.uppercased())
          .font(.system(.title3, design: .monospaced).weight(.semibold))
        if let rgb = HexColor.rgb(hex) {
          Text(verbatim: "RGB \(rgb.0) \(rgb.1) \(rgb.2)")
            .font(.caption)
            .opacity(0.85)
        }
      }
      .padding(14)
    case .phone, .email:
      VStack(alignment: .leading, spacing: 4) {
        if let title = clip.title {
          Text(verbatim: title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Text(verbatim: clip.preview)
          .font(.title3.weight(.medium))
          .lineLimit(3)
          .minimumScaleFactor(0.75)
      }
      .padding(12)
    case .address:
      VStack(alignment: .leading, spacing: 1) {
        Text(verbatim: clip.title ?? Self.firstLine(of: clip.preview))
          .font(.subheadline.weight(.semibold))
          .lineLimit(preview?.image == nil && !PreviewStore.isEnabled ? 3 : 1)
        Text(verbatim: clip.title == nil ? Self.rest(of: clip.preview) : clip.preview)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .padding(.horizontal, 12)
      .padding(.top, 8)
    case .text:
      VStack(alignment: .leading, spacing: 4) {
        if let title = clip.title {
          Text(verbatim: title)
            .font(.subheadline.weight(.bold))
            .lineLimit(2)
        }
        Text(verbatim: clip.preview)
          .font(.subheadline)
      }
      .padding(12)
      .fadingBottom()
    }
  }

  private var footer: some View {
    HStack(spacing: 5) {
      Image(systemName: content.symbolName)
        .foregroundStyle(onDarkCard ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(content.kind.tint))
      Text(content.kindName)
        .fontWeight(.semibold)
        .foregroundStyle(onDarkCard ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(content.kind.tint))
      Text(verbatim: "·")
      AgeText(date: clip.lastCopiedAt)
      Spacer(minLength: 0)
      if clip.pinned {
        Image(systemName: "pin.fill")
          .foregroundStyle(onDarkCard ? Color.white : Color.pin)
          .accessibilityLabel(Text("Pinned clip"))
      }
      SourceBadge(clip: clip, onDarkCard: onDarkCard, isLocalOnly: isLocalOnly)
    }
    .font(.caption)
    .lineLimit(1)
    .foregroundStyle(onDarkCard ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
  }

  static func firstLine(of text: String) -> String {
    String(text.split(whereSeparator: \.isNewline).first ?? Substring(text))
  }

  static func rest(of text: String) -> String {
    text.split(whereSeparator: \.isNewline).dropFirst().joined(separator: ", ")
  }

  // MARK: - Colors

  private var onDarkCard: Bool {
    switch content {
    case .code: true
    case .color(let hex): !HexColor.isLight(hex)
    default: false
    }
  }

  private var background: AnyShapeStyle {
    switch content {
    case .code: AnyShapeStyle(CodeTheme.background)
    case .color(let hex): AnyShapeStyle(Color(hex: hex) ?? .gray)
    default: AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground))
    }
  }

  private var foreground: Color {
    if case .color(let hex) = content, HexColor.isLight(hex) { return .black }
    return onDarkCard ? .white : .primary
  }
}

/// Where a clip came from, at the end of its card or row: the app's initial on a small square for Mac copies that
/// name their app (the Mac will send the app's own icon in 1.3), otherwise the device. An iPhone can't tell which
/// app a copy came from.
struct SourceBadge: View {
  let clip: Clip
  var onDarkCard = false
  /// Kept on this iPhone only (iCloud data deleted, another account, or Settings › Privacy).
  var isLocalOnly = false

  var body: some View {
    if isLocalOnly {
      Image(systemName: "icloud.slash")
        .accessibilityLabel(Text("Only on This iPhone"))
    }
    if clip.isFromMac, let app = clip.sourceAppName, let initial = app.first {
      Text(verbatim: String(initial).uppercased())
        .font(.caption2.weight(.heavy))
        .frame(width: 18, height: 18)
        .foregroundStyle(onDarkCard ? Color.white : Color.accentColor)
        .background(
          onDarkCard ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(Color.accentColor.opacity(0.14)),
          in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
        .accessibilityLabel(Text(verbatim: "Mac, \(app)"))
    } else {
      Image(systemName: clip.isFromMac ? "laptopcomputer" : "iphone")
        .accessibilityLabel(Text(verbatim: clip.isFromMac ? "Mac" : "iPhone"))
    }
  }
}

/// The small square at the end of a list row: the page image or map when previews are on, otherwise the color, a
/// code sample or the kind's symbol.
struct ClipThumbnail: View {
  let clip: Clip
  @ScaledMetric(relativeTo: .body) private var size: CGFloat = 52

  var body: some View {
    let content = clip.content
    Group {
      if let image = PreviewStore.shared.preview(for: clip)?.image {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        switch content {
        case .color(let hex):
          Color(hex: hex) ?? .gray
        case .code:
          ZStack {
            CodeTheme.background
            Image(systemName: content.symbolName)
              .font(.headline)
              .foregroundStyle(CodeTheme.label)
          }
        default:
          ZStack {
            content.kind.tint.opacity(0.14)
            Image(systemName: content.symbolName)
              .font(.title3)
              .foregroundStyle(content.kind.tint)
          }
        }
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .task(id: clip.id) { await PreviewStore.shared.load(clip) }
    .accessibilityHidden(true)
  }
}

private extension View {
  /// Text that runs past the tile fades out at the bottom instead of stopping at a hard edge.
  func fadingBottom() -> some View {
    mask {
      LinearGradient(
        stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
        startPoint: .top,
        endPoint: .bottom
      )
    }
  }
}

/// Call, write, or get directions, inside the card.
private struct CardAction {
  let title: LocalizedStringKey
  let systemImage: String
  let url: URL

  init?(_ content: ClipContent) {
    switch content {
    case .phone(let number):
      guard let url = URL(string: "tel:\(number.filter { $0.isNumber || $0 == "+" })") else { return nil }
      (title, systemImage, self.url) = ("Call", "phone.fill", url)
    case .email(let address):
      guard let url = URL(string: "mailto:\(address)") else { return nil }
      (title, systemImage, self.url) = ("Write Email", "envelope.fill", url)
    case .address(let address):
      guard let url = Coordinates.directionsURL(to: address) else { return nil }
      (title, systemImage, self.url) = ("Get Directions", "arrow.triangle.turn.up.right.diamond.fill", url)
    default:
      return nil
    }
  }
}

/// Asked once, at the top of the history: previews need the network, so the person decides.
struct PreviewPromptCard: View {
  @AppStorage(PreviewChoice.key) private var choice = PreviewChoice.unasked.rawValue

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Show link and map previews?", systemImage: "rectangle.and.text.magnifyingglass")
        .font(.headline)
      Text("Links and addresses can show their page and a map inside their cards. For that, this iPhone opens the link and asks Apple Maps where the address is. Links that look like sign-in or reset links are never opened.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 10) {
        Button {
          withAnimation(.snappy) { choice = PreviewChoice.on.rawValue }
        } label: {
          Text("Show Previews")
            .frame(maxWidth: .infinity)
        }
        .primaryActionStyle()
        .accessibilityIdentifier("previewsOnButton")
        Button {
          withAnimation(.snappy) { choice = PreviewChoice.off.rawValue }
        } label: {
          Text("Not Now")
            .frame(maxWidth: .infinity)
        }
        .secondaryActionStyle()
        .accessibilityIdentifier("previewsOffButton")
      }
      .controlSize(.large)
      Text("You can change this in Settings.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(16)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}
