import AppKit
import Defaults
import PastronautCore
import SwiftHEXColors
import SwiftUI

// Pastronaut's additions to Maccy's popup: device of origin, device filter, content icons, day sections and
// the sync status line. Strings live in the "Pastronaut" table (Pastronaut.xcstrings).

// `Color.brand` comes from the BrandColor asset (generated asset symbol): deep sky in light mode, the sky blue
// itself in dark mode (Gökyüzü palette).

// MARK: - Device of origin

extension NSPasteboard.PasteboardType {
  /// Marks history items that arrived from an iPhone through iCloud sync. Stored with the item on this Mac
  /// only; it lets the popup badge them and keeps them iPhone clips when this Mac changes them.
  nonisolated static let pastronautFromIPhone = NSPasteboard.PasteboardType("com.xkbxyberk.pastronaut.from-iphone")
}

extension HistoryItem {
  /// Copied on an iPhone: through Universal Clipboard, or through iCloud sync.
  var isFromIPhone: Bool {
    universalClipboard
      || contents.contains { $0.type == NSPasteboard.PasteboardType.pastronautFromIPhone.rawValue }
  }
}

enum DeviceFilter: String, CaseIterable, Identifiable {
  case all
  case mac
  case iphone

  var id: Self { self }

  var title: String {
    switch self {
    case .all: String(localized: "All", table: "Pastronaut")
    case .mac: String(localized: "This Mac", table: "Pastronaut")
    case .iphone: String(localized: "iPhone", table: "Pastronaut")
    }
  }

  func includes(_ item: HistoryItemDecorator) -> Bool {
    switch self {
    case .all: true
    case .mac: !item.item.isFromIPhone
    case .iphone: item.item.isFromIPhone
    }
  }
}

extension History {
  /// The device filter, the filter menu's chips and the filters typed into the search, on top of the search.
  func passesFilters(_ item: HistoryItemDecorator) -> Bool {
    deviceFilter.includes(item)
      && collectionFilter.map { SyncedCollections.shared.contains(item.item, in: $0) } ?? true
      && ClipSearchToken.allMatch(
      tokenFilter,
      text: item.item.imageData == nil && item.item.fileURLs.isEmpty ? item.item.text : nil,
      pinned: item.isPinned,
      lastCopiedAt: item.item.lastCopiedAt
    )
      && passesTypedFilters(item)
  }

  /// `app:`, `type:`, `date:` and `from:` from the search field (ClipQuery), parsed once per query.
  var typedFilters: ClipQuery {
    if let (query, parsed) = Self.lastTypedFilters, query == searchQuery { return parsed }
    let parsed = ClipQuery.parse(searchQuery)
    Self.lastTypedFilters = (searchQuery, parsed)
    return parsed
  }

  nonisolated(unsafe) private static var lastTypedFilters: (String, ClipQuery)?

  private func passesTypedFilters(_ item: HistoryItemDecorator) -> Bool {
    let query = typedFilters
    guard query.hasFilters else { return true }
    if let device = query.device, (device == .iphone) != item.item.isFromIPhone { return false }
    if !query.matchesDay(item.item.lastCopiedAt) { return false }
    if query.app != nil {
      let bundle = item.item.application
      guard query.matchesApp(name: bundle.flatMap { AppNames.name(for: $0) }, bundleIdentifier: bundle) else {
        return false
      }
    }
    if !query.kinds.isEmpty {
      let kind: ClipKind? = if item.item.imageData != nil {
        .image
      } else if !item.item.fileURLs.isEmpty {
        .file
      } else {
        item.item.text.map { ClipContent($0).kind }
      }
      guard let kind, query.kinds.contains(kind) else { return false }
    }
    return true
  }
}

/// Kind, date and pin chips in a menu next to the device filter, the Mac side of the iPhone's search chips.
struct ClipFilterMenu: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    let tokens = appState.history.tokenFilter
    let isFiltering = !tokens.isEmpty || appState.history.collectionFilter != nil
    Menu {
      CollectionFilterSection()
      Section {
        toggle(.pinned)
        toggle(.today)
        toggle(.thisWeek)
      }
      Section {
        ForEach([ClipSearchToken.link, .email, .phone, .address, .color, .code, .text], id: \.self, content: toggle)
      }
      if isFiltering {
        Divider()
        Button {
          appState.history.tokenFilter = []
          appState.history.collectionFilter = nil
        } label: {
          Text("Clear Filters", tableName: "Pastronaut")
        }
      }
      Section {
        Text("app:Safari · type:link · date:yesterday · from:iphone", tableName: "Pastronaut")
      } header: {
        Text("Or type in the search", tableName: "Pastronaut")
      }
    } label: {
      Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        .foregroundStyle(isFiltering ? Color.accentColor : Color.secondary)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .help(Text("Filter", tableName: "Pastronaut"))
    .accessibilityLabel(Text("Filter", tableName: "Pastronaut"))
    .accessibilityIdentifier("clip-filter-menu")
  }

  private func toggle(_ token: ClipSearchToken) -> some View {
    Toggle(isOn: Binding(
      get: { appState.history.tokenFilter.contains(token) },
      set: { isOn in
        if isOn {
          appState.history.tokenFilter.append(token)
        } else {
          appState.history.tokenFilter.removeAll { $0 == token }
        }
      }
    )) {
      Label { Text(verbatim: token.title) } icon: { Image(systemName: token.systemImage) }
    }
  }
}

