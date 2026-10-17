import AppKit
import Defaults
import PastronautCore
import SwiftUI

// Pastronaut additions to Maccy's popup and menu bar item: timed pause, time-based retention, undo for deleted
// items, hiding from screen sharing, and a context menu on rows. Kept in one file so Maccy's own files only
// gain one-line hooks (marked "// Pastronaut").

extension HistoryAge: Defaults.Serializable {}

extension Defaults.Keys {
  /// UI tests use Maccy's isolated preferences, like the Maccy settings these sit next to.
  #if DEBUG
  nonisolated(unsafe) private static let extrasSuite: UserDefaults = AppDelegate.isTesting
    ? (UserDefaults(suiteName: testingSuiteName) ?? .standard)
    : .standard
  #else
  nonisolated(unsafe) private static let extrasSuite: UserDefaults = .standard
  #endif

  /// When a pause chosen from the menu bar item ends. `nil` with `ignoreEvents` on means "until resumed".
  static let pausedUntil = Key<Date?>("pastronautPausedUntil", default: nil, suite: extrasSuite)
  static let historyAge = Key<HistoryAge>("pastronautHistoryAge", default: .forever, suite: extrasSuite)
  static let hideDuringScreenSharing = Key<Bool>("pastronautHideDuringScreenSharing", default: false, suite: extrasSuite)
}

@MainActor
enum PopupExtras {
  /// Call once at launch, also in UI tests.
  static func start() {
    CopyPause.start()
    HistoryRetention.start()
    ScreenSharingPrivacy.start()
  }
}

// MARK: - Pause

/// Pausing reuses Maccy's "ignoreEvents" switch, so the menu bar icon dims and the shell commands keep working;
/// a pause from the menu bar can also end by itself.
@MainActor
enum CopyPause {
  private static var resumeTask: Task<Void, Never>?

  static var isPaused: Bool { Defaults[.ignoreEvents] }

  static func pause(_ length: PauseLength) {
    Defaults[.pausedUntil] = length.end(from: .now)
    Defaults[.ignoreOnlyNextEvent] = false
    Defaults[.ignoreEvents] = true
    scheduleResume()
  }

  static func resume() {
    resumeTask?.cancel()
    Defaults[.pausedUntil] = nil
    Defaults[.ignoreEvents] = false
  }

  fileprivate static func start() {
    scheduleResume()
    Task {
      for await isIgnoring in Defaults.updates(.ignoreEvents, initial: false) where !isIgnoring {
        // Resumed some other way (Advanced settings, ⌥-click, a shell command): forget the timer.
        resumeTask?.cancel()
        Defaults[.pausedUntil] = nil
        AppState.shared.popup.needsResize = true
      }
    }
  }

  private static func scheduleResume() {
    resumeTask?.cancel()
    guard let end = Defaults[.pausedUntil] else { return }
    guard Defaults[.ignoreEvents] else {
      Defaults[.pausedUntil] = nil
      return
    }
    resumeTask = Task {
      let delay = end.timeIntervalSinceNow
      if delay > 0 {
        // ContinuousClock keeps counting while the Mac sleeps.
        try? await Task.sleep(for: .seconds(delay))
      }
      guard !Task.isCancelled else { return }
      resume()
    }
  }
}

/// The menu shown by right-clicking (or ⌃-clicking) the menu bar item.
@MainActor
enum StatusItemMenu {
  static func make(openPopup: @escaping () -> Void) -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false

    if CopyPause.isPaused {
      let state: String
      if let end = Defaults[.pausedUntil] {
        let time = end.formatted(date: Calendar.current.isDateInToday(end) ? .omitted : .abbreviated, time: .shortened)
        state = String(localized: "Copying paused until \(time)", table: "Pastronaut")
      } else {
        state = String(localized: "Copying paused", table: "Pastronaut")
      }
      menu.addItem(disabledItem(state))
      let resume = closureMenuItem(String(localized: "Resume Copying", table: "Pastronaut"), symbol: "play.fill") {
        CopyPause.resume()
      }
      resume.setAccessibilityIdentifier("resume-copying")
      menu.addItem(resume)
    } else {
      let pause = NSMenuItem(title: String(localized: "Pause Copying", table: "Pastronaut"), action: nil, keyEquivalent: "")
      pause.setAccessibilityIdentifier("pause-copying")
      pause.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: nil)
      let submenu = NSMenu()
      for length in PauseLength.allCases {
        let item = closureMenuItem(length.title) { CopyPause.pause(length) }
        item.setAccessibilityIdentifier("pause-\(length)")
        submenu.addItem(item)
      }
      pause.submenu = submenu
      menu.addItem(pause)
    }

    menu.addItem(.separator())
    menu.addItem(closureMenuItem(String(localized: "Open Pastronaut", table: "Pastronaut"), action: openPopup))
    menu.addItem(closureMenuItem(String(localized: "Settings…", table: "Pastronaut")) {
      AppState.shared.openPreferences()
    })
    menu.addItem(.separator())
    menu.addItem(closureMenuItem(String(localized: "Quit Pastronaut", table: "Pastronaut")) {
      NSApp.terminate(nil)
    })
    return menu
  }

  private static func disabledItem(_ title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    return item
  }
}

