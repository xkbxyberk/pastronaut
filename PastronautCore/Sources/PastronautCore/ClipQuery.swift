import Foundation

/// Filters typed into the search field next to the words to find: `app:Safari`, `type:link`, `date:yesterday`,
/// `from:iphone`, with Turkish keys and values too (`uygulama:`, `tür:bağlantı`, `tarih:dün`, `cihaz:iphone`).
/// Values with spaces go in quotes (`app:"Google Chrome"`). Anything that isn't a known key and value stays a
/// word to find, so "https://…" or "10:30" search as before.
public struct ClipQuery: Equatable, Sendable {
  public enum Day: String, Sendable {
    case today, yesterday, thisWeek
  }

  public enum Device: String, Sendable {
    case mac, iphone
  }

  /// The words to find, filters removed.
  public var text: String = ""
  /// Any of these kinds (empty: all).
  public var kinds: Set<ClipKind> = []
  /// Part of the app's name or bundle identifier, folded like `fold`.
  public var app: String?
  public var day: Day?
  public var device: Device?

  public init() {}

  public var hasFilters: Bool {
    !kinds.isEmpty || app != nil || day != nil || device != nil
  }

  public static func parse(_ query: String) -> ClipQuery {
    var result = ClipQuery()
    var words: [String] = []
    for term in terms(query) {
      if !result.apply(term) {
        words.append(term)
      }
    }
    // Without filters the text stays exactly as typed (spaces matter to Maccy's exact and regex search).
    result.text = result.hasFilters ? words.joined(separator: " ") : query
    return result
  }

  public func matchesDay(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
    switch day {
    case nil:
      return true
    case .today:
      return calendar.isDate(date, inSameDayAs: now)
    case .yesterday:
      guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return false }
      return calendar.isDate(date, inSameDayAs: yesterday)
    case .thisWeek:
      let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
      return date >= start
    }
  }

  /// `name` is the app's display name, `bundleIdentifier` its identifier; either may contain the filter.
  public func matchesApp(name: String?, bundleIdentifier: String?) -> Bool {
    guard let app else { return true }
    return [name, bundleIdentifier].contains { $0.map { Self.fold($0).contains(app) } ?? false }
  }

  // MARK: - Parsing

  /// Splits on spaces, keeping `key:"two words"` together.
  static func terms(_ query: String) -> [String] {
    var terms: [String] = []
    var current = ""
    var quoted = false
    for character in query {
      if character == "\"" {
        quoted.toggle()
      } else if character == " " && !quoted {
        if !current.isEmpty { terms.append(current) }
        current = ""
      } else {
        current.append(character)
      }
    }
    if !current.isEmpty { terms.append(current) }
    return terms
  }

  /// Applies `key:value` if both are known; false leaves the term a word to find.
  private mutating func apply(_ term: String) -> Bool {
    guard let colon = term.firstIndex(of: ":"), colon != term.startIndex else { return false }
    let key = Self.fold(String(term[..<colon]))
    let value = Self.fold(String(term[term.index(after: colon)...]))
    guard !value.isEmpty else { return false }
    switch key {
    case "app", "uygulama":
      app = value
    case "type", "kind", "tur":
      guard let kind = Self.kinds[value] else { return false }
      kinds.insert(kind)
    case "date", "tarih":
      guard let day = Self.days[value] else { return false }
      self.day = day
    case "from", "device", "cihaz", "kaynak":
      guard let device = Self.devices[value] else { return false }
      self.device = device
    default:
      return false
    }
    return true
  }

  static let kinds: [String: ClipKind] = [
    "link": .link, "links": .link, "url": .link, "baglanti": .link,
    "email": .email, "mail": .email, "eposta": .email, "e-posta": .email,
    "phone": .phone, "tel": .phone, "telefon": .phone,
    "color": .color, "colour": .color, "renk": .color,
    "address": .address, "adres": .address,
    "code": .code, "kod": .code,
    "text": .text, "metin": .text, "yazi": .text,
    "image": .image, "img": .image, "photo": .image, "gorsel": .image, "resim": .image, "foto": .image,
    "file": .file, "dosya": .file
  ]

  static let days: [String: Day] = [
    "today": .today, "bugun": .today,
    "yesterday": .yesterday, "dun": .yesterday,
    "week": .thisWeek, "thisweek": .thisWeek, "hafta": .thisWeek, "buhafta": .thisWeek
  ]

  static let devices: [String: Device] = [
    "mac": .mac, "iphone": .iphone, "ios": .iphone, "phone": .iphone, "telefon": .iphone
  ]

  /// Lower case, accents and Turkish letters folded to ASCII ("Tür" → "tur", "Bağlantı" → "baglanti").
  static func fold(_ text: String) -> String {
    text.lowercased(with: Locale(identifier: "tr_TR"))
      .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
      .replacingOccurrences(of: "ı", with: "i")
  }
}
