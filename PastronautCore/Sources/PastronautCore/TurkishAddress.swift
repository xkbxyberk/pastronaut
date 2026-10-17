import Foundation

/// Recognizes Turkish postal addresses, which the system's data detector mostly misses: numbered streets
/// ("286/1 Sok."), a neighbourhood first ("Mansuroğlu Mah."), building, floor and flat ("Kat: 3, Daire: 12"), and the
/// district and province after a slash ("Bayraklı / İzmir"). Works on the device, offline.
public enum TurkishAddress {
  /// A street-level word and at least one of: a door number, a postal code, a province.
  public static func looksLikeAddress(_ text: String) -> Bool {
    let folded = fold(text)
    guard folded.count <= 300, text.split(separator: "\n").count <= 5, !folded.contains("http") else { return false }
    guard matches(streetPattern, in: folded) else { return false }
    return matches(numberPattern, in: folded) || matches(postalPattern, in: folded) || containsProvince(folded)
  }

  /// Simpler versions of an address for the map lookup, best first: the whole text on one line, then without
  /// building, floor and flat, then only the district and province (or postal code and province).
  public static func geocodingCandidates(for text: String) -> [String] {
    let oneLine = text
      .split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
    var candidates = [oneLine]
    let detailPattern = #"(?i)\b[\p{L}\d ]*(apartman[ıi]|apt\.?|sitesi|blok)\b[^,]*,?|\b(kat|daire|d|k)\s*[:.]\s*\d+\w*,?"#
    let withoutDetails = oneLine
      .replacingOccurrences(of: detailPattern, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\s*,\s*,+"#, with: ",", options: .regularExpression)
      .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
    candidates.append(withoutDetails)
    // "35535 Bayraklı / İzmir" or "Bayraklı/İzmir": the last line, or the part with the slash.
    if let last = text.split(whereSeparator: \.isNewline).last.map(String.init), last != text {
      candidates.append(last.trimmingCharacters(in: .whitespaces))
    }
    if let slash = oneLine.range(of: #"[\p{L}]+\s*/\s*[\p{L}]+"#, options: .regularExpression) {
      candidates.append(String(oneLine[slash]))
    }
    var seen = Set<String>()
    return candidates.filter { !$0.isEmpty && seen.insert($0).inserted }
  }

  // MARK: - Rules

  /// Lower case, Turkish letters folded to ASCII ("Güneş Apartmanı" → "gunes apartmani").
  static func fold(_ text: String) -> String {
    text.lowercased(with: Locale(identifier: "tr_TR"))
      .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
      .replacingOccurrences(of: "ı", with: "i")
  }

  static let streetPattern =
    #"\b(mah|mahalle|mahallesi|cad|cd|cadde|caddesi|sok|sk|sokak|sokagi|bulvar|bulvari|blv|yolu|meydani|apt|apartmani|sitesi|koyu|mevkii)\b"#
  /// "No: 4", "no 12", "286/1", "Kat: 3", "D: 12".
  static let numberPattern = #"\bno\s*[:.]?\s*\d+|\b\d+/\d+\b|\b(kat|daire|d|k)\s*[:.]\s*\d+"#
  /// Five digits starting with a province code, 01 to 81.
  static let postalPattern = #"\b(0[1-9]|[1-7]\d|8[01])\d{3}\b"#

  static func matches(_ pattern: String, in text: String) -> Bool {
    text.range(of: pattern, options: .regularExpression) != nil
  }

  static func containsProvince(_ folded: String) -> Bool {
    let words = Set(folded.split(whereSeparator: { !$0.isLetter }).map(String.init))
    return !words.isDisjoint(with: provinces)
  }

  /// The 81 provinces, folded like `fold`.
  static let provinces: Set<String> = Set([
    "Adana", "Adıyaman", "Afyonkarahisar", "Afyon", "Ağrı", "Amasya", "Ankara", "Antalya", "Artvin", "Aydın", "Balıkesir",
    "Bilecik", "Bingöl", "Bitlis", "Bolu", "Burdur", "Bursa", "Çanakkale", "Çankırı", "Çorum", "Denizli", "Diyarbakır",
    "Edirne", "Elazığ", "Erzincan", "Erzurum", "Eskişehir", "Gaziantep", "Giresun", "Gümüşhane", "Hakkari", "Hatay",
    "Isparta", "Mersin", "İçel", "İstanbul", "İzmir", "Kars", "Kastamonu", "Kayseri", "Kırklareli", "Kırşehir", "Kocaeli",
    "Konya", "Kütahya", "Malatya", "Manisa", "Kahramanmaraş", "Mardin", "Muğla", "Muş", "Nevşehir", "Niğde", "Ordu",
    "Rize", "Sakarya", "Samsun", "Siirt", "Sinop", "Sivas", "Tekirdağ", "Tokat", "Trabzon", "Tunceli", "Şanlıurfa",
    "Uşak", "Van", "Yozgat", "Zonguldak", "Aksaray", "Bayburt", "Karaman", "Kırıkkale", "Batman", "Şırnak", "Bartın",
    "Ardahan", "Iğdır", "Yalova", "Karabük", "Kilis", "Osmaniye", "Düzce"
  ].map(fold))
}
