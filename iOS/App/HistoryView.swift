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
  @State private var showsOnboarding = false
  @State private var showsNewClip = false
  @State private var editMode: EditMode = .inactive
  @State private var selection = Set<String>()
  @State private var confirmsBulkDelete = false
  /// Pin and date chips in the search field. Kind chips there are the scope's kind (`searchChips`).
  @State private var tokens: [ClipSearchToken] = []
  @State private var heldBackIDs: Set<String> = []
  @State private var isAwayFromTop = false
  @State private var showsSyncChip = false
  /// "Add Title…": the clip being named and the text typed so far.
  @State private var titling: Clip?
  @State private var titleDraft = ""
  /// "Edit…" from the menu.
  @State private var editing: Clip?
  /// "Show in History": the clip to scroll to, and the one outlined for a moment.
  @State private var revealID: String?
  @State private var highlightID: String?
  @State private var isSearchPresented = false
  /// The clipboard holds something to paste (checked without reading it, so no paste prompt).
  @State private var clipboardHasContent = false
  @Environment(\.scenePhase) private var scenePhase
  @State private var showsTextScanner = false
  @State private var showsDocumentScanner = false
  @State private var isReadingScan = false
  @State private var scannedText: ScannedText?
  @AppStorage(AppPreferences.onboardingKey) private var hasCompletedOnboarding = false
  @AppStorage(PreviewChoice.key) private var previewChoice = PreviewChoice.unasked.rawValue

  init(scope: Binding<HistoryScope>, showsScopeBar: Bool) {
    _scope = scope
    self.showsScopeBar = showsScopeBar
  }

  var body: some View {
    @Bindable var store = store
    NavigationStack {
      ScrollViewReader { proxy in
        Group {
          if usesCards {
            cards
          } else {
            list
          }
        }
        .modifier(AwayFromTopTracker(isAway: $isAwayFromTop))
        .overlay(alignment: .top) {
          topIndicator(proxy: proxy)
            .padding(.top, 8)
        }
        .onChange(of: revealID) { _, id in
          guard let id else { return }
          Task { @MainActor in
            // Let the list drop the search first, so the clip has a place to scroll to.
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            withAnimation(.snappy) { highlightID = id }
            revealID = nil
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut) { if highlightID == id { highlightID = nil } }
          }
        }
      }
      .modifier(FilterBarPlacement(isShown: showsScopeBar) { filterBar })
      // Text dropped here (iPad, or from another app) is saved, into the collection on screen if there is one.
      .dropDestination(for: String.self) { texts, _ in
        store.addDropped(texts, to: scope.collectionID)
        return !texts.isEmpty
      }
      .overlay {
        if store.isWaitingForFirstSync {
          ProgressView {
            Text("Loading your clips…")
          }
          .controlSize(.large)
          .accessibilityIdentifier("firstSyncProgress")
        } else if store.clips.isEmpty {
          ContentUnavailableView(
            "No clips yet",
            systemImage: "tray",
            description: Text("Turn on Sync in Pastronaut on your Mac, or save your clipboard with the paste button.")
          )
        } else if sections.isEmpty {
          if store.searchText.isEmpty && tokens.isEmpty {
            emptyScope
          } else {
            ContentUnavailableView.search(text: store.searchText)
          }
        }
      }
      .overlay(alignment: .bottom) {
        if let toast {
          Toast(text: toast.text, systemImage: toast.systemImage, undo: toast.undo)
            // Above the bottom bar (search and "+") on iOS 26 and later.
            .padding(.bottom, Self.toastClearance)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .environment(\.editMode, $editMode)
      .onChange(of: store.noticeID) {
        switch store.notice {
        case .savedFromClipboard: showToast("Saved from clipboard")
        case .clipboardEmpty: showToast("The clipboard has no text", systemImage: "doc.questionmark")
        case .tooLarge: showToast("Too large to sync", systemImage: "exclamationmark.triangle")
        case .noTextFound: showToast("No text found on these pages", systemImage: "doc.questionmark")
        case .stillDownloading: showToast("Still downloading from iCloud", systemImage: "icloud.and.arrow.down")
        case .keptOnThisIPhone:
          showToast("Saved on this iPhone only", systemImage: "icloud.slash", for: .seconds(2.6))
        case nil: break
        }
      }
      // Chips for kind, date and pins. A kind chip is the filter menu's kind: choosing one in either place shows
      // in both.
      .modifier(HistorySearch(
        text: $store.searchText, chips: searchChips, suggested: suggestedChips, isPresented: $isSearchPresented
      ))
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
          deleteWithUndo(selectedClips)
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
      .modifier(ClipDialogs(editing: $editing, titling: $titling, titleDraft: $titleDraft))
      .modifier(ScanSheets(
        showsTextScanner: $showsTextScanner,
        showsDocumentScanner: $showsDocumentScanner,
        isReadingScan: $isReadingScan,
        scannedText: $scannedText
      ))
      .sheet(isPresented: $showsSettings) {
        SettingsView()
      }
      .fullScreenCover(isPresented: $showsOnboarding) {
        OnboardingView(presentation: .firstLaunch)
      }
      .onAppear(perform: showOnboardingOnce)
      .onChange(of: store.clips) { old, new in
        holdBackArrivals(from: old, in: new)
      }
      .onChange(of: isAwayFromTop) { _, isAway in
        if !isAway { releaseHeldBack() }
      }
      .task(id: store.isSyncing) {
        guard store.isSyncing else {
          withAnimation(.snappy) { showsSyncChip = false }
          return
        }
        try? await Task.sleep(for: .milliseconds(800))
        guard !Task.isCancelled, store.isSyncing else { return }
        withAnimation(.snappy) { showsSyncChip = true }
      }
      .task {
        // Safety net for lost pushes while the app is open; the app is suspended in the background.
        while !Task.isCancelled {
          try? await Task.sleep(for: .seconds(60))
          await store.refresh()
        }
      }
    }
  }

  private func showOnboardingOnce() {
    KeyboardSetup.shared.update()
    #if DEBUG
    if ProcessInfo.processInfo.environment["PT_E2E"] != nil { return }
    #endif
    guard !hasCompletedOnboarding else { return }
    showsOnboarding = true
  }

  private var sections: [ClipSection] {
    matchedClips.filter(scope.includes).sectioned()
  }

  /// Nothing matches the source, kind and collection chosen.
  @ViewBuilder
  private var emptyScope: some View {
    if scope.collectionID != nil && scope.kind == nil && scope.source == .all {
      ContentUnavailableView(
        "No clips in this collection",
        systemImage: "folder",
        description: Text("Touch and hold a clip and choose Add to Collection.")
      )
    } else if scope.hasFilters {
      ContentUnavailableView {
        Label("Nothing matches these filters", systemImage: "line.3.horizontal.decrease")
      } actions: {
        Button("Clear Filters") {
          withAnimation(.snappy) {
            scope.kind = nil
            scope.collectionID = nil
          }
        }
      }
    } else {
      ContentUnavailableView("Nothing from this device", systemImage: scope.source.systemImage)
    }
  }

  private var title: Text {
    guard !showsScopeBar else { return Text(verbatim: "Pastronaut") }
    if let id = scope.collectionID { return Text(verbatim: store.collections.first { $0.id == id }?.name ?? "") }
    if let kind = scope.kind { return Text(kind.pluralTitle) }
    return Text(scope.source.title)
  }

  private var filterBar: some View {
    let clips = matchedClips
    // What each choice would show with the other choices kept: the kind menu counts within the source and
    // collection, the collections within the source and kind.
    var withoutKind = scope
    withoutKind.kind = nil
    var withoutCollection = scope
    withoutCollection.collectionID = nil
    let forKinds = clips.filter(withoutKind.includes)
    let forCollections = clips.filter(withoutCollection.includes)
    let kindCounts = Dictionary(grouping: forKinds, by: { $0.content.kind }).mapValues(\.count)
    let collectionCounts = Dictionary(uniqueKeysWithValues: store.collections.map { collection in
      (collection.id, forCollections.count { $0.isIn(collection.id) })
    })
    return ScopeBar(scope: $scope, kindCounts: kindCounts, collectionCounts: collectionCounts)
  }

  private var isEditing: Bool { editMode.isEditing }

  private var matchedClips: [Clip] {
    visibleClips.matching(store.searchText, tokens: tokens)
  }

  private var visibleClips: [Clip] {
    heldBackIDs.isEmpty ? store.clips : store.clips.filter { !heldBackIDs.contains($0.id) }
  }

  private func holdBackArrivals(from old: [Clip], in new: [Clip]) {
    let current = Set(new.map(\.id))
    if !heldBackIDs.isSubset(of: current) {
      heldBackIDs.formIntersection(current)
    }
    guard isAwayFromTop, !isEditing, store.searchText.isEmpty, tokens.isEmpty else { return }
    let known = Set(old.map(\.id))
    let arrivals = new.filter { !known.contains($0.id) && $0.isFromMac }.map(\.id)
    heldBackIDs.formUnion(arrivals)
  }

  private static func cardSectionAnchor(_ section: ClipSection) -> String {
    "section.\(section.id)"
  }

  private func releaseHeldBack() {
    guard !heldBackIDs.isEmpty else { return }
    withAnimation(.snappy) { heldBackIDs.removeAll() }
  }

  @ViewBuilder
  private func topIndicator(proxy: ScrollViewProxy) -> some View {
    if !heldBackIDs.isEmpty {
      Button {
        withAnimation(.snappy) {
          if let section = sections.first {
            if usesCards {
              proxy.scrollTo(Self.cardSectionAnchor(section), anchor: .top)
            } else if let first = section.clips.first?.id {
              proxy.scrollTo(first, anchor: .top)
            }
          }
          heldBackIDs.removeAll()
        }
      } label: {
        Label("\(heldBackIDs.count) new", systemImage: "arrow.up")
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .glassBackground(in: Capsule())
      }
      .buttonStyle(.plain)
      .foregroundStyle(Color.accentColor)
      .transition(.move(edge: .top).combined(with: .opacity))
      .accessibilityIdentifier("newClipsButton")
    } else if showsSyncChip && !store.isWaitingForFirstSync {
      Label {
        Text("Syncing…")
      } icon: {
        ProgressView()
          .controlSize(.mini)
      }
      .font(.footnote.weight(.medium))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .glassBackground(in: Capsule())
      .transition(.opacity)
      .accessibilityIdentifier("syncChip")
    }
  }

  /// The chips in the search field: pins and dates as typed, and the scope's kind.
  private var searchChips: Binding<[SearchChip]> {
    Binding {
      tokens.map(SearchChip.token) + (scope.kind.map { [.kind($0)] } ?? [])
    } set: { chips in
      tokens = chips.compactMap(\.token)
      // One kind at a time, as in the menu: the one chosen last.
      let kinds = chips.compactMap(\.kind)
      if scope.kind != kinds.last {
        withAnimation(.snappy) { scope.kind = kinds.last }
      }
    }
  }

  /// Offered while searching: pins and dates not chosen yet, and the kinds there are clips of.
  private var suggestedChips: [SearchChip] {
    let others = ClipSearchToken.allCases.filter { !$0.isKind && !tokens.contains($0) }.map(SearchChip.token)
    let present = Set(store.clips.map { $0.content.kind })
    let kinds = ClipKind.allCases.filter { present.contains($0) && $0 != scope.kind }.map(SearchChip.kind)
    return others + kinds
  }

  /// Only what the list shows: the selection outlives a change of scope or search, and acting on clips the
  /// person can't see (deleting them) would be a surprise.
  /// The selection in the order the screen shows it, for the queue and for combining.
  /// Oldest first: the order they were copied in, for a queue and for combining.
  private var selectedInOrder: [Clip] {
    sections.flatMap(\.clips).filter { selection.contains($0.id) }.inCopyOrder
  }

  private var selectedClips: [Clip] {
    matchedClips.filter { scope.includes($0) && selection.contains($0.id) }
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
    if #unavailable(iOS 26.0) {
      ToolbarItemGroup(placement: .topBarTrailing) {
        newClipButton
      }
    }
    if #available(iOS 26.0, *) {
      // Search and "+" where the thumb is.
      DefaultToolbarItem(kind: .search, placement: .bottomBar)
      ToolbarSpacer(.fixed, placement: .bottomBar)
      ToolbarItem(placement: .bottomBar) {
        newClipButton
      }
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

  /// "+": paste what the clipboard holds (only offered when it holds something), type a clip, or scan text or a
  /// document with the camera.
  private var newClipButton: some View {
    Menu {
      if clipboardHasContent {
        // Text, an image, a PDF or files. The system button pastes without the paste prompt.
        PasteButton(supportedContentTypes: [.plainText, .url, .image, .pdf, .data]) { providers in
          Task { @MainActor in store.save(providers: providers) }
        }
      }
      Button {
        showsNewClip = true
      } label: {
        Label("Type a Clip", systemImage: "square.and.pencil")
      }
      .accessibilityIdentifier("typeClipButton")
      if TextScannerSheet.isAvailable {
        Button {
          showsTextScanner = true
        } label: {
          Label("Scan Text", systemImage: "text.viewfinder")
        }
        .accessibilityIdentifier("scanTextButton")
      }
      if DocumentScanner.isAvailable {
        Button {
          showsDocumentScanner = true
        } label: {
          Label("Scan Document", systemImage: "doc.viewfinder")
        }
        .accessibilityIdentifier("scanDocumentButton")
      }
    } label: {
      Label("New Clip", systemImage: "plus")
    }
    .accessibilityIdentifier("newClipButton")
    .task(id: scenePhase) { await watchClipboard() }
  }

  /// Keeps `clipboardHasContent` current while the app is in front: copies made in another app (iPad side by
  /// side) or here. Only the change count and the item count are read, which never asks for permission.
  private func watchClipboard() async {
    guard scenePhase == .active else { return }
    var seen = -1
    while !Task.isCancelled {
      let pasteboard = UIPasteboard.general
      if pasteboard.changeCount != seen {
        seen = pasteboard.changeCount
        let hasContent = pasteboard.numberOfItems > 0
        if hasContent != clipboardHasContent { clipboardHasContent = hasContent }
      }
      try? await Task.sleep(for: .seconds(1))
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
      Menu {
        Button {
          store.startQueue(selectedInOrder)
          endEditing()
          showToast("Queue ready: tap its key on the keyboard", for: .seconds(2.6))
        } label: {
          Label("Start Queue", systemImage: "list.number")
        }
        .disabled(selection.isEmpty)
        .accessibilityIdentifier("startQueue")
        if store.hasQueue {
          Button(role: .destructive) {
            store.endQueue()
            endEditing()
            showToast("Queue ended")
          } label: {
            Label("End Queue", systemImage: "xmark.circle")
          }
          .accessibilityIdentifier("endQueue")
        }
        Menu {
          ForEach(ClipSeparator.allCases, id: \.self) { separator in
            Button(separator.title) {
              let saved = store.copyCombined(selectedInOrder, separator: separator)
              endEditing()
              Haptics.success()
              showToast(saved ? "Copied and saved" : "Copied")
            }
          }
        } label: {
          Label("Combine & Copy", systemImage: "square.stack.3d.down.right")
        }
        .disabled(selection.count < 2)
      } label: {
        Label("More", systemImage: "ellipsis.circle")
      }
      .disabled(selection.isEmpty && !store.hasQueue)
      .accessibilityIdentifier("bulkMore")
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
    // White cards on the grey grouped background in light mode, raised grey in dark mode (`list`).
    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 12))
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
        deleteWithUndo([clip])
      } label: {
        Label("Delete", systemImage: "trash")
      }
      .accessibilityIdentifier("deleteAction")
    }
    .contextMenu { clipMenu(clip) }
  }

  /// Touch and hold, for list rows and cards alike.
  @ViewBuilder
  private func clipMenu(_ clip: Clip) -> some View {
    Button {
      copy(clip)
    } label: {
      Label("Copy", systemImage: "doc.on.doc")
    }
    if case .link(let url) = clip.content {
      Link(destination: url) {
        Label("Open Link", systemImage: "safari")
      }
    }
    if let text = clip.media?.recognizedText {
      Button {
        store.copyText(text)
        Haptics.success()
        showToast("Copied")
      } label: {
        Label("Copy Text", systemImage: "text.viewfinder")
      }
    }
    Button {
      detail = clip
    } label: {
      Label("Show Details", systemImage: "info.circle")
    }
    .accessibilityIdentifier("showDetails")
    if isNarrowed {
      Button {
        showInHistory(clip)
      } label: {
        Label("Show in History", systemImage: "clock.arrow.circlepath")
      }
      .accessibilityIdentifier("showInHistory")
    }
    Divider()
    Button {
      titleDraft = clip.title ?? ""
      titling = clip
    } label: {
      Label(clip.title == nil ? "Add Title…" : "Edit Title…", systemImage: "character.cursor.ibeam")
    }
    .accessibilityIdentifier("titleAction")
    if !clip.isMedia {
      Button {
        editing = clip
      } label: {
        Label("Edit…", systemImage: "pencil")
      }
    }
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
    if clip.isMedia {
      if MediaFiles.hasFiles(for: clip) {
        ShareLink(items: MediaFiles.fileURLs(for: clip))
      }
    } else {
      ShareLink(item: clip.text)
    }
    Divider()
    Button(role: .destructive) {
      deleteWithUndo([clip])
    } label: {
      Label("Delete", systemImage: "trash")
    }
  }

  /// Search, chips or another scope hide part of the history; "Show in History" brings the clip back among its
  /// neighbours.
  private var isNarrowed: Bool {
    !store.searchText.isEmpty || !tokens.isEmpty || scope != .all
  }

  private func showInHistory(_ clip: Clip) {
    store.searchText = ""
    tokens = []
    isSearchPresented = false
    scope = .all
    releaseHeldBack()
    revealID = clip.id
  }

  // MARK: - List (previews off)

  private var list: some View {
    List(selection: $selection) {
      if #unavailable(iOS 26.0), showsScopeBar {
        // Before Liquid Glass the filter scrolls with the list.
        Section {
          filterBar
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
      }
      if showsPreviewPrompt {
        Section {
          PreviewPromptCard()
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
      }
      ForEach(sections) { section in
        Section {
          ForEach(section.clips, id: \.id) { clip in
            row(clip)
              .listRowBackground(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                  .fill(Color(uiColor: .secondarySystemGroupedBackground))
                  .overlay {
                    if highlightID == clip.id {
                      RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                    }
                  }
              )
          }
        } header: {
          Text(section.title)
        }
        .headerProminence(.increased)
      }
    }
    // Separate cards instead of one grouped block: each clip is its own rounded surface.
    .listRowSpacing(10)
  }

  // MARK: - Cards (previews on)

  private var choice: PreviewChoice {
    PreviewChoice.override ?? PreviewChoice(rawValue: previewChoice) ?? .unasked
  }

  private var usesCards: Bool { choice == .on }

  /// Asked once, and only when there is something to preview.
  private var showsPreviewPrompt: Bool {
    guard choice == .unasked else { return false }
    return store.clips.contains { clip in
      switch clip.content {
      case .link, .address: true
      default: false
      }
    }
  }

  private var cards: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 12) {
        if #unavailable(iOS 26.0), showsScopeBar {
          filterBar
        }
        ForEach(sections) { section in
          Text(section.title)
            .font(.title3.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .id(Self.cardSectionAnchor(section))
          CardGrid(clips: section.clips) { clip in
            ClipCard(
              clip: clip,
              isEditing: isEditing,
              isSelected: selection.contains(clip.id),
              isHighlighted: highlightID == clip.id,
              isLocalOnly: store.localOnly.clips.contains(clip.id),
              isDownloading: store.pendingFiles.contains(clip.id)
            ) {
              if isEditing {
                if selection.contains(clip.id) { selection.remove(clip.id) } else { selection.insert(clip.id) }
              } else {
                copy(clip)
              }
            }
            // The lifted card keeps the card's shape (see `ClipCard.shape`).
            .contentShape(.contextMenuPreview, ClipCard.shape)
            .contextMenu { if !isEditing { clipMenu(clip) } }
            // Drag a card into another app (iPhone and iPad): its text, or its image or files.
            .contentShape(.dragPreview, ClipCard.shape)
            .modifier(ClipDrag(clip: clip))
            .accessibilityIdentifier(clip.pinned ? "card.pinned" : "card.unpinned")
            .id(clip.id)
          }
        }
      }
      .padding(.horizontal, 14)
      .padding(.bottom, 24)
    }
    // White cards on the grouped grey, like the list's rows.
    .background(Color(uiColor: .systemGroupedBackground))
  }

  private static var toastClearance: CGFloat {
    if #available(iOS 26.0, *) { 72 } else { 24 }
  }

  private func copy(_ clip: Clip) {
    store.copy(clip)
    Haptics.success()
    showToast("Copied")
  }

  /// Deleting asks no question (a swipe or the menu), so it can be taken back for a few seconds.
  private func deleteWithUndo(_ clips: [Clip]) {
    store.delete(clips)
    Haptics.success()
    showToast(
      clips.count == 1 ? "Deleted" : "Deleted \(clips.count) clips",
      systemImage: "trash",
      for: .seconds(5),
      undo: { store.undoDelete() }
    )
  }

  /// Short notices go quickly; a sentence to read (`duration`) stays longer.
  private func showToast(
    _ text: LocalizedStringKey,
    systemImage: String = "checkmark",
    for duration: Duration = .seconds(1.4),
    undo: (() -> Void)? = nil
  ) {
    withAnimation(.snappy) {
      toast = ToastContent(text: text, systemImage: systemImage, undo: undo.map { action in
        { action(); withAnimation(.snappy) { toast = nil } }
      })
    }
    hideToast?.cancel()
    hideToast = Task {
      try? await Task.sleep(for: duration)
      guard !Task.isCancelled else { return }
      withAnimation(.snappy) { toast = nil }
    }
  }
}

