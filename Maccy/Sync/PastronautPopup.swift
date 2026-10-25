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

  var systemImage: String {
    switch self {
    case .all: "tray.full"
    case .mac: "laptopcomputer"
    case .iphone: "iphone"
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

extension HistoryItem {
  /// What the item is, as the filter menu sorts it: a PDF (also one copied with a picture of it), an image, files
  /// (PDF files count as PDFs), or the kind of its text.
  var clipKind: ClipKind? {
    if pdfData != nil { return .pdf }
    if imageData != nil { return .image }
    let files = fileURLs
    if !files.isEmpty {
      return files.allSatisfy { $0.pathExtension.lowercased() == "pdf" } ? .pdf : .file
    }
    return text.flatMap { $0.isEmpty ? nil : ClipContent($0).kind }
  }
}

extension ClipKind {
  /// The kind as a filter: "Links", "PDFs".
  var filterTitle: String {
    switch self {
    case .text: String(localized: "Text", table: "Pastronaut")
    case .link: String(localized: "Links", table: "Pastronaut")
    case .code: String(localized: "Code", table: "Pastronaut")
    case .email: String(localized: "Emails", table: "Pastronaut")
    case .phone: String(localized: "Phone Numbers", table: "Pastronaut")
    case .address: String(localized: "Addresses", table: "Pastronaut")
    case .color: String(localized: "Colors", table: "Pastronaut")
    case .image: String(localized: "Images", table: "Pastronaut")
    case .pdf: String(localized: "PDFs", table: "Pastronaut")
    case .file: String(localized: "Files", table: "Pastronaut")
    }
  }
}

extension History {
  /// The device filter, the filter menu's chips and the filters typed into the search, on top of the search.
  func passesFilters(_ item: HistoryItemDecorator) -> Bool {
    deviceFilter.includes(item)
      && kindFilter.map { item.item.clipKind == $0 } ?? true
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

/// The filter button next to the source: a Kind submenu (every kind in the history), the collections, pins and
/// dates, and Clear Filters. The Mac side of the iPhone's filter menu; what is chosen shows as chips under the
/// search (`ActiveFilterChips`).
struct ClipFilterMenu: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    let history = appState.history
    let isFiltering = history.hasPastronautFilters
    Menu {
      kindMenu
      CollectionFilterSection()
      Section {
        toggle(.pinned)
        toggle(.today)
        toggle(.thisWeek)
      }
      if isFiltering {
        Divider()
        Button {
          history.clearPastronautFilters()
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
      Image(systemName: "line.3.horizontal.decrease")
        .font(.system(size: 12, weight: .semibold))
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    // On the menu itself: a borderless menu drops what its label draws behind it.
    .tint(isFiltering ? Color.white : Color.primary)
    .foregroundStyle(isFiltering ? Color.white : Color.primary)
    .frame(width: 26, height: 26)
    .background(Circle().fill(isFiltering ? Color.accentColor : Color.primary.opacity(0.06)))
    .overlay(Circle().strokeBorder(Color.primary.opacity(isFiltering ? 0 : 0.1), lineWidth: 0.5))
    .contentShape(Circle())
    .fixedSize()
    .help(Text("Filter", tableName: "Pastronaut"))
    .accessibilityLabel(Text("Filter", tableName: "Pastronaut"))
    .accessibilityIdentifier("clip-filter-menu")
  }

  /// Kinds there are items of, with how many; the chosen one stays even when none are left.
  private var kindMenu: some View {
    let history = appState.history
    var counts: [ClipKind: Int] = [:]
    for decorator in history.allItems {
      if let kind = decorator.item.clipKind { counts[kind, default: 0] += 1 }
    }
    let kinds = ClipKind.allCases.filter { (counts[$0] ?? 0) > 0 || $0 == history.kindFilter }
    let title = history.kindFilter.map {
      String(localized: "Kind", table: "Pastronaut") + ": " + $0.filterTitle
    } ?? String(localized: "Kind", table: "Pastronaut")
    return Menu {
      Picker(selection: Binding(get: { history.kindFilter }, set: { history.kindFilter = $0 })) {
        Text("All Kinds", tableName: "Pastronaut").tag(ClipKind?.none)
        ForEach(kinds, id: \.self) { kind in
          Label {
            Text(verbatim: "\(kind.filterTitle)  ·  \(counts[kind] ?? 0)")
          } icon: {
            Image(systemName: kind.symbolName)
          }
          .tag(Optional(kind))
        }
      } label: {
        EmptyView()
      }
      .pickerStyle(.inline)
    } label: {
      Label { Text(verbatim: title) } icon: { Image(systemName: "square.grid.2x2") }
    }
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

extension History {
  /// A kind, a collection, or pin and date chips are chosen (the source has its own control).
  var hasPastronautFilters: Bool {
    kindFilter != nil || collectionFilter != nil || !tokenFilter.isEmpty
  }

  func clearPastronautFilters() {
    kindFilter = nil
    collectionFilter = nil
    tokenFilter = []
  }
}

/// What the filter menu chose, as removable chips under the search field. Nothing when no filter is on.
struct ActiveFilterChips: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    let history = appState.history
    if history.hasPastronautFilters {
      HStack(spacing: 6) {
        if let kind = history.kindFilter {
          chip(kind.filterTitle, systemImage: kind.symbolName) { history.kindFilter = nil }
        }
        if let id = history.collectionFilter, let collection = SyncedCollections.shared.collection(withID: id) {
          chip(collection.name, systemImage: "folder") { history.collectionFilter = nil }
        }
        ForEach(history.tokenFilter, id: \.self) { token in
          chip(token.title, systemImage: token.systemImage) { history.tokenFilter.removeAll { $0 == token } }
        }
        Spacer(minLength: 0)
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("active-filters")
    }
  }

  private func chip(_ title: String, systemImage: String, remove: @escaping () -> Void) -> some View {
    Button(action: remove) {
      HStack(spacing: 4) {
        Image(systemName: systemImage)
          .foregroundStyle(.secondary)
        Text(verbatim: title)
          .lineLimit(1)
        Image(systemName: "xmark")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.secondary)
      }
      .font(.system(size: 11, weight: .semibold))
      .padding(.horizontal, 8)
      .frame(height: 22)
      .background(Capsule().fill(Color.primary.opacity(0.06)))
      .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .help(Text("Remove this filter", tableName: "Pastronaut"))
    .accessibilityLabel(Text(verbatim: title))
    .accessibilityHint(Text("Remove this filter", tableName: "Pastronaut"))
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

/// All (symbol and name), This Mac and iPhone (symbols) in one capsule, and the filter button beside it.
struct DeviceFilterPicker: View {
  @Environment(AppState.self) private var appState
  @Namespace private var selectionNamespace

  var body: some View {
    HStack(spacing: 6) {
      HStack(spacing: 0) {
        ForEach(DeviceFilter.allCases) { filter in
          segment(filter)
        }
      }
      .padding(2)
      .background(Capsule().fill(Color.primary.opacity(0.06)))
      .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("device-filter")
      ClipFilterMenu()
    }
    // The capsule keeps its size; the search field gives way.
    .fixedSize()
  }

  private func segment(_ filter: DeviceFilter) -> some View {
    let isSelected = appState.history.deviceFilter == filter
    return Button {
      withAnimation(.snappy(duration: 0.25)) { appState.history.deviceFilter = filter }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: filter.systemImage)
          .font(.system(size: 11, weight: .semibold))
        if filter == .all {
          Text(verbatim: filter.title)
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
        }
      }
      .foregroundStyle(isSelected ? Color.white : Color.primary)
      .padding(.horizontal, filter == .all ? 9 : 8)
      .frame(height: 22)
      .background {
        if isSelected {
          Capsule()
            .fill(Color.accentColor)
            .matchedGeometryEffect(id: "selectedSource", in: selectionNamespace)
        }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .help(Text(verbatim: filter.title))
    .accessibilityLabel(Text(verbatim: filter.title))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - Rows

/// Text and file items get a colored kind icon (a swatch for colors) and a line saying where and when they were
/// copied. Images keep Maccy's thumbnail.
struct ClipRowInfo {
  let kind: ClipKind
  /// nil for files, pictures and PDFs.
  let content: ClipContent?
  let subtitle: String
  let fromIPhone: Bool
  /// Its image or files stay on this Mac.
  let isLocalOnly: Bool
  /// What the row says when its own title is empty or a path: a picture copied without a name ("Picture 1944 ×
  /// 1222"), or a row from before 1.3.
  let name: String?
  /// The small picture shows (only rows with a picture have one; `MediaRowStyle`).
  let showsPicture: Bool
  /// The kind's icon shows: always for text and files, for pictures as `MediaRowStyle` says.
  let showsIcon: Bool
  /// Copied on the iPhone, which never says in which app: the app icon column shows the iPhone instead of Maccy's
  /// question mark.
  let showsIPhoneBadge: Bool

  @MainActor
  init?(_ decorator: HistoryItemDecorator) {
    let item = decorator.item
    let imageData = item.imageData
    let isPDF = item.pdfData != nil
      || (!item.fileURLs.isEmpty && item.fileURLs.allSatisfy { $0.pathExtension.lowercased() == "pdf" })
    if imageData != nil {
      // A picture, or a PDF shown by its first page (1.3: named and dated like files, `MediaRowStyle`).
      kind = isPDF ? .pdf : .image
      content = nil
    } else if !item.fileURLs.isEmpty {
      kind = isPDF ? .pdf : .file
      content = nil
    } else if let text = item.text, !text.isEmpty {
      let content = ClipContent(text)
      self.content = content
      kind = content.kind
    } else {
      return nil
    }
    let style = imageData == nil ? nil : Defaults[.mediaRowStyle]
    showsPicture = style == .previewAndName
    showsIcon = style == nil || style == .iconAndName
    if !item.title.isEmpty, !item.title.hasPrefix("file://") {
      name = nil
    } else if !item.fileURLs.isEmpty {
      name = item.fileURLs.map(\.lastPathComponent).joined(separator: ", ")
    } else if kind == .pdf {
      name = String(localized: "PDF Document", table: "Pastronaut")
    } else if let size = imageData.flatMap(MediaProcessing.pixelSize(of:)) {
      name = SyncBridge.pictureTitle(width: size.width, height: size.height)
    } else {
      name = nil
    }
    fromIPhone = item.isFromIPhone
    showsIPhoneBadge = fromIPhone && item.application == nil
    isLocalOnly = item.isLocalOnlyMedia
    let when = item.lastCopiedAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    // The app recorded for a Universal Clipboard copy is only what was frontmost here, so leave it out.
    let app = fromIPhone ? nil : item.application.flatMap(AppNames.name(for:))
    let localOnly = isLocalOnly ? String(localized: "Only on This Mac", table: "Pastronaut") : nil
    subtitle = [app, when, localOnly].compactMap { $0 }.joined(separator: " · ")
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

/// In the app icon column, for a copy made on the iPhone: an iPhone on a gray tile, the size of an app icon.
struct IPhoneBadge: View {
  var size: CGFloat = 15

  var body: some View {
    // App icons leave a margin around their tile (about 8%); the badge keeps the same one, so both look one size.
    let tile = size * 0.84
    RoundedRectangle(cornerRadius: tile * 0.24, style: .continuous)
      .fill(LinearGradient(colors: [Color(white: 0.62), Color(white: 0.45)], startPoint: .top, endPoint: .bottom))
      .overlay {
        Image(systemName: "iphone")
          .font(.system(size: tile * 0.62, weight: .semibold))
          .foregroundStyle(.white)
      }
      .frame(width: tile, height: tile)
      .frame(width: size, height: size)
      .accessibilityHidden(true)
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

