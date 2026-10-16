import AppKit
import Defaults
import PastronautCore
import SwiftHEXColors
import SwiftUI

// Pastronaut's additions to Maccy's popup: device of origin, device filter, content icons, day sections and
// the sync status line. Strings live in the "Pastronaut" table (Pastronaut.xcstrings).

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

struct DeviceFilterPicker: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    @Bindable var history = appState.history
    Picker(selection: $history.deviceFilter) {
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

/// Text items get a content icon (a swatch for colors) and a line saying where and when they were copied.
struct ClipRowInfo {
  let content: ClipContent
  let subtitle: String
  let fromIPhone: Bool

  @MainActor
  init?(_ decorator: HistoryItemDecorator) {
    let item = decorator.item
    guard item.imageData == nil, item.fileURLs.isEmpty, let text = item.text, !text.isEmpty else { return nil }
    content = ClipContent(text)
    fromIPhone = item.isFromIPhone
    let when = item.lastCopiedAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    // The app recorded for a Universal Clipboard copy is only what was frontmost here, so leave it out.
    let app = fromIPhone ? nil : item.application.flatMap(AppNames.name(for:))
    subtitle = [app, when].compactMap { $0 }.joined(separator: " · ")
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

/// Rounded tile with the content type's symbol, or a swatch for colors. Mirrors the iOS app's icon.
struct ClipContentIcon: View {
  let content: ClipContent
  var isSelected = false
  var size: CGFloat = 22

  var body: some View {
    RoundedRectangle(cornerRadius: size / 4, style: .continuous)
      .fill(isSelected ? Color.white.opacity(0.22) : Color.accentColor.opacity(0.16))
      .frame(width: size, height: size)
      .overlay {
        if case .color(let hex) = content, let color = NSColor(hexString: hex) {
          RoundedRectangle(cornerRadius: size / 6, style: .continuous)
            .fill(Color(nsColor: color))
            .frame(width: size * 0.58, height: size * 0.58)
        } else {
          Image(systemName: content.symbolName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : Color.accentColor)
        }
      }
      .accessibilityHidden(true)
  }
}

extension ClipContent {
  var symbolName: String {
    switch self {
    case .link: "link"
    case .email: "envelope"
    case .phone: "phone"
    case .color: "paintpalette"
    case .code: "chevron.left.forwardslash.chevron.right"
    case .text: "text.alignleft"
    }
  }

  var kindName: String {
    switch self {
    case .link: String(localized: "Link", table: "Pastronaut")
    case .email: String(localized: "Email", table: "Pastronaut")
    case .phone: String(localized: "Phone", table: "Pastronaut")
    case .color: String(localized: "Color", table: "Pastronaut")
    case .code: String(localized: "Code", table: "Pastronaut")
    case .text: String(localized: "Text", table: "Pastronaut")
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
