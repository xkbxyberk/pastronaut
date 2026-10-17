import PastronautCore
import SwiftUI
import UIKit

// The history as cards (previews on): each kind draws its own content, links and addresses with their preview.
// With previews off the history stays a list (HistoryView.row).

/// Two columns that fill top to bottom. Each clip goes to the column that is shorter so far (by an estimate of its
/// card's height), so tall cards (maps, page images, code) don't pile up on one side.
struct CardColumns<Card: View>: View {
  let clips: [Clip]
  @ViewBuilder let card: (Clip) -> Card

  var body: some View {
    let columns = Self.split(clips, previews: PreviewStore.isEnabled)
    HStack(alignment: .top, spacing: 10) {
      ForEach(0..<2, id: \.self) { index in
        VStack(spacing: 10) {
          ForEach(columns[index], id: \.id, content: card)
        }
        .frame(maxWidth: .infinity, alignment: .top)
      }
    }
  }

  static func split(_ clips: [Clip], previews: Bool) -> [[Clip]] {
    var columns: [[Clip]] = [[], []]
    var heights: [CGFloat] = [0, 0]
    for clip in clips {
      let target = heights[0] <= heights[1] ? 0 : 1
      columns[target].append(clip)
      heights[target] += estimatedHeight(of: clip, previews: previews) + 10
    }
    return columns
  }

  /// Rough card heights in points; close enough to keep the columns even.
  static func estimatedHeight(of clip: Clip, previews: Bool) -> CGFloat {
    let lines = CGFloat(min(7, max(1, clip.preview.count / 22 + clip.preview.filter(\.isNewline).count)))
    switch clip.content {
    case .address: return (previews ? 112 : 0) + 70 + lines * 20 + 44
    case .link: return (previews ? 100 : 0) + 110
    case .code: return 70 + CGFloat(min(9, clip.text.split(whereSeparator: \.isNewline).count + clip.text.count / 26)) * 18
    case .color: return 150
    case .phone, .email: return 140
    case .text: return 50 + lines * 20
    }
  }
}

struct ClipCard: View {
  let clip: Clip
  var isEditing = false
  var isSelected = false
  let onTap: () -> Void
  @Environment(\.openURL) private var openURL
  @Environment(\.colorScheme) private var colorScheme

  private var content: ClipContent { clip.content }
  private var preview: PreviewStore.Preview? { PreviewStore.shared.preview(for: clip) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: onTap) {
        VStack(alignment: .leading, spacing: 0) {
          media
          main
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      if let action = CardAction(content), !isEditing {
        Button {
          openURL(action.url)
        } label: {
          Label(action.title, systemImage: action.systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(.white)
            .background(content.kind.deepTint, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 4)
      }
      footer
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
    .foregroundStyle(foreground)
    .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      if isEditing {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
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
  }

  // MARK: - Parts

  @ViewBuilder
  private var media: some View {
    switch content {
    case .address:
      if let image = preview?.image {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(height: 112)
          .frame(maxWidth: .infinity)
          .clipped()
      } else if PreviewStore.isEnabled {
        ZStack {
          Color(red: 0.93, green: 0.91, blue: 0.87)
          Image(systemName: "mappin.circle.fill")
            .font(.title)
            .foregroundStyle(ClipKind.address.deepTint)
        }
        .frame(height: 112)
      }
    case .link:
      if let image = preview?.image {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(height: 100)
          .frame(maxWidth: .infinity)
          .clipped()
      }
    default:
      EmptyView()
    }
  }

  @ViewBuilder
  private var main: some View {
    switch content {
    case .link(let url):
      VStack(alignment: .leading, spacing: 6) {
        if let title = preview?.title {
          Text(verbatim: title)
            .font(.subheadline.weight(.bold))
            .lineLimit(3)
        }
        Label {
          Text(verbatim: url.host() ?? url.absoluteString)
            .lineLimit(1)
        } icon: {
          Image(systemName: "link")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(ClipKind.link.tint)
        if preview?.title == nil, !url.path().isEmpty, url.path() != "/" {
          Text(verbatim: url.path())
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
    case .code:
      VStack(alignment: .leading, spacing: 6) {
        Text(verbatim: CodeHighlighter.language(of: clip.text).title.uppercased())
          .font(.caption2.weight(.bold))
          .foregroundStyle(CodeTheme.label)
        Text(CodeTheme.attributed(clip.text))
          .font(.system(size: 12, design: .monospaced))
          .lineLimit(9)
      }
    case .color(let hex):
      VStack(alignment: .leading, spacing: 4) {
        Spacer().frame(height: 56)
        Text(verbatim: hex.uppercased())
          .font(.system(.title3, design: .monospaced).weight(.semibold))
        if let rgb = Self.rgb(hex) {
          Text(verbatim: "RGB \(rgb.0) \(rgb.1) \(rgb.2)")
            .font(.caption)
            .opacity(0.85)
        }
      }
    case .phone, .email:
      Text(verbatim: clip.preview)
        .font(.title3.weight(.medium))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    case .address:
      Text(verbatim: clip.preview)
        .font(.subheadline.weight(.semibold))
        .lineLimit(4)
    case .text:
      Text(verbatim: clip.preview)
        .font(.subheadline)
        .lineLimit(7)
    }
  }

  private var footer: some View {
    HStack(spacing: 5) {
      Image(systemName: content.symbolName)
        .foregroundStyle(onDarkCard ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(content.kind.tint))
      Text(content.kindName)
      Text(verbatim: "·")
      Text(clip.lastCopiedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
        .lineLimit(1)
      Spacer(minLength: 0)
      if clip.pinned {
        Image(systemName: "pin.fill")
          .foregroundStyle(onDarkCard ? Color.white : Color.pin)
          .accessibilityLabel(Text("Pinned clip"))
      }
      Image(systemName: clip.isFromMac ? "laptopcomputer" : "iphone")
        .accessibilityLabel(Text(verbatim: clip.isFromMac ? "Mac" : "iPhone"))
    }
    .font(.caption)
    .foregroundStyle(onDarkCard ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
  }

  // MARK: - Colors

  private var onDarkCard: Bool {
    switch content {
    case .code: true
    case .color(let hex): !Self.isLight(hex)
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
    if case .color(let hex) = content, Self.isLight(hex) { return .black }
    return onDarkCard ? .white : .primary
  }

  static func rgb(_ hex: String) -> (Int, Int, Int)? { HexColor.rgb(hex) }
  static func isLight(_ hex: String) -> Bool { HexColor.isLight(hex) }
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
      var components = URLComponents(string: "https://maps.apple.com/")
      components?.queryItems = [URLQueryItem(name: "daddr", value: address)]
      guard let url = components?.url else { return nil }
      (title, systemImage, self.url) = ("Get Directions", "arrow.triangle.turn.up.right.diamond.fill", url)
    default:
      return nil
    }
  }
}

/// Code colored on the device (CodeHighlighter), for the dark code cards.
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