extension ClipSearchToken {
  var title: String {
    switch self {
    case .pinned: String(localized: "Pinned", table: "Pastronaut")
    case .today: String(localized: "Today", table: "Pastronaut")
    case .thisWeek: String(localized: "This Week", table: "Pastronaut")
    case .link: String(localized: "Links", table: "Pastronaut")
    case .email: String(localized: "Emails", table: "Pastronaut")
    case .phone: String(localized: "Phone Numbers", table: "Pastronaut")
    case .color: String(localized: "Colors", table: "Pastronaut")
    case .address: String(localized: "Addresses", table: "Pastronaut")
    case .code: String(localized: "Code", table: "Pastronaut")
    case .text: String(localized: "Text", table: "Pastronaut")
    case .image: String(localized: "Images", table: "Pastronaut")
    case .file: String(localized: "Files", table: "Pastronaut")
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

struct DeviceFilterPicker: View {
  @Environment(AppState.self) private var appState
  @Namespace private var glassNamespace

  var body: some View {
    if #available(macOS 26.0, *) {
      // Glass capsules; the tinted selection flows between them.
      HStack(spacing: 6) {
        GlassEffectContainer(spacing: 6) {
          HStack(spacing: 4) {
            ForEach(DeviceFilter.allCases) { filter in
              chip(filter)
            }
          }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("device-filter")
        ClipFilterMenu()
      }
      // The chips keep their size; the search field gives way.
      .fixedSize()
    } else {
      HStack(spacing: 4) {
        segmented
        ClipFilterMenu()
      }
    }
  }

  @available(macOS 26.0, *)
  private func chip(_ filter: DeviceFilter) -> some View {
    let isSelected = appState.history.deviceFilter == filter
    return Button {
      withAnimation(.bouncy(duration: 0.3)) { appState.history.deviceFilter = filter }
    } label: {
      Text(verbatim: filter.title)
        .lineLimit(1)
        .font(.callout.weight(isSelected ? .semibold : .regular))
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .glassEffect(isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: Capsule())
    .glassEffectID(filter, in: glassNamespace)
    .accessibilityLabel(Text(verbatim: filter.title))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var segmented: some View {
    @Bindable var history = appState.history
    return Picker(selection: $history.deviceFilter) {
      ForEach(DeviceFilter.allCases) { filter in
        Text(verbatim: filter.title).tag(filter)
      }
    } label: {
      Text("Device", tableName: "Pastronaut")
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .fixedSize()
    .controlSize(.small)
    .accessibilityIdentifier("device-filter")
  }
}

// MARK: - Rows

/// Text and file items get a colored kind icon (a swatch for colors) and a line saying where and when they were
/// copied. Images keep Maccy's thumbnail.
struct ClipRowInfo {
  let kind: ClipKind
  /// nil for files.
  let content: ClipContent?
  let subtitle: String
  let fromIPhone: Bool

  @MainActor
  init?(_ decorator: HistoryItemDecorator) {
    let item = decorator.item
    guard item.imageData == nil else { return nil }
    if !item.fileURLs.isEmpty {
      kind = .file
      content = nil
    } else if let text = item.text, !text.isEmpty {
      let content = ClipContent(text)
      self.content = content
      kind = content.kind
    } else {
      return nil
    }
    fromIPhone = item.isFromIPhone
    let when = item.lastCopiedAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    // The app recorded for a Universal Clipboard copy is only what was frontmost here, so leave it out.
    let app = fromIPhone ? nil : item.application.flatMap(AppNames.name(for:))
    subtitle = [app, when].compactMap { $0 }.joined(separator: " · ")
  }

  var colorHex: String? {
    if case .color(let hex)? = content { return hex }
    return nil
  }
}

@MainActor
enum AppNames {
  private static var cache: [String: String] = [:]

  static func name(for bundleIdentifier: String) -> String? {
    if let name = cache[bundleIdentifier] { return name }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
    let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    cache[bundleIdentifier] = name
    return name
  }
}

/// The kind's symbol on a soft circle of the kind's color ("colored icon"), or a swatch for colors. On a selected
/// row the circle turns white and keeps the kind's color, so the kind stays readable. Same colors as the iPhone.
struct ClipContentIcon: View {
  let kind: ClipKind
  var colorHex: String?
  var isSelected = false
  var size: CGFloat = 22

  var body: some View {
    ZStack {
      if let hex = colorHex, let color = NSColor(hexString: hex) {
        Circle()
          .fill(Color(nsColor: color))
          .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
          .overlay(Circle().strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 1.5))
      } else {
        Circle()
          .fill(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(kind.tint.opacity(0.18)))
        Image(systemName: kind.symbolName)
          .font(.system(size: size * 0.46, weight: .semibold))
          .foregroundStyle(isSelected ? kind.deepTint : kind.tint)
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

extension ClipKind {
  var title: String {
    switch self {
    case .text: String(localized: "Text", table: "Pastronaut")
    case .link: String(localized: "Link", table: "Pastronaut")
    case .code: String(localized: "Code", table: "Pastronaut")
    case .email: String(localized: "Email", table: "Pastronaut")
    case .phone: String(localized: "Phone", table: "Pastronaut")
    case .address: String(localized: "Address", table: "Pastronaut")
    case .color: String(localized: "Color", table: "Pastronaut")
    case .image: String(localized: "Image", table: "Pastronaut")
    case .pdf: String(localized: "PDF", table: "Pastronaut")
    case .file: String(localized: "File", table: "Pastronaut")
    }
  }
}

// MARK: - Sections

enum HistorySections {
  /// Day headings only make sense while the list is ordered by date and not narrowed by a search.
  @MainActor
  static var isEnabled: Bool {
    Defaults[.sortBy] != .numberOfCopies && AppState.shared.history.searchQuery.isEmpty
  }

  /// The heading to show above `item`, or nil when it belongs to the same day group as `previous`.
  @MainActor
  static func title(for item: HistoryItemDecorator, after previous: HistoryItemDecorator?) -> String? {
    guard isEnabled else { return nil }
    let group = group(of: date(of: item))
    guard previous.map({ group != Self.group(of: date(of: $0)) }) ?? true else { return nil }
    return group.title
  }

  @MainActor
  private static func date(of item: HistoryItemDecorator) -> Date {
    Defaults[.sortBy] == .firstCopiedAt ? item.item.firstCopiedAt : item.item.lastCopiedAt
  }

  enum Group: Equatable {
    case today, yesterday, week, earlier

    var title: String {
      switch self {
      case .today: String(localized: "Today", table: "Pastronaut")
      case .yesterday: String(localized: "Yesterday", table: "Pastronaut")
      case .week: String(localized: "This Week", table: "Pastronaut")
      case .earlier: String(localized: "Earlier", table: "Pastronaut")
      }
    }
  }

  static func group(of date: Date, now: Date = .now, calendar: Calendar = .current) -> Group {
    if calendar.isDate(date, inSameDayAs: now) { return .today }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
      return .yesterday
    }
    let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) ?? now
    return date >= weekAgo ? .week : .earlier
  }
}

struct HistorySectionHeader: View {
  let title: String

  var body: some View {
    Text(verbatim: title)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, 10)
      .padding(.top, 8)
      .padding(.bottom, 3)
      .accessibilityAddTraits(.isHeader)
  }
}

// MARK: - Sync status

/// "● Synced · 2 sec ago" above the footer while iCloud sync is on.
struct SyncStatusLine: View {
  @Default(.iCloudSync) private var isEnabled
  @State private var status: SyncStatus?

  private var isVisible: Bool {
    #if DEBUG
    // Tests run with isolated history; the real sync setting and counts would only confuse them.
    if AppDelegate.isTesting { return false }
    #endif
    return isEnabled
  }

  var body: some View {
    if isVisible {
      HStack(spacing: 6) {
        Circle()
          .fill(status?.lastError == nil ? Color.green : Color.orange)
          .frame(width: 7, height: 7)
        Group {
          if let error = status?.lastError {
            Text(verbatim: error)
          } else if let date = status?.lastSyncAt {
            Text("Synced \(date.formatted(.relative(presentation: .named)))", tableName: "Pastronaut")
          } else {
            Text("Syncing…", tableName: "Pastronaut")
          }
        }
        .lineLimit(1)
        Spacer(minLength: 4)
        if let count = status?.syncedClips {
          Text("\(count) in iCloud", tableName: "Pastronaut")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 10)
      .padding(.bottom, Popup.verticalSeparatorPadding)
      .task {
        while !Task.isCancelled {
          status = await SyncBridge.shared.status()
          try? await Task.sleep(for: .seconds(5))
        }
      }
      .accessibilityElement(children: .combine)
    }
  }
}

// MARK: - Selection

/// On macOS 26 and later a single selected row is tinted Liquid Glass instead of a flat fill. Rows joined by a
/// multiple selection keep Maccy's connected flat shape.
struct GlassSelection: ViewModifier {
  let isSelected: Bool
  let appearance: SelectionAppearance

  /// Whether a selected row with this appearance is drawn as glass (then it gets no flat fill).
  static func isUsed(for appearance: SelectionAppearance) -> Bool {
    if #available(macOS 26.0, *) { return appearance == .none }
    return false
  }

  func body(content: Content) -> some View {
    if #available(macOS 26.0, *), isSelected, appearance == .none {
      content.glassEffect(
        .regular.tint(Color.accentColor.opacity(0.85)).interactive(),
        in: RoundedRectangle(cornerRadius: Popup.cornerRadius, style: .continuous)
      )
    } else {
      content
    }
  }
}