extension PauseLength {
  var title: String {
    switch self {
    case .fifteenMinutes: String(localized: "For 15 Minutes", table: "Pastronaut")
    case .oneHour: String(localized: "For 1 Hour", table: "Pastronaut")
    case .untilTomorrow: String(localized: "Until Tomorrow", table: "Pastronaut")
    case .indefinitely: String(localized: "Until I Resume", table: "Pastronaut")
    }
  }
}

/// Menu items that run a closure (NSMenuItem's own initializers can't be overridden from main-actor code).
private func closureMenuItem(_ title: String, symbol: String? = nil, action handler: @escaping () -> Void) -> NSMenuItem {
  let item = NSMenuItem(title: title, action: #selector(MenuActions.run(_:)), keyEquivalent: "")
  item.target = MenuActions.shared
  item.representedObject = MenuActions.Handler(handler)
  if let symbol {
    item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
  }
  return item
}

private final class MenuActions: NSObject {
  static let shared = MenuActions()

  final class Handler {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
  }

  @objc func run(_ sender: NSMenuItem) {
    (sender.representedObject as? Handler)?.run()
  }
}

// MARK: - Retention

@MainActor
enum HistoryRetention {
  fileprivate static func start() {
    Task {
      // History loads shortly after launch; check then, every hour, and whenever the setting changes.
      try? await Task.sleep(for: .seconds(30))
      while !Task.isCancelled {
        apply()
        try? await Task.sleep(for: .seconds(60 * 60))
      }
    }
    Task {
      for await _ in Defaults.updates(.historyAge, initial: false) {
        apply()
      }
    }
  }

  static func apply(now: Date = .now) {
    let age = Defaults[.historyAge]
    guard age != .forever else { return }
    let expired = AppState.shared.history.allItems.filter {
      age.isExpired(lastCopiedAt: $0.item.lastCopiedAt, pinned: $0.isPinned || SyncedCollections.shared.isKept($0.item), now: now)
    }
    guard !expired.isEmpty else { return }
    expired.forEach(AppState.shared.history.delete)
  }

  @MainActor
  static func expiredCount(for age: HistoryAge, now: Date = .now) -> Int {
    AppState.shared.history.allItems.filter {
      age.isExpired(lastCopiedAt: $0.item.lastCopiedAt, pinned: $0.isPinned || SyncedCollections.shared.isKept($0.item), now: now)
    }.count
  }
}

extension HistoryAge {
  var title: String {
    switch self {
    case .forever: String(localized: "Forever", table: "Pastronaut")
    case .day: String(localized: "1 Day", table: "Pastronaut")
    case .week: String(localized: "1 Week", table: "Pastronaut")
    case .month: String(localized: "1 Month", table: "Pastronaut")
    case .year: String(localized: "1 Year", table: "Pastronaut")
    }
  }
}

/// "Keep history" in Storage settings. Choosing a shorter period asks first, because older items go at once.
struct HistoryAgeSetting: View {
  @Default(.historyAge) private var age
  @State private var pending: HistoryAge?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Picker("", selection: Binding(get: { age }, set: choose)) {
        ForEach(HistoryAge.allCases, id: \.self) { age in
          Text(verbatim: age.title).tag(age)
        }
      }
      .labelsHidden()
      .frame(width: 160, alignment: .leading)
      .accessibilityLabel(Text("Keep history", tableName: "Pastronaut"))
      Text("Older items are deleted on all your devices. Pinned items are always kept.", tableName: "Pastronaut")
        .controlSize(.small)
        .foregroundStyle(.gray)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 300, alignment: .leading)
    }
    .alert(
      Text("Delete older items?", tableName: "Pastronaut"),
      isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
      presenting: pending
    ) { newAge in
      Button(role: .destructive) {
        age = newAge
      } label: {
        Text("Delete", tableName: "Pastronaut")
      }
      Button(role: .cancel) {} label: {
        Text("Cancel", tableName: "Pastronaut")
      }
    } message: { newAge in
      Text("\(HistoryRetention.expiredCount(for: newAge)) unpinned items are older than \(newAge.title) and will be deleted from this Mac and iCloud. This can't be undone.", tableName: "Pastronaut")
    }
  }

  private func choose(_ newAge: HistoryAge) {
    if newAge.isShorter(than: age) && HistoryRetention.expiredCount(for: newAge) > 0 {
      pending = newAge
    } else {
      age = newAge
    }
  }
}