/// A list row: what the clip says (its title, or its first line, in bold), a second line of it, then its kind, time
/// and source; a small picture on the right.
struct ClipRow: View {
  let clip: Clip
  @Environment(ClipStore.self) private var store

  private var lines: (String, String?) {
    if case .link(let url) = clip.content {
      let host = url.host() ?? url.absoluteString
      let path = url.path().count > 1 ? url.path() : nil
      return (clip.title ?? PreviewStore.shared.preview(for: clip)?.title ?? host, clip.title == nil ? path : host)
    }
    if clip.isMedia {
      return (clip.title ?? clip.mediaCaption ?? "", clip.mediaSummary)
    }
    if let title = clip.title { return (title, clip.preview) }
    let parts = clip.preview.split(whereSeparator: \.isNewline).map(String.init)
    return (parts.first ?? clip.preview, parts.count > 1 ? parts.dropFirst().joined(separator: " ") : nil)
  }

  /// Code and colors read better in a fixed-width font; a link shows its page's name instead of the address.
  private var usesMonospacedTitle: Bool {
    switch clip.content {
    case .code, .color: clip.title == nil
    default: false
    }
  }

  var body: some View {
    let content = clip.content
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(verbatim: lines.0)
          .font(usesMonospacedTitle ? .body.monospaced().weight(.semibold) : .body.weight(.semibold))
          .lineLimit(1)
        if let second = lines.1 {
          Text(verbatim: second)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        HStack(spacing: 5) {
          // The kind on a band of its color, like a card's strip.
          Text(content.kindName)
            .fontWeight(.bold)
            .foregroundStyle(content.kind.tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(content.kind.strip, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
          Text(verbatim: "·")
          AgeText(date: clip.lastCopiedAt)
          if clip.pinned {
            Image(systemName: "pin.fill")
              .foregroundStyle(Color.pin)
              .accessibilityLabel(Text("Pinned clip"))
          }
          Spacer(minLength: 0)
          SourceBadge(clip: clip, isLocalOnly: store.localOnly.clips.contains(clip.id))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }
      .multilineTextAlignment(.leading)
      ClipThumbnail(clip: clip)
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
  }
}

/// "Scan Text" and "Scan Document" from the "+" menu.
private struct ScanSheets: ViewModifier {
  @Environment(ClipStore.self) private var store
  @Binding var showsTextScanner: Bool
  @Binding var showsDocumentScanner: Bool
  @Binding var isReadingScan: Bool
  @Binding var scannedText: ScannedText?

  func body(content: Content) -> some View {
    content
      .fullScreenCover(isPresented: $showsTextScanner) {
        TextScannerSheet { text in store.save(text) }
      }
      .fullScreenCover(isPresented: $showsDocumentScanner) {
        DocumentScanner { pages in
          showsDocumentScanner = false
          isReadingScan = true
          Task {
            // The pages are kept as a PDF; the text read from them can be checked and saved as text too.
            await store.saveScannedPDF(pages)
            let text = await TextRecognition.text(inPages: pages)
            isReadingScan = false
            if let text {
              scannedText = ScannedText(text: text)
            } else {
              store.notice = .noTextFound
            }
          }
        } onCancel: {
          showsDocumentScanner = false
        }
        .ignoresSafeArea()
      }
      .sheet(item: $scannedText) { scan in
        // Read on the device; shown first so it can be corrected before it is saved.
        ClipEditor(text: scan.text, title: "Scanned Text", allowsUnchanged: true) { text in
          store.save(text)
        }
      }
      .overlay {
        if isReadingScan {
          ProgressView {
            Text("Reading the text…")
          }
          .controlSize(.large)
          .padding(24)
          .glassBackground(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
      }
  }
}

/// "Edit…" and "Add Title…" from a clip's menu.
private struct ClipDialogs: ViewModifier {
  @Environment(ClipStore.self) private var store
  @Binding var editing: Clip?
  @Binding var titling: Clip?
  @Binding var titleDraft: String

  func body(content: Content) -> some View {
    content
      .sheet(item: $editing) { clip in
        ClipEditor(text: clip.text) { text in
          if store.edit(clip, to: text) == nil, !SyncPolicy.default.isEligible(text) {
            store.notice = .tooLarge
          }
        }
      }
      .alert(
        Text(titling?.title == nil ? "Add Title" : "Edit Title"),
        isPresented: Binding(get: { titling != nil }, set: { if !$0 { titling = nil } }),
        presenting: titling
      ) { clip in
        TextField("Title", text: $titleDraft)
          .accessibilityIdentifier("titleField")
        Button("Save") { store.setTitle(titleDraft, for: clip) }
          .accessibilityIdentifier("saveTitleButton")
        if clip.title != nil {
          Button("Remove Title", role: .destructive) { store.setTitle(nil, for: clip) }
        }
        Button("Cancel", role: .cancel) {}
      } message: { _ in
        Text("Shown instead of the text, and found when you search. The text itself doesn't change.")
      }
  }
}

// MARK: - Filtering and sections

/// Where clips were copied: everywhere, on the Mac, or on this iPhone (and iPads). Kinds and collections are in
/// the filter menu next to it.
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
    case .all: "tray.full"
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

extension ClipKind {
  /// The kind as a filter: "Links", "PDFs".
  var pluralTitle: LocalizedStringKey {
    switch self {
    case .text: "Text"
    case .link: "Links"
    case .code: "Code"
    case .email: "Emails"
    case .phone: "Phone Numbers"
    case .address: "Addresses"
    case .color: "Colors"
    case .image: "Images"
    case .pdf: "PDFs"
    case .file: "Files"
    }
  }
}

/// The search field with its chips; on its own so the history's body stays quick to compile.
private struct HistorySearch: ViewModifier {
  @Binding var text: String
  let chips: Binding<[SearchChip]>
  let suggested: [SearchChip]
  @Binding var isPresented: Bool

  func body(content: Content) -> some View {
    content.searchable(text: $text, tokens: chips, suggestedTokens: .constant(suggested), isPresented: $isPresented) {
      (chip: SearchChip) in
      Label(chip.title, systemImage: chip.systemImage)
    }
  }
}

/// A chip in the search field: a pin or date chip, or a kind (the same kind the filter menu chooses).
enum SearchChip: Hashable, Identifiable {
  case token(ClipSearchToken)
  case kind(ClipKind)

  var id: Self { self }

  var token: ClipSearchToken? {
    if case .token(let token) = self { return token }
    return nil
  }

  var kind: ClipKind? {
    if case .kind(let kind) = self { return kind }
    return nil
  }

  var title: LocalizedStringKey {
    switch self {
    case .token(let token): token.title
    case .kind(let kind): kind.pluralTitle
    }
  }

  var systemImage: String {
    switch self {
    case .token(let token): token.systemImage
    case .kind(let kind): kind.symbolName
    }
  }
}

extension ClipSearchToken {
  /// Kinds are chosen as the scope's kind on the iPhone (`SearchChip.kind`), not as these chips.
  var isKind: Bool {
    switch self {
    case .pinned, .today, .thisWeek: false
    case .link, .email, .phone, .color, .address, .code, .text, .image, .file: true
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
private struct AwayFromTopTracker: ViewModifier {
  @Binding var isAway: Bool

  func body(content: Content) -> some View {
    if #available(iOS 18.0, *) {
      content.onScrollGeometryChange(for: Bool.self) { geometry in
        geometry.contentOffset.y + geometry.contentInsets.top > 160
      } action: { _, isAway in
        self.isAway = isAway
      }
    } else {
      content
    }
  }
}

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
  /// "Undo" after a deletion.
  var undo: (() -> Void)?
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
    case .image: "Images"
    case .file: "Files"
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
    case .image: "photo"
    case .file: "doc"
    }
  }
}

/// A card dragged into another app: its text, or its image, PDF or files (with their names).
private struct ClipDrag: ViewModifier {
  let clip: Clip

  func body(content: Content) -> some View {
    if clip.isMedia {
      content.onDrag {
        guard let url = MediaFiles.fileURLs(for: clip).first, MediaFiles.hasFiles(for: clip),
              let provider = NSItemProvider(contentsOf: url) else { return NSItemProvider() }
        provider.suggestedName = url.lastPathComponent
        return provider
      }
    } else {
      content.draggable(clip.text)
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

extension ClipSeparator {
  var title: LocalizedStringKey {
    switch self {
    case .newLine: "One per Line"
    case .blankLine: "Blank Line Between"
    case .comma: "Commas"
    case .space: "Spaces"
    }
  }
}
