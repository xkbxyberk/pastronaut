import Defaults
import SwiftUI

enum SelectionAppearance {
  case none
  case topConnection
  case bottomConnection
  case topBottomConnection

  func rect(cornerRadius: CGFloat) -> some Shape {
    var cornerRadii = RectangleCornerRadii()
    switch self {
    case .none:
      cornerRadii.topLeading = cornerRadius
      cornerRadii.topTrailing = cornerRadius
      cornerRadii.bottomLeading = cornerRadius
      cornerRadii.bottomTrailing = cornerRadius
    case .topConnection:
      cornerRadii.bottomLeading = cornerRadius
      cornerRadii.bottomTrailing = cornerRadius
    case .bottomConnection:
      cornerRadii.topLeading = cornerRadius
      cornerRadii.topTrailing = cornerRadius
    case .topBottomConnection:
      break
    }
    return .rect(cornerRadii: cornerRadii)
  }
}

struct ListItemView<Title: View, ID: Hashable>: View {
  var id: ID
  var selectionId: UUID
  var appIcon: ApplicationImage?
  var image: NSImage?
  var accessoryImage: NSImage?
  var clipInfo: ClipRowInfo? // Pastronaut: content icon and "where · when" line for text clips.
  var attributedTitle: AttributedString?
  var shortcuts: [KeyShortcut]
  var isSelected: Bool
  var selectionIndex: Int?
  var help: LocalizedStringKey?
  var selectionAppearance: SelectionAppearance = .none
  // Complete description used when the row's visual content is hidden from accessibility.
  var accessibilityLabel: String = ""
  @ViewBuilder var title: () -> Title

  @Default(.showApplicationIcons) private var showIcons
  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags

  // Use the same selection number for the visible badge and accessibility value.
  private var displaySelectionIndex: String? {
    selectionIndex.map { "\($0 + 1)" }
  }

  var body: some View {
    HStack(spacing: 0) {
      if showIcons, clipInfo?.showsIPhoneBadge == true {
        // Pastronaut: the iPhone instead of a question mark (iOS doesn't say which app a copy came from).
        VStack {
          Spacer(minLength: 0)
          IPhoneBadge()
          Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .padding(.vertical, 5)
      } else if showIcons, let appIcon {
        VStack {
          Spacer(minLength: 0)
          AppImageView(appImage: appIcon, size: NSSize(width: 15, height: 15))
          Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .padding(.vertical, 5)
      }

      Spacer()
        .frame(width: showIcons ? 5 : 10)

      if let clipInfo, clipInfo.showsIcon {
        ClipContentIcon(kind: clipInfo.kind, colorHex: clipInfo.colorHex, isSelected: isSelected)
          .padding(.trailing, 8)
          .padding(.vertical, 5)
      } else if let clipInfo, image == nil {
        // Pastronaut: "Name Only" keeps the icon's place, so names line up with text rows.
        ClipContentIcon(kind: clipInfo.kind).hidden()
          .padding(.trailing, 8)
          .padding(.vertical, 5)
      }

      if let accessoryImage {
        Image(nsImage: accessoryImage)
          .accessibilityIdentifier("copy-history-item")
          .accessibilityHidden(true)
          .padding(.trailing, 5)
          .padding(.vertical, 5)
      }

      if let image, clipInfo != nil {
        // Pastronaut: a small picture in a column of its own, with the name and "where · when" next to it.
        MediaRowPicture(image: image)
          .padding(.trailing, 8)
          .padding(.vertical, 5)
      } else if let image {
        Image(nsImage: image)
          .accessibilityIdentifier("copy-history-item")
          .accessibilityHidden(true)
          .padding(.trailing, 5)
          .padding(.vertical, 5)
      }
      if let clipInfo {
        VStack(alignment: .leading, spacing: 1) {
          ListItemTitleView(attributedTitle: attributedTitle, title: title)
          HStack(spacing: 4) {
            if clipInfo.fromIPhone {
              Image(systemName: "iphone")
                .accessibilityLabel(Text(verbatim: "iPhone"))
            }
            Text(verbatim: clipInfo.subtitle)
              .lineLimit(1)
          }
          .font(.caption)
          .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
        }
        .accessibilityHidden(true)
        .padding(.trailing, 5)
        .padding(.vertical, 4)
      } else if image == nil {
        ListItemTitleView(attributedTitle: attributedTitle, title: title)
          .accessibilityHidden(true)
          .padding(.trailing, 5)
      }

      Spacer()

      HStack(spacing: 5) {
        if let displaySelectionIndex {
          Text(displaySelectionIndex)
            .font(.caption)
            .frame(minWidth: 10, alignment: .center)
            .padding(3)
            .background(
              Color.secondary.opacity(isSelected ? 0.5 : 0.8),
              in: Capsule()
            )
            .foregroundStyle(Color.white)
            .accessibilityHidden(true)
        }

        if !shortcuts.isEmpty {
          ZStack(alignment: .trailing) {
            ForEach(shortcuts) { shortcut in
              let visible = shortcut.isVisible(shortcuts, modifierFlags.flags)
              KeyboardShortcutView(shortcut: shortcut)
                .opacity(visible ? 1 : 0)
                .accessibilityHidden(true)
                .frame(width: visible ? nil : 0)
            }
          }
        }
      }
      .padding(.trailing, 10)
    }
    .frame(minHeight: Popup.itemHeight)
    .id(id)
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(isSelected ? Color.white : .primary)
    // macOS 26 broke hovering if no background is present.
    // The slight opcaity white background is a workaround
    .background(
      isSelected && !GlassSelection.isUsed(for: selectionAppearance)
        ? Color.accentColor.opacity(0.8) : .white.opacity(0.001),
      in: selectionAppearance.rect(cornerRadius: Popup.cornerRadius)
    )
    .modifier(GlassSelection(isSelected: isSelected, appearance: selectionAppearance)) // Pastronaut
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(accessibilityLabel))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityValue(Text(displaySelectionIndex ?? ""))
    .hoverSelectionId(selectionId)
    .help(help ?? "")
  }
}