// MARK: - Undo

/// Keeps what the user just deleted from the popup for a few seconds, so ⌘Z or the footer button can bring it
/// back. Restored items are added again like a new copy, so they sync again too.
@MainActor
@Observable
final class RecentlyDeleted {
  static let shared = RecentlyDeleted()

  private struct Snapshot {
    let contents: [(type: String, value: Data?)]
    let title: String
    let pin: String?
    let application: String?
    let firstCopiedAt: Date
    let lastCopiedAt: Date
    let numberOfCopies: Int

    init(_ item: HistoryItem) {
      contents = item.contents.map { ($0.type, $0.value) }
      title = item.title
      pin = item.pin
      application = item.application
      firstCopiedAt = item.firstCopiedAt
      lastCopiedAt = item.lastCopiedAt
      numberOfCopies = item.numberOfCopies
    }
  }

  private var snapshots: [Snapshot] = []
  private var expiry: Task<Void, Never>?
  private(set) var count = 0

  var canUndo: Bool { count > 0 }

  func remember(_ items: [HistoryItemDecorator]) {
    snapshots = items.map { Snapshot($0.item) }
    count = snapshots.count
    AppState.shared.popup.needsResize = true
    expiry?.cancel()
    expiry = Task {
      try? await Task.sleep(for: .seconds(8))
      guard !Task.isCancelled else { return }
      forget()
    }
  }

  func undo() {
    let restored = snapshots.map(restore)
    forget()
    if let first = restored.first {
      AppState.shared.navigator.select(item: first)
    }
  }

  private func forget() {
    expiry?.cancel()
    snapshots = []
    count = 0
    AppState.shared.popup.needsResize = true
  }

  private func restore(_ snapshot: Snapshot) -> HistoryItemDecorator {
    let item = HistoryItem(contents: snapshot.contents.map { HistoryItemContent(type: $0.type, value: $0.value) })
    item.title = snapshot.title
    item.application = snapshot.application
    item.firstCopiedAt = snapshot.firstCopiedAt
    item.lastCopiedAt = snapshot.lastCopiedAt
    item.numberOfCopies = snapshot.numberOfCopies
    if let pin = snapshot.pin {
      item.pin = HistoryItem.availablePins.contains(pin) ? pin : HistoryItem.randomAvailablePin
    }
    if #unavailable(macOS 15.0) {
      // Maccy's add expects the item in storage already on macOS 14 (see History.add).
      try? AppState.shared.history.insertIntoStorage(item)
    }
    return AppState.shared.history.add(item)
  }
}

// MARK: - Screen sharing

@MainActor
enum ScreenSharingPrivacy {
  fileprivate static func start() {
    Task {
      for await hide in Defaults.updates(.hideDuringScreenSharing) {
        apply(hide)
      }
    }
  }

  /// The popup is created once at launch; panels opened later (like the preview) live inside it.
  static func apply(_ hide: Bool = Defaults[.hideDuringScreenSharing]) {
    for window in NSApp.windows where window is NSPanel {
      window.sharingType = hide ? .none : .readOnly
    }
  }
}

struct HideDuringScreenSharingToggle: View {
  var body: some View {
    Defaults.Toggle(key: .hideDuringScreenSharing) {
      Text("Hide during screen sharing and recording", tableName: "Pastronaut")
    }
    .help(Text("Other people in a call, and screenshots, won't see your clipboard history.", tableName: "Pastronaut"))
  }
}

// MARK: - Popup footer

/// Pause and undo notices above the sync status line.
struct PopupStatusArea: View {
  @Default(.ignoreEvents) private var isPaused
  @Default(.pausedUntil) private var pausedUntil

