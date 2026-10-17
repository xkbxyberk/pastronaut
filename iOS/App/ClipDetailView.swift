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
    .navigationTitle(clip.map { Text($0.content.kindName) } ?? Text(verbatim: ""))
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

        InfoList(clip: clip)
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

private struct InfoList: View {
  let clip: Clip

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
        Label("Encrypted", systemImage: "lock")
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
  private let title: LocalizedStringKey
  private let onSave: (String) -> Void

  init(text: String, title: LocalizedStringKey = "Edit", onSave: @escaping (String) -> Void) {
    _draft = State(initialValue: text)
    original = text
    self.title = title
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
        .navigationTitle(title)
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
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft == original)
            .accessibilityIdentifier("saveClipButton")
          }
        }
    }
  }
}
