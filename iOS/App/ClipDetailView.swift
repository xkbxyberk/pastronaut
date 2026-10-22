import PastronautCore
import SwiftUI

struct ClipDetailView: View {
  @Environment(ClipStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  /// Follows the clip through edits, which change its content-derived ID.
  @State private var clipID: String
  @State private var showsCopied = false
  @State private var isEditing = false
  @State private var confirmsDelete = false
  @State private var isTitling = false
  @State private var titleDraft = ""

  init(clipID: String) {
    _clipID = State(initialValue: clipID)
  }

  private var clip: Clip? {
    store.clips.first { $0.id == clipID }
  }

  var body: some View {
    Group {
      if let clip {
        content(clip)
      } else {
        ContentUnavailableView("This clip was deleted", systemImage: "trash")
      }
    }
    .navigationTitle(clip.map { AppPreferences.shared.string($0.content.kindTitle) } ?? "")
    .navigationBarTitleDisplayMode(.inline)
    .overlay(alignment: .bottom) {
      if showsCopied {
        Toast(text: "Copied")
          .padding(.bottom, 24)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
  }

  private func content(_ clip: Clip) -> some View {
    ScrollView {
      VStack(spacing: 16) {
        if let image = PreviewStore.shared.preview(for: clip)?.image {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .accessibilityHidden(true)
        }
        Button {
          titleDraft = clip.title ?? ""
          isTitling = true
        } label: {
          TitleRow(title: clip.title)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detailTitle")
        // Content layer: a plain card. Glass is for the controls around it.
        Text(clip.text)
          .font(clip.content.usesMonospacedFont ? .body.monospaced() : .body)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(18)
          .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

        Button {
          copy(clip)
        } label: {
          Label("Copy", systemImage: "doc.on.doc")
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .primaryActionStyle()
        .accessibilityIdentifier("copyButton")

        if let action = SmartAction(clip.content) {
          Button {
            openURL(action.url)
          } label: {
            Label(action.title, systemImage: action.systemImage)
              .frame(maxWidth: .infinity)
          }
          .controlSize(.large)
          .secondaryActionStyle()
        }

        HStack(spacing: 10) {
          ShareLink(item: clip.text) {
            ActionTile(title: "Share", systemImage: "square.and.arrow.up")
          }
          .secondaryActionStyle()
          Button {
            store.togglePin(clip)
          } label: {
            ActionTile(title: clip.pinned ? "Unpin" : "Pin", systemImage: clip.pinned ? "pin.slash" : "pin")
          }
          .secondaryActionStyle()
          .tint(.pin)
          Button {
            isEditing = true
          } label: {
            ActionTile(title: "Edit", systemImage: "pencil")
          }
          .secondaryActionStyle()
          Button(role: .destructive) {
            confirmsDelete = true
          } label: {
            ActionTile(title: "Delete", systemImage: "trash")
          }
          .secondaryActionStyle()
          .tint(.red)
        }

        CollectionMenu(clips: [clip]) {
          CollectionsRow(names: store.collections.filter { clip.isIn($0.id) }.map(\.name))
        }
        .buttonStyle(.plain)

        InfoList(clip: clip, isLocalOnly: store.localOnly.clips.contains(clip.id))
      }
      .padding()
    }
    // Grouped background so the white cards stand out in light mode, like Settings.
    .background(Color(uiColor: .systemGroupedBackground))
    .sheet(isPresented: $isEditing) {
      ClipEditor(text: clip.text) { newText in
        if let newID = store.edit(clip, to: newText) {
          clipID = newID
        }
      }
    }
    .alert(Text(clip.title == nil ? "Add Title" : "Edit Title"), isPresented: $isTitling) {
      TextField("Title", text: $titleDraft)
      Button("Save") { store.setTitle(titleDraft, for: clip) }
      if clip.title != nil {
        Button("Remove Title", role: .destructive) { store.setTitle(nil, for: clip) }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Shown instead of the text, and found when you search. The text itself doesn't change.")
    }
    .confirmationDialog("Delete this clip?", isPresented: $confirmsDelete, titleVisibility: .visible) {
      Button("Delete", role: .destructive) {
        store.delete(clip)
        dismiss()
      }
    } message: {
      Text("It is removed from all your devices.")
    }
  }

  private func copy(_ clip: Clip) {
    store.copy(clip)
    Haptics.success()
    withAnimation(.snappy) { showsCopied = true }
    Task {
      try? await Task.sleep(for: .seconds(1.4))
      withAnimation(.snappy) { showsCopied = false }
    }
  }
}

/// Opens a link, starts a call or an email, without any network lookup of our own.
private struct SmartAction {
  let title: LocalizedStringKey
  let systemImage: String
  let url: URL

  init?(_ content: ClipContent) {
    switch content {
    case .link(let url):
      (title, systemImage, self.url) = ("Open Link", "safari", url)
    case .email(let address):
      guard let url = URL(string: "mailto:\(address)") else { return nil }
      (title, systemImage, self.url) = ("Write Email", "envelope", url)
    case .phone(let number):
      let dialable = number.filter { $0.isNumber || $0 == "+" }
      guard let url = URL(string: "tel:\(dialable)") else { return nil }
      (title, systemImage, self.url) = ("Call", "phone", url)
    case .address(let address):
      guard let url = Coordinates.directionsURL(to: address) else { return nil }
      (title, systemImage, self.url) = ("Get Directions", "arrow.triangle.turn.up.right.diamond", url)
    case .color, .code, .text:
      return nil
    }
  }
}

private struct ActionTile: View {
  let title: LocalizedStringKey
  let systemImage: String

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.title3)
      Text(title)
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, minHeight: 52)
  }
}

/// The clip's title, or a prompt to give it one; opens the title alert.
private struct TitleRow: View {
  let title: String?

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "character.cursor.ibeam")
        .foregroundStyle(Color.accentColor)
      if let title {
        Text(verbatim: title)
          .font(.headline)
          .lineLimit(2)
      } else {
        Text("Add Title")
      }
      Spacer()
      Image(systemName: "pencil")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .font(.subheadline)
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

/// The clip's collections; opens "Add to Collection".
private struct CollectionsRow: View {
  let names: [String]

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: names.isEmpty ? "folder.badge.plus" : "folder")
        .foregroundStyle(Color.accentColor)
      if names.isEmpty {
        Text("Add to Collection")
      } else {
        Text(verbatim: names.formatted(.list(type: .and)))
          .lineLimit(2)
      }
      Spacer()
      Image(systemName: "chevron.up.chevron.down")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .font(.subheadline)
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

private struct InfoList: View {
  let clip: Clip
  let isLocalOnly: Bool

  var body: some View {
    VStack(spacing: 0) {
      row("Source") {
        Text(verbatim: [clip.isFromMac ? "Mac" : "iPhone", clip.sourceAppName].compactMap { $0 }.joined(separator: " · "))
      }
      Divider()
      row("First copied") {
        Text(clip.firstCopiedAt, format: .dateTime.day().month().hour().minute())
      }
      Divider()
      row("Last copied") {
        Text(clip.lastCopiedAt, format: .dateTime.day().month().hour().minute())
      }
      Divider()
      row("Characters") {
        Text(clip.text.count, format: .number)
      }
      Divider()
      row("iCloud") {
        if isLocalOnly {
          Label("Only on This iPhone", systemImage: "icloud.slash")
        } else {
          Label("Encrypted", systemImage: "lock")
        }
      }
    }
    .font(.subheadline)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private func row(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
    HStack {
      Text(title).foregroundStyle(.secondary)
      Spacer()
      value()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .accessibilityElement(children: .combine)
  }
}

struct ClipEditor: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: String
  @FocusState private var isFocused: Bool
  private let original: String
  private let title: String.LocalizationValue
  /// A scan's text can be saved as it was read; an edit needs a change.
  private let allowsUnchanged: Bool
  private let onSave: (String) -> Void

  init(
    text: String,
    title: String.LocalizationValue = "Edit",
    allowsUnchanged: Bool = false,
    onSave: @escaping (String) -> Void
  ) {
    _draft = State(initialValue: text)
    original = text
    self.title = title
    self.allowsUnchanged = allowsUnchanged
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      TextEditor(text: $draft)
        .font(.body)
        .padding(.horizontal)
        .focused($isFocused)
        .onAppear { isFocused = true }
        .accessibilityIdentifier("clipEditor")
        .navigationTitle(AppPreferences.shared.string(title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              onSave(draft)
              dismiss()
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (draft == original && !allowsUnchanged))
            .accessibilityIdentifier("saveClipButton")
          }
        }
    }
  }
}

private extension ClipContent {
  var kindTitle: String.LocalizationValue {
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
}