  var body: some View {
    VStack(spacing: 4) {
      if isPaused {
        notice(symbol: "pause.circle.fill", tint: .orange) {
          if let pausedUntil {
            Text("Copying paused until \(pausedUntil.formatted(date: .omitted, time: .shortened))", tableName: "Pastronaut")
          } else {
            Text("Copying paused", tableName: "Pastronaut")
          }
        } action: {
          Button {
            CopyPause.resume()
          } label: {
            Text("Resume", tableName: "Pastronaut")
          }
          .accessibilityIdentifier("resume-button")
        }
      }
      QueueNotice()
      if RecentlyDeleted.shared.canUndo {
        notice(symbol: "trash", tint: .secondary) {
          Text("Deleted \(RecentlyDeleted.shared.count) items", tableName: "Pastronaut")
        } action: {
          Button {
            RecentlyDeleted.shared.undo()
          } label: {
            Text("Undo", tableName: "Pastronaut")
          }
          .accessibilityIdentifier("undo-button")
          .keyboardShortcut("z", modifiers: .command)
        }
      }
      SyncStatusLine()
    }
    .onChange(of: isPaused) { AppState.shared.popup.needsResize = true }
  }

  private func notice(
    symbol: String,
    tint: Color,
    @ViewBuilder text: () -> some View,
    @ViewBuilder action: () -> some View
  ) -> some View {
    StatusNotice(symbol: symbol, tint: tint, text: text, action: action)
  }
}

/// One line above the sync status: a symbol, a short text and a small button.
struct StatusNotice<Label: View, Action: View>: View {
  let symbol: String
  let tint: Color
  let text: Label
  let action: Action

  init(symbol: String, tint: Color, @ViewBuilder text: () -> Label, @ViewBuilder action: () -> Action) {
    self.symbol = symbol
    self.tint = tint
    self.text = text()
    self.action = action()
  }

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .foregroundStyle(tint)
      text
        .lineLimit(1)
        .foregroundStyle(.secondary)
      Spacer(minLength: 4)
      action
        .buttonStyle(.borderless)
        .controlSize(.small)
    }
    .font(.caption)
    .padding(.horizontal, 10)
    .padding(.bottom, Popup.verticalSeparatorPadding)
    .accessibilityElement(children: .contain)
  }
}

// MARK: - Row context menu

struct HistoryItemContextMenu: View {
  let item: HistoryItemDecorator

  var body: some View {
    let history = AppState.shared.history
    Button {
      AppState.shared.popup.close()
      Clipboard.shared.copy(item.item)
      history.searchQuery = ""
    } label: {
      Label { Text("Copy", tableName: "Pastronaut") } icon: { Image(systemName: "doc.on.doc") }
    }
    .accessibilityIdentifier("context-copy")
    Button {
      AppState.shared.popup.close()
      Clipboard.shared.copy(item.item)
      Clipboard.shared.paste()
      history.searchQuery = ""
    } label: {
      Label { Text("Paste", tableName: "Pastronaut") } icon: { Image(systemName: "doc.on.clipboard") }
    }
    Button {
      AppState.shared.popup.close()
      Clipboard.shared.copy(item.item, removeFormatting: true)
      Clipboard.shared.paste()
      history.searchQuery = ""
    } label: {
      Label { Text("Paste as Plain Text", tableName: "Pastronaut") } icon: { Image(systemName: "textformat") }
    }
    if item.item.imageData != nil, !item.item.title.isEmpty {
      // Maccy already reads the text in images (it becomes the title, so it's searchable); this copies it.
      Button {
        AppState.shared.popup.close()
        Clipboard.shared.copyInMaccy(item.item.title)
      } label: {
        Label { Text("Copy Text from Image", tableName: "Pastronaut") } icon: { Image(systemName: "text.viewfinder") }
      }
    }
    Divider()
    Button {
      history.togglePin(item)
    } label: {
      if item.isPinned {
        Label { Text("Unpin", tableName: "Pastronaut") } icon: { Image(systemName: "pin.slash") }
      } else {
        Label { Text("Pin", tableName: "Pastronaut") } icon: { Image(systemName: "pin") }
      }
    }
    CollectionsContextMenu(item: item)
    if Self.isFiltered {
      Button {
        Self.reveal(item)
      } label: {
        Label { Text("Show in History", tableName: "Pastronaut") } icon: { Image(systemName: "list.bullet.below.rectangle") }
      }
      .keyboardShortcut("g", modifiers: .command)
      .accessibilityIdentifier("context-reveal")
    }
    Divider()
    Button(role: .destructive) {
      Self.delete(item)
    } label: {
      Label { Text("Delete", tableName: "Pastronaut") } icon: { Image(systemName: "trash") }
    }
    .accessibilityIdentifier("context-delete")
  }

