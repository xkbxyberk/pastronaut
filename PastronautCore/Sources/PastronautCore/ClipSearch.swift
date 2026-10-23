import Foundation

/// A filter chip in the iPhone app's search field. Chips of the same group widen the search (link or email);
/// chips of different groups narrow it (pinned and a link).
public enum ClipSearchToken: String, CaseIterable, Hashable, Identifiable, Sendable {
  case pinned
  case today
  case thisWeek
  case link
  case email
  case phone
  case color
  case address
  case code
  case text
  /// Since 1.3: images; PDFs and other files.
  case image
  case file

  public var id: Self { self }

  enum Group { case pin, date, kind }

  var group: Group {
    switch self {
    case .pinned: .pin
    case .today, .thisWeek: .date
    case .link, .email, .phone, .color, .address, .code, .text, .image, .file: .kind
    }
  }

  public func matches(_ clip: Clip, now: Date = .now, calendar: Calendar = .current) -> Bool {
    switch group {
    case .kind: kind(of: ClipContent(clip: clip))
    case .pin, .date: matches(text: nil, pinned: clip.pinned, lastCopiedAt: clip.lastCopiedAt, now: now, calendar: calendar)
    }
  }

  /// `text` is nil for images and files on the Mac: they match pin and date chips, never a kind.
  public func matches(text: String?, pinned: Bool, lastCopiedAt: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
    switch self {
    case .pinned:
      return pinned
    case .today:
      return calendar.isDate(lastCopiedAt, inSameDayAs: now)
    case .thisWeek:
      let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
      return lastCopiedAt >= start
    case .link, .email, .phone, .color, .address, .code, .text, .image, .file:
      return text.map { kind(of: ClipContent($0)) } ?? false
    }
  }

  /// Chips of one group widen, groups narrow (see the type's comment). No chips match everything.
  public static func allMatch(_ tokens: [ClipSearchToken], clip: Clip, now: Date = .now, calendar: Calendar = .current) -> Bool {
    Dictionary(grouping: tokens, by: \.group).values.allSatisfy { group in
      group.contains { $0.matches(clip, now: now, calendar: calendar) }
    }
  }

  public static func allMatch(
    _ tokens: [ClipSearchToken],
    text: String?,
    pinned: Bool,
    lastCopiedAt: Date,
    now: Date = .now,
    calendar: Calendar = .current
  ) -> Bool {
    Dictionary(grouping: tokens, by: \.group).values.allSatisfy { group in
      group.contains { $0.matches(text: text, pinned: pinned, lastCopiedAt: lastCopiedAt, now: now, calendar: calendar) }
    }
  }

  private func kind(of content: ClipContent) -> Bool {
    switch (self, content) {
    case (.link, .link), (.email, .email), (.phone, .phone), (.color, .color), (.address, .address), (.code, .code),
         (.text, .text), (.image, .image), (.file, .pdf), (.file, .file):
      true
    default:
      false
    }
  }
}

public extension Collection<Clip> {
  /// Clips containing `query` (case and accent insensitive) that match the tokens.
  func matching(
    _ query: String,
    tokens: [ClipSearchToken] = [],
    now: Date = .now,
    calendar: Calendar = .current
  ) -> [Clip] {
    let query = Self.searchKey(query.trimmingCharacters(in: .whitespacesAndNewlines))
    return filter { clip in
      (query.isEmpty || clip.searchableTexts.contains { Self.searchKey($0).contains(query) })
        && ClipSearchToken.allMatch(tokens, clip: clip, now: now, calendar: calendar)
    }
  }

  /// Lowercased without accents. Turkish dotless ı counts as i: people often type "toplanti" for "Toplantı",
  /// and ı is a letter of its own, not an accented i, so folding alone keeps them apart.
  private static func searchKey(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
      .lowercased()
      .replacingOccurrences(of: "ı", with: "i")
  }
}

/// Which clips a widget or Shortcuts action looks at.
public enum ClipSource: String, CaseIterable, Codable, Sendable {
  case all
  case mac
  case iphone
  case pinned

  public func includes(_ clip: Clip) -> Bool {
    switch self {
    case .all: true
    case .mac: clip.sourceDevice == .mac
    case .iphone: clip.sourceDevice != .mac
    case .pinned: clip.pinned
    }
  }

  /// Newest copies first; pinned clips are not moved to the top, since "latest" means the last copy.
  public func latest(from clips: some Collection<Clip>, count: Int) -> [Clip] {
    Array(clips.filter(includes).sorted { $0.lastCopiedAt > $1.lastCopiedAt }.prefix(count))
  }
}

extension Clip {
  /// What a search looks in: the text and the title, and for media the text read from it and the file names.
  var searchableTexts: [String] {
    [text, title, media?.recognizedText].compactMap { $0 } + (media?.files.map(\.name) ?? [])
  }
}
