import AppIntents
import PastronautCore
import SwiftUI
import WidgetKit

@main
struct PastronautWidgets: WidgetBundle {
  var body: some Widget {
    RecentClipsWidget()
    LatestClipAccessoryWidget()
    if #available(iOS 18.0, *) {
      SaveClipboardControl()
    }
  }
}

// MARK: - Data

struct ClipsEntry: TimelineEntry {
  let date: Date
  let clips: [Clip]
  let source: ClipSourceOption
  let isLocked: Bool
  /// The row a widget button just copied; shows a check mark for a moment.
  let copiedID: String?

  static let placeholder = ClipsEntry(
    date: .now,
    clips: [
      Clip(text: "https://developer.apple.com", sourceDevice: .mac),
      Clip(text: "Toplantı Perşembe 14:00'te", sourceDevice: .iphone),
      Clip(text: "#87CEEB", sourceDevice: .mac)
    ],
    source: .all,
    isLocked: false,
    copiedID: nil
  )
}

enum ClipsTimeline {
  static func entries(source: ClipSourceOption, count: Int) -> [ClipsEntry] {
    let now = Date.now
    let locked = SharedSettings.isAppLockEnabled
    let clips = locked ? [] : source.source.latest(from: SharedClipFiles()?.currentClips() ?? [], count: count)
    let defaults = SharedSettings.defaults
    var copiedID: String?
    if let copiedAt = defaults?.object(forKey: SharedSettings.widgetCopiedAtKey) as? Date,
       now.timeIntervalSince(copiedAt) < 3 {
      copiedID = defaults?.string(forKey: SharedSettings.widgetCopiedIDKey)
    }
    let entry = ClipsEntry(date: now, clips: clips, source: source, isLocked: locked, copiedID: copiedID)
    guard copiedID != nil else { return [entry] }
    // The check mark goes away after a moment.
    let plain = ClipsEntry(date: now.addingTimeInterval(2), clips: clips, source: source, isLocked: locked, copiedID: nil)
    return [entry, plain]
  }

  /// The app reloads widgets whenever the history changes; this is only a fallback.
  static func policy() -> TimelineReloadPolicy {
    .after(.now.addingTimeInterval(30 * 60))
  }

  static func rowCount(for family: WidgetFamily) -> Int {
    switch family {
    case .systemSmall: 1
    case .systemMedium: 3
    case .systemLarge: 7
    case .systemExtraLarge: 7
    default: 1
    }
  }
}

// MARK: - Home screen

struct RecentClipsConfiguration: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Recent Clips"
  static let description = IntentDescription("Your latest clips, each with a copy button.")

  @Parameter(title: "Show", default: .all)
  var source: ClipSourceOption
}

struct RecentClipsProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> ClipsEntry { .placeholder }

  func snapshot(for configuration: RecentClipsConfiguration, in context: Context) async -> ClipsEntry {
    if context.isPreview && (SharedClipFiles()?.currentClips().isEmpty ?? true) { return .placeholder }
    return ClipsTimeline.entries(source: configuration.source, count: ClipsTimeline.rowCount(for: context.family))[0]
  }

  func timeline(for configuration: RecentClipsConfiguration, in context: Context) async -> Timeline<ClipsEntry> {
    Timeline(
      entries: ClipsTimeline.entries(source: configuration.source, count: ClipsTimeline.rowCount(for: context.family)),
      policy: ClipsTimeline.policy()
    )
  }
}

struct RecentClipsWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "RecentClips", intent: RecentClipsConfiguration.self, provider: RecentClipsProvider()) {
      RecentClipsView(entry: $0)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Recent Clips")
    .description("Copy your latest clips without opening the app.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

struct RecentClipsView: View {
  let entry: ClipsEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    if entry.isLocked {
      MessageView(systemImage: "lock.fill", text: "Locked")
    } else if entry.clips.isEmpty {
      MessageView(systemImage: "tray", text: "No clips yet")
    } else if family == .systemSmall, let clip = entry.clips.first {
      SmallClipView(clip: clip, copied: entry.copiedID == clip.id)
    } else {
      VStack(alignment: .leading, spacing: 6) {
        Header(source: entry.source)
        ForEach(entry.clips, id: \.id) { clip in
          ClipWidgetRow(clip: clip, copied: entry.copiedID == clip.id)
        }
        Spacer(minLength: 0)
      }
    }
  }
}

private struct Header: View {
  let source: ClipSourceOption

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: source.systemImage)
      Text(source.title)
      Spacer()
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(.secondary)
  }
}