  /// A search or a filter hides part of the history, so "Show in History" (⌘G) has something to show.
  static var isFiltered: Bool {
    let history = AppState.shared.history
    return !history.searchQuery.isEmpty || history.deviceFilter != .all || !history.tokenFilter.isEmpty
      || history.collectionFilter != nil
  }

  /// Deletes one row and, like the delete shortcut, keeps the selection in the list instead of the footer.
  static func delete(_ item: HistoryItemDecorator) {
    let history = AppState.shared.history
    let navigator = AppState.shared.navigator
    let next = history.nearestVisible(to: item) { $0 != item }
    let keepsSelection = navigator.leadHistoryItem != nil && navigator.leadHistoryItem != item
    RecentlyDeleted.shared.remember([item])
    withTransaction(Transaction()) {
      history.delete(item)
      if !keepsSelection {
        navigator.select(item: next)
      }
    }
  }

  /// Clears the search and the device filter, then selects the item among its neighbours from the same day.
  static func reveal(_ item: HistoryItemDecorator) {
    let history = AppState.shared.history
    history.deviceFilter = .all
    history.tokenFilter = []
    history.collectionFilter = nil
    history.searchQuery = ""
    Task {
      // Clearing the search is throttled (0.2 s) and then selects the first item; select ours after that.
      try? await Task.sleep(for: .milliseconds(350))
      AppState.shared.navigator.select(item: item)
    }
  }
}

// MARK: - Text in images

/// Under an image's preview: the text Maccy recognized in it (also its searchable title), with a copy button.
struct RecognizedTextPreview: View {
  let item: HistoryItemDecorator
  @State private var copied = false

  var body: some View {
    let text = item.item.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !text.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Label { Text("Text in Image", tableName: "Pastronaut") } icon: { Image(systemName: "text.viewfinder") }
            .font(.caption.weight(.semibold))
          Spacer()
          Button {
            Clipboard.shared.copyInMaccy(text)
            copied = true
            Task {
              try? await Task.sleep(for: .seconds(1.5))
              copied = false
            }
          } label: {
            Label {
              copied ? Text("Copied", tableName: "Pastronaut") : Text("Copy Text", tableName: "Pastronaut")
            } icon: {
              Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
          }
          .controlSize(.small)
          .accessibilityIdentifier("preview-copy-text")
        }
        ScrollView {
          Text(verbatim: text)
            .font(.callout)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 120)
      }
      .padding(.top, 10)
    }
  }
}

// MARK: - Preview by kind

/// The preview's body for clips with a kind of their own: code in color on a dark panel, a color as a swatch, and
/// links, addresses, emails and phone numbers with a button that opens them. Plain text keeps Maccy's preview.
struct KindPreview: View {
  /// Longer code stays plain (coloring is a regex pass over the whole text).
  private static let maxCodeLength = 20_000

  let content: ClipContent
  let text: String

  static func handles(_ content: ClipContent, text: String) -> Bool {
    switch content {
    case .text: false
    case .code: text.utf16.count <= maxCodeLength
    default: true
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      switch content {
      case .code:
        code
      case .color(let hex):
        swatch(hex)
      default:
        ScrollView {
          Text(verbatim: text)
            .font(.body)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 220)
        .fixedSize(horizontal: false, vertical: true)
      }
      if let action = PreviewAction(content) {
        Button {
          AppState.shared.popup.close()
          NSWorkspace.shared.open(action.url)
        } label: {
          Label { Text(action.title, tableName: "Pastronaut") } icon: { Image(systemName: action.systemImage) }
        }
        .controlSize(.regular)
        .accessibilityIdentifier("preview-action")
      }
    }
  }

