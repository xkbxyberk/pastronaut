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
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .foregroundStyle(tint)
      text()
        .lineLimit(1)
        .foregroundStyle(.secondary)
      Spacer(minLength: 4)
      action()
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
    if !history.searchQuery.isEmpty || history.deviceFilter != .all || !history.tokenFilter.isEmpty
      || history.collectionFilter != nil {
      Button {
        Self.reveal(item)
      } label: {
        Label { Text("Show in History", tableName: "Pastronaut") } icon: { Image(systemName: "list.bullet.below.rectangle") }
      }
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
