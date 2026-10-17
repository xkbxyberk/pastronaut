import CoreSpotlight
import PastronautCore
import SwiftUI

struct HistoryView: View {
  @Environment(ClipStore.self) private var store
  @Environment(CollectionActions.self) private var actions
  @Binding private var scope: HistoryScope
  /// False next to the iPad's sidebar, which shows the same choices.
  private let showsScopeBar: Bool
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

  init(scope: Binding<HistoryScope>, showsScopeBar: Bool) {
    _scope = scope
    self.showsScopeBar = showsScopeBar
  }

  var body: some View {
    @Bindable var store = store
    NavigationStack {
      List(selection: $selection) {
        if #unavailable(iOS 26.0), showsScopeBar {
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
      .modifier(FilterBarPlacement(isShown: showsScopeBar) { filterBar })
      // Text dropped here (iPad, or from another app) is saved, into the collection on screen if there is one.
      .dropDestination(for: String.self) { texts, _ in
        store.addDropped(texts, to: scope.collectionID)
        return !texts.isEmpty
      }
      .overlay {
        if store.clips.isEmpty {
          ContentUnavailableView(
            "No clips yet",
            systemImage: "tray",
            description: Text("Turn on Sync in Pastronaut on your Mac, or save your clipboard with the paste button.")
          )
        } else if sections.isEmpty {
          if store.searchText.isEmpty && tokens.isEmpty {
            switch scope {
            case .device(let filter):
              ContentUnavailableView("Nothing from this device", systemImage: filter.systemImage)
            case .collection:
              ContentUnavailableView(
                "No clips in this collection",
                systemImage: "folder",
                description: Text("Touch and hold a clip and choose Add to Collection.")
              )
            }
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
      // A fixed bar with the logotype instead of a large title: the large title collapsing on scroll fought the
      // filter bar under it and made the list jump.
      .modifier(BrandTitle(showsBrand: showsScopeBar, title: title))
      .onContinueUserActivity(CSSearchableItemActionType) { activity in
        // A pinned clip chosen in Spotlight is copied.
        if let id = SpotlightIndex.clipID(from: activity), let clip = store.clips.first(where: { $0.id == id }) {
          copy(clip)
        }
      }
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
    matchedClips.filter(scope.includes).sectioned()
  }

  private var title: Text {
    guard !showsScopeBar else { return Text(verbatim: "Pastronaut") }
    switch scope {
    case .device(let filter): return Text(filter.title)
    case .collection(let id): return Text(verbatim: store.collections.first { $0.id == id }?.name ?? "")
    }
  }

  private var filterBar: some View {
    let clips = matchedClips
    let counts = Dictionary(uniqueKeysWithValues: DeviceFilter.allCases.map { filter in
      (filter, clips.filter(filter.includes).count)
    })
    let collectionCounts = Dictionary(uniqueKeysWithValues: store.collections.map { collection in
      (collection.id, clips.count { $0.isIn(collection.id) })
    })
    return ScopeBar(scope: $scope, counts: counts, collectionCounts: collectionCounts)
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
    if showsScopeBar {
      if #available(iOS 26.0, *) {
        ToolbarItem(placement: .topBarLeading) {
          PastronautWordmark(size: 21)
        }
        .sharedBackgroundVisibility(.hidden)
      } else {
        ToolbarItem(placement: .topBarLeading) {
          PastronautWordmark(size: 21)
        }
      }
    }
    ToolbarItemGroup(placement: .topBarTrailing) {
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
    if #available(iOS 26.0, *) {
      ToolbarSpacer(.fixed, placement: .topBarTrailing)
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
      CollectionMenu(clips: selectedClips) {
        Label("Add to Collection", systemImage: "folder.badge.plus")
      }
      .disabled(selection.isEmpty)
      .accessibilityIdentifier("bulkCollect")
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
    // iPad: drag a clip into another app, or onto a collection in the sidebar.
    .modifier(DraggableOnPad(text: clip.text))
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
      CollectionMenu(clips: [clip])
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
  let isShown: Bool
  @ViewBuilder let bar: () -> Bar

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *), isShown {
      content.safeAreaBar(edge: .top, alignment: .leading) {
        // The bar scrolls sideways and keeps its own margins.
        bar()
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
    case .address: "Addresses"
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
    case .address: "mappin.and.ellipse"
    case .code: "chevron.left.forwardslash.chevron.right"
    case .text: "text.alignleft"
    }
  }
}

/// Rows are draggable on iPad only. On iPhone, a long press on a draggable row keeps the context menu "busy"
/// (found by the UI test, which then waited a minute per tap), and dragging between apps is an iPad habit.
private struct DraggableOnPad: ViewModifier {
  let text: String

  func body(content: Content) -> some View {
    if UIDevice.current.userInterfaceIdiom == .pad {
      content.draggable(text)
    } else {
      content
    }
  }
}

/// The phone's history shows the logotype in a fixed bar (the title stays for the back button where iOS allows);
/// next to the iPad's sidebar the screen keeps a plain inline title.
private struct BrandTitle: ViewModifier {
  let showsBrand: Bool
  let title: Text

  func body(content: Content) -> some View {
    if showsBrand {
      if #available(iOS 18.0, *) {
        content
          .navigationTitle(Text(verbatim: "Pastronaut"))
          .navigationBarTitleDisplayMode(.inline)
          .toolbar(removing: .title)
      } else {
        content
          .navigationTitle(Text(verbatim: ""))
          .navigationBarTitleDisplayMode(.inline)
      }
    } else {
      content
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
  }
}