  private var code: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(verbatim: CodeHighlighter.language(of: text).title.uppercased())
        .font(.caption2.weight(.bold))
        .foregroundStyle(CodeTheme.label)
      ScrollView([.vertical, .horizontal]) {
        Text(CodeTheme.attributed(text))
          .font(.system(size: 12, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(CodeTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .accessibilityIdentifier("preview-code")
  }

  private func swatch(_ hex: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Spacer(minLength: 0)
      Text(verbatim: hex.uppercased())
        .font(.system(.title2, design: .monospaced).weight(.semibold))
      if let (r, g, b) = HexColor.rgb(hex) {
        Text(verbatim: "RGB \(r) \(g) \(b)")
          .font(.callout)
          .opacity(0.85)
      }
    }
    .foregroundStyle(HexColor.isLight(hex) ? Color.black : Color.white)
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 130, idealHeight: 130, maxHeight: 130, alignment: .bottomLeading)
    .background(NSColor(hexString: hex).map { Color(nsColor: $0) } ?? .gray, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator))
    .accessibilityIdentifier("preview-swatch")
  }
}

/// Open a link, write an email, call, or get directions: what the preview's button does.
private struct PreviewAction {
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
      guard let url = URL(string: "tel:\(number.filter { $0.isNumber || $0 == "+" })") else { return nil }
      (title, systemImage, self.url) = ("Call", "phone", url)
    case .address(let address):
      guard let url = Coordinates.directionsURL(to: address) else { return nil }
      (title, systemImage, self.url) = ("Get Directions", "arrow.triangle.turn.up.right.diamond", url)
    case .code, .color, .text:
      return nil
    }
  }
}

/// ⌘G: show the selected row among its neighbours, search and filters cleared.
enum RevealKey {
  static func matches(_ event: NSEvent?) -> Bool {
    guard let event, event.type == .keyDown, event.keyCode == 5 else { return false } // kVK_ANSI_G
    return event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command
  }
}

/// Space alone, like Quick Look in Finder.
enum QuickPreviewKey {
  static func matches(_ event: NSEvent?) -> Bool {
    guard let event, event.type == .keyDown, event.keyCode == 49 else { return false } // kVK_Space
    return event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
  }
}

// MARK: - Queue

/// Pasting several clips in order: select them with ⌘-click or ⇧↑ ⇧↓, press Return, then every ⌘V in any app
/// pastes the next one. Built on Maccy's multiple selection and its stack of items to paste; this adds the notices
/// that explain it and copies only (no automatic first paste, so the next item can't replace it mid-paste).
struct QueueNotice: View {
  var body: some View {
    let appState = AppState.shared
    let isQueueing = appState.history.pasteStack.map { !$0.items.isEmpty } ?? false
      || appState.navigator.selection.count > 1
    if isQueueing && !QueuePermission.isGranted {
      StatusNotice(symbol: "exclamationmark.triangle.fill", tint: .orange) {
        Text("The queue needs permission to notice ⌘V", tableName: "Pastronaut")
      } action: {
        Button {
          QueuePermission.request()
        } label: {
          Text("Allow…", tableName: "Pastronaut")
        }
        .accessibilityIdentifier("queue-permission")
      }
    }
    if let stack = appState.history.pasteStack, !stack.items.isEmpty {
      StatusNotice(symbol: "list.number", tint: .accentColor) {
        Text("Queue: \(stack.items.count) left · ⌘V pastes the next", tableName: "Pastronaut")
      } action: {
        Button {
          appState.removePasteStack()
        } label: {
          Text("End Queue", tableName: "Pastronaut")
        }
        .accessibilityIdentifier("queue-end")
      }
      .accessibilityIdentifier("queue-notice")
    } else if appState.navigator.selection.count > 1 {
      StatusNotice(symbol: "list.number", tint: .accentColor) {
        Text("\(appState.navigator.selection.count) selected · Return starts a queue", tableName: "Pastronaut")
      } action: {
        Button {
          appState.select(flags: [])
        } label: {
          Text("Start Queue", tableName: "Pastronaut")
        }
        .accessibilityIdentifier("queue-start")
      }
      .accessibilityIdentifier("queue-hint")
    }
  }
}

/// Seeing ⌘V in other apps (to move the queue on) needs Accessibility access, like pasting does. Without it
/// the first item stays on the clipboard and every ⌘V pastes it again.
enum QueuePermission {
  static var isGranted: Bool { AXIsProcessTrusted() }

  /// Shows the system's request and opens the switch's page (Privacy & Security › Accessibility; "Device
  /// Control and Data Access" from macOS 27). The request doesn't always add the app to that list (seen with
  /// the app in ~/Applications), so the app is also shown in Finder, ready to drag onto the list.
  static func request() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
  }
}