/// One clip: tapping the text opens the app, the button copies.
struct ClipWidgetRow: View {
  let clip: Clip
  let copied: Bool

  var body: some View {
    HStack(spacing: 8) {
      ClipIcon(content: clip.content, size: 26)
      Text(clip.preview)
        .font(.footnote)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      CopyButton(clipID: clip.id, copied: copied)
    }
  }
}

private struct SmallClipView: View {
  let clip: Clip
  let copied: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        ClipIcon(content: clip.content, size: 26)
        Spacer()
        Image(systemName: clip.isFromMac ? "laptopcomputer" : "iphone")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(clip.preview)
        .font(.footnote)
        .lineLimit(3)
        .frame(maxWidth: .infinity, alignment: .leading)
      Spacer(minLength: 0)
      CopyButton(clipID: clip.id, copied: copied, wide: true)
    }
  }
}

private struct CopyButton: View {
  let clipID: String
  let copied: Bool
  var wide = false

  var body: some View {
    Button(intent: CopyClipIntent(clipID: clipID)) {
      Group {
        if wide {
          Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
            .frame(maxWidth: .infinity)
        } else {
          Image(systemName: copied ? "checkmark" : "doc.on.doc")
            .accessibilityLabel(Text(copied ? "Copied" : "Copy"))
        }
      }
      .font(.footnote.weight(.semibold))
      .contentTransition(.symbolEffect(.replace))
    }
    .buttonStyle(.bordered)
    .buttonBorderShape(.capsule)
    .tint(copied ? .green : .accentColor)
  }
}

private struct MessageView: View {
  let systemImage: String
  let text: LocalizedStringKey

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.title2)
      Text(text)
        .font(.footnote)
    }
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

extension ClipSourceOption {
  var title: LocalizedStringKey {
    switch self {
    case .all: "Recent"
    case .mac: "From Mac"
    case .iphone: "From iPhone"
    case .pinned: "Pinned"
    }
  }

  var systemImage: String {
    switch self {
    case .all: "clock"
    case .mac: "laptopcomputer"
    case .iphone: "iphone"
    case .pinned: "pin"
    }
  }
}

// MARK: - Lock screen

struct LatestClipProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> ClipsEntry { .placeholder }

  func snapshot(for configuration: LatestClipConfiguration, in context: Context) async -> ClipsEntry {
    ClipsTimeline.entries(source: configuration.source, count: 1)[0]
  }

  func timeline(for configuration: LatestClipConfiguration, in context: Context) async -> Timeline<ClipsEntry> {
    Timeline(entries: ClipsTimeline.entries(source: configuration.source, count: 1), policy: ClipsTimeline.policy())
  }
}

struct LatestClipConfiguration: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Latest Clip"
  static let description = IntentDescription("Your most recent clip on the Lock Screen.")

  @Parameter(title: "Show", default: .mac)
  var source: ClipSourceOption
}

struct LatestClipAccessoryWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "LatestClip", intent: LatestClipConfiguration.self, provider: LatestClipProvider()) {
      LatestClipAccessoryView(entry: $0)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Latest Clip")
    .description("Your latest clip at a glance. Hidden while the iPhone is locked.")
    .supportedFamilies([.accessoryRectangular, .accessoryInline])
  }
}

struct LatestClipAccessoryView: View {
  let entry: ClipsEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    let clip = entry.clips.first
    switch family {
    case .accessoryInline:
      Label {
        if entry.isLocked {
          Text("Locked")
        } else if let clip {
          Text(verbatim: clip.preview)
        } else {
          Text("No clips yet")
        }
      } icon: {
        Image(systemName: entry.source.systemImage)
      }
      .privacySensitive()
    default:
      VStack(alignment: .leading, spacing: 2) {
        Label(entry.source.title, systemImage: entry.source.systemImage)
          .font(.caption2.weight(.semibold))
          .widgetAccentable()
        Group {
          if entry.isLocked {
            Text("Locked")
          } else if let clip {
            Text(verbatim: clip.preview)
          } else {
            Text("No clips yet")
          }
        }
        .font(.caption)
        .lineLimit(2)
        // Redacted while the iPhone itself is locked.
        .privacySensitive()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
