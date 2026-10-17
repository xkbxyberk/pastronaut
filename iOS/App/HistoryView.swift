import PastronautCore
import SwiftUI

struct HistoryView: View {
  @Environment(ClipStore.self) private var store
  @State private var filter: DeviceFilter = .all
  @State private var showsSettings = false
  @State private var toast: ToastContent?
  @State private var hideToast: Task<Void, Never>?
  @State private var detail: Clip?
  @State private var showsSetup = false
  @State private var showsNewClip = false
  @State private var editMode: EditMode = .inactive
  @State private var selection = Set<String>()
  @State private var confirmsBulkDelete = false
  @State private var tokens: [ClipSearchToken] = []
  @AppStorage("setupGuideShown") private var setupGuideShown = false

  var body: some View {
    @Bindable var store = store
    NavigationStack {
      List(selection: $selection) {
        if #unavailable(iOS 26.0) {
          // Before Liquid Glass the filter scrolls with the list.
          Section {
            filterBar
              .listRowInsets(EdgeInsets())
              .listRowBackground(Color.clear)
          }
        }
        ForEach(sections) { section in
          Section {
            ForEach(section.clips, id: \.id) { clip in
              row(clip)
            }
          } header: {
            Text(section.title)
          }
          .headerProminence(.increased)
        }
      }
      // Separate cards instead of one grouped block: each clip is its own rounded surface.
      .listRowSpacing(10)
      .modifier(FilterBarPlacement { filterBar })
      .overlay {
        if store.clips.isEmpty {
          ContentUnavailableView(
            "No clips yet",
            systemImage: "tray",
            description: Text("Turn on Sync in Pastronaut on your Mac, or save your clipboard with the paste button.")
          )
        } else if sections.isEmpty {
          if store.searchText.isEmpty && tokens.isEmpty {
            ContentUnavailableView("Nothing from this device", systemImage: filter.systemImage)
          } else {
            ContentUnavailableView.search(text: store.searchText)
          }
        }
      }
      .overlay(alignment: .bottom) {
        if let toast {
          Toast(text: toast.text, systemImage: toast.systemImage)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .environment(\.editMode, $editMode)
      .onChange(of: store.noticeID) {
        switch store.notice {
        case .savedFromClipboard: showToast("Saved from clipboard")
        case .clipboardEmpty: showToast("The clipboard has no text", systemImage: "doc.questionmark")
        case .tooLarge: showToast("Too large to sync", systemImage: "exclamationmark.triangle")
        case nil: break
        }
      }
      // Chips for kind, date and pins; the device bar stays separate.
      .searchable(text: $store.searchText, tokens: $tokens, suggestedTokens: .constant(suggestedTokens)) { token in
        Label(token.title, systemImage: token.systemImage)
      }
      .refreshable { await store.refresh() }
      .navigationTitle(Text(verbatim: "Pastronaut"))
      .navigationDestination(item: $detail) { clip in
        ClipDetailView(clipID: clip.id)
      }
      .toolbar {
        if isEditing {
          editingToolbar
        } else {
          browsingToolbar
        }
      }
      .confirmationDialog(
        Text("Delete \(selection.count) clips?"),
        isPresented: $confirmsBulkDelete,
        titleVisibility: .visible
      ) {
        Button("Delete", role: .destructive) {
          store.delete(selectedClips)
          endEditing()
        }
        .accessibilityIdentifier("confirmBulkDelete")
      } message: {
        Text("They are removed from all your devices.")
      }
      .sheet(isPresented: $showsNewClip) {
        ClipEditor(text: "", title: "New Clip") { text in
          store.save(text)
        }
      }
      .sheet(isPresented: $showsSettings) {
        SettingsView()
      }
      .sheet(isPresented: $showsSetup) {
        NavigationStack {
          KeyboardSetupView(isSheet: true)
        }
      }
      .onAppear(perform: showSetupOnce)
      .task {
        // Safety net for lost pushes while the app is open; the app is suspended in the background.
        while !Task.isCancelled {
          try? await Task.sleep(for: .seconds(60))
          await store.refresh()
        }
      }
    }
  }

  /// The keyboard is the point of the app, so its setup guide opens once on first launch.
  private func showSetupOnce() {
    let setup = KeyboardSetup.shared
    setup.update()
    #if DEBUG
    if ProcessInfo.processInfo.environment["PT_E2E"] != nil { return }
    #endif
    guard !setupGuideShown, !setup.isComplete else { return }
    setupGuideShown = true
    showsSetup = true
  }

  private var sections: [ClipSection] {
    matchedClips.filter(filter.includes).sectioned()
  }

  private var filterBar: some View {
    let clips = matchedClips
    let counts = Dictionary(uniqueKeysWithValues: DeviceFilter.allCases.map { filter in
      (filter, clips.filter(filter.includes).count)
    })
    return DeviceFilterBar(selection: $filter, counts: counts)
  }

  private var isEditing: Bool { editMode.isEditing }

  private var matchedClips: [Clip] {
    store.clips.matching(store.searchText, tokens: tokens)
  }

  /// Offered while searching; a chip already in the field isn't offered again.
  private var suggestedTokens: [ClipSearchToken] {
    ClipSearchToken.allCases.filter { !tokens.contains($0) }
  }

  private var selectedClips: [Clip] {
    store.clips.filter { selection.contains($0.id) }
  }

  @ToolbarContentBuilder
  private var browsingToolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .topBarLeading) {
      PasteButton(payloadType: String.self) { strings in
        Task { @MainActor in store.save(strings.first) }
      }
      .labelStyle(.iconOnly)
      .buttonBorderShape(.circle)
      Button {
        showsNewClip = true
      } label: {
        Label("New Clip", systemImage: "square.and.pencil")
      }
      .accessibilityIdentifier("newClipButton")
    }
    ToolbarItemGroup(placement: .topBarTrailing) {
      Button {
        withAnimation { editMode = .active }
      } label: {
        Label("Select", systemImage: "checkmark.circle")
      }
      .disabled(store.clips.isEmpty)
      .accessibilityIdentifier("selectButton")
      Button {
        showsSettings = true
      } label: {
        Label("Settings", systemImage: "gearshape")
      }
      .accessibilityIdentifier("settingsButton")
    }
  }

  @ToolbarContentBuilder
  private var editingToolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      let visible = Set(sections.flatMap(\.clips).map(\.id))
      if !visible.isEmpty && visible.isSubset(of: selection) {
        Button("Deselect All") { selection.removeAll() }
      } else {
        Button("Select All") { selection = visible }
          .accessibilityIdentifier("selectAllButton")
      }
    }
    ToolbarItem(placement: .confirmationAction) {
      Button("Done") { endEditing() }
        .accessibilityIdentifier("endSelectButton")
    }
    ToolbarItemGroup(placement: .bottomBar) {
      Button {
        store.togglePin(selectedClips)
        endEditing()
      } label: {
        let pins = selectedClips.contains { !$0.pinned }
        Label(pins ? "Pin" : "Unpin", systemImage: pins ? "pin" : "pin.slash")
      }
      .disabled(selection.isEmpty)
      .accessibilityIdentifier("bulkPin")
      Spacer()
      Text("\(selection.count) selected")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
      Button(role: .destructive) {
        confirmsBulkDelete = true
      } label: {
        Label("Delete", systemImage: "trash")
      }
      .disabled(selection.isEmpty)
      .accessibilityIdentifier("bulkDelete")
    }
  }

  private func endEditing() {
    withAnimation {
      editMode = .inactive
      selection.removeAll()
    }
  }

  @ViewBuilder
  private func row(_ clip: Clip) -> some View {
    if isEditing {
      // While selecting, a tap selects; copying would be a surprise.
      cardRow(ClipRow(clip: clip), clip: clip)
    } else {
      cardRow(
        Button {
          copy(clip)
        } label: {
          ClipRow(clip: clip)
        },
        clip: clip
      )
    }
  }

  private func cardRow(_ content: some View, clip: Clip) -> some View {
    content
    .foregroundStyle(.primary)
    .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 16))
    .listRowBackground(
      // White cards on the grey grouped background in light mode, raised grey in dark mode.
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(Color(uiColor: .secondarySystemGroupedBackground))
    )
    .listRowSeparator(.hidden)
    // The identifier carries the pin state for the end-to-end test (iOS/UITests); VoiceOver reads the label.
    .accessibilityIdentifier(clip.pinned ? "clip.pinned" : "clip.unpinned")
    .accessibilityHint(Text("Copies the text"))
    .swipeActions(edge: .leading) {
      Button {
        store.togglePin(clip)
      } label: {
        if clip.pinned {
          Label("Unpin", systemImage: "pin.slash")
        } else {
          Label("Pin", systemImage: "pin")
        }
      }
      .tint(.pin)
      .accessibilityIdentifier("pinAction")
    }
    .swipeActions(edge: .trailing) {
      Button(role: .destructive) {
        store.delete(clip)
      } label: {
        Label("Delete", systemImage: "trash")
      }
      .accessibilityIdentifier("deleteAction")
    }
    .contextMenu {
      Button {
        copy(clip)
      } label: {
        Label("Copy", systemImage: "doc.on.doc")
      }
      Button {
        detail = clip
      } label: {
        Label("Show Details", systemImage: "info.circle")
      }
      .accessibilityIdentifier("showDetails")
      Button {
        store.togglePin(clip)
      } label: {
        if clip.pinned {
          Label("Unpin", systemImage: "pin.slash")
        } else {
          Label("Pin", systemImage: "pin")
        }
      }
      ShareLink(item: clip.text)
      Divider()
      Button(role: .destructive) {
        store.delete(clip)
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  private func copy(_ clip: Clip) {
    store.copy(clip)
    Haptics.success()
    showToast("Copied")
  }

  private func showToast(_ text: LocalizedStringKey, systemImage: String = "checkmark") {
    withAnimation(.snappy) { toast = ToastContent(text: text, systemImage: systemImage) }
    hideToast?.cancel()
    hideToast = Task {
      try? await Task.sleep(for: .seconds(1.4))
      guard !Task.isCancelled else { return }
      withAnimation(.snappy) { toast = nil }
    }
  }
}

struct ClipRow: View {
  let clip: Clip

  var body: some View {
    HStack(spacing: 12) {
      ClipIcon(content: clip.content, size: 38, glass: true)
      VStack(alignment: .leading, spacing: 3) {
        Text(clip.preview)
          .font(clip.content.usesMonospacedFont ? .body.monospaced() : .body)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        ClipSourceLine(clip: clip)
      }
      Spacer(minLength: 0)
      if clip.pinned {
        Image(systemName: "pin.fill")
          .font(.footnote)
          .foregroundStyle(Color.pin)
          .accessibilityLabel(Text("Pinned clip"))
      }
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Filtering and sections

enum DeviceFilter: String, CaseIterable, Identifiable {
  case all
  case mac
  case iphone

  var id: Self { self }

  var title: LocalizedStringKey {
    switch self {
    case .all: "All"
    case .mac: "Mac"
    case .iphone: "iPhone"
    }
  }

  var systemImage: String {
    switch self {
    case .all: "tray"
    case .mac: "laptopcomputer"
    case .iphone: "iphone"
    }
  }

  func includes(_ clip: Clip) -> Bool {
    switch self {
    case .all: true
    case .mac: clip.sourceDevice == .mac
    case .iphone: clip.sourceDevice != .mac
    }
  }
}

struct ClipSection: Identifiable {
  let id: String
  let title: LocalizedStringKey
  let clips: [Clip]
}

extension Array where Element == Clip {
  /// Pinned first, then by the day of the last copy, newest first.
  func sectioned(now: Date = .now, calendar: Calendar = .current) -> [ClipSection] {
    let pinned = filter(\.pinned).sorted { $0.lastCopiedAt > $1.lastCopiedAt }
    let recent = filter { !$0.pinned }.sorted { $0.lastCopiedAt > $1.lastCopiedAt }
    let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) ?? now

    var today: [Clip] = [], yesterday: [Clip] = [], week: [Clip] = [], earlier: [Clip] = []
    for clip in recent {
      if calendar.isDate(clip.lastCopiedAt, inSameDayAs: now) {
        today.append(clip)
      } else if calendar.isDateInYesterday(clip.lastCopiedAt) {
        yesterday.append(clip)
      } else if clip.lastCopiedAt >= weekAgo {
        week.append(clip)
      } else {
        earlier.append(clip)
      }
    }
    return [
      ClipSection(id: "pinned", title: "Pinned", clips: pinned),
      ClipSection(id: "today", title: "Today", clips: today),
      ClipSection(id: "yesterday", title: "Yesterday", clips: yesterday),
      ClipSection(id: "week", title: "This Week", clips: week),
      ClipSection(id: "earlier", title: "Earlier", clips: earlier)
    ].filter { !$0.clips.isEmpty }
  }
}

/// On iOS 26 and later the filter is a glass bar under the navigation bar that takes part in the scroll
/// edge effect; earlier systems show it at the top of the list instead.
private struct FilterBarPlacement<Bar: View>: ViewModifier {
  @ViewBuilder let bar: () -> Bar

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.safeAreaBar(edge: .top, alignment: .leading) {
        bar()
          .padding(.horizontal)
          .padding(.vertical, 6)
      }
    } else {
      content
    }
  }
}


private struct ToastContent {
  let text: LocalizedStringKey
  let systemImage: String
}

extension ClipSearchToken {
  var title: LocalizedStringKey {
    switch self {
    case .pinned: "Pinned"
    case .today: "Today"
    case .thisWeek: "This Week"
    case .link: "Links"
    case .email: "Emails"
    case .phone: "Phone Numbers"
    case .color: "Colors"
    case .code: "Code"
    case .text: "Text"
    }
  }

  var systemImage: String {
    switch self {
    case .pinned: "pin"
    case .today: "sun.max"
    case .thisWeek: "calendar"
    case .link: "link"
    case .email: "envelope"
    case .phone: "phone"
    case .color: "paintpalette"
    case .code: "chevron.left.forwardslash.chevron.right"
    case .text: "text.alignleft"
    }
  }
}
