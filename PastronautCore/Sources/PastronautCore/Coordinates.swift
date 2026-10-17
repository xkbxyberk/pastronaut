import Foundation

/// A latitude and longitude copied from a map app, shown like an address (a map, directions). Recognized forms:
/// - decimal, as Google Maps copies it: `38.4237, 27.1428` (also with parentheses or a space after the comma)
/// - decimal with hemispheres, as Apple Maps copies it: `38.4237° N, 27.1428° E`, in Turkish `38,4237° K, 27,1428° D`
/// - degrees, minutes, seconds: `38°25'25.3"N 27°08'34.1"E`
public struct Coordinates: Equatable, Sendable {
  public let latitude: Double
  public let longitude: Double

  public init?(latitude: Double, longitude: Double) {
    guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
    self.latitude = latitude
    self.longitude = longitude
  }

  /// "38.4237,27.1428": for map links (Apple Maps `daddr`, `ll`).
  public var query: String {
    "\(Self.format(latitude)),\(Self.format(longitude))"
  }

  /// Apple Maps directions to an address or to copied coordinates.
  public static func directionsURL(to address: String) -> URL? {
    var components = URLComponents(string: "https://maps.apple.com/")
    components?.queryItems = [URLQueryItem(name: "daddr", value: parse(address)?.query ?? address)]
    return components?.url
  }

  public static func parse(_ text: String) -> Coordinates? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count <= 60, !trimmed.contains("\n") else { return nil }
    return plainDecimal(trimmed) ?? withHemispheres(trimmed)
  }

  // MARK: - Forms

  /// `38.4237, 27.1428`: both numbers need at least three decimals, so "1.5, 2.25" stays text.
  private static func plainDecimal(_ text: String) -> Coordinates? {
    let pattern = #"^\(?\s*(-?\d{1,2}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})\s*\)?$"#
    guard let groups = captures(pattern, in: text), groups.count == 2,
          let latitude = Double(groups[0]), let longitude = Double(groups[1]) else { return nil }
    return Coordinates(latitude: latitude, longitude: longitude)
  }

  /// Two parts, each a number of degrees (decimal, or degrees/minutes/seconds) and a hemisphere letter.
  private static func withHemispheres(_ text: String) -> Coordinates? {
    // One part: 38.4237° N | 38,4237° K | 38°25'25.3"N | 38°25′25.3″ N
    let number = #"(\d{1,3}(?:[.,]\d+)?)"#
    let part = #"\#(number)\s*°\s*(?:\#(number)\s*['′]\s*(?:\#(number)\s*["″]\s*)?)?([NSEWKGDBnsewkgdb])"#
    let pattern = #"^\#(part)\s*,?\s*\#(part)$"#
    guard let groups = captures(pattern, in: text), groups.count == 8 else { return nil }
    guard let first = degrees(groups[0], groups[1], groups[2]), let second = degrees(groups[4], groups[5], groups[6]) else {
      return nil
    }
    let firstHemisphere = groups[3].uppercased(), secondHemisphere = groups[7].uppercased()
    // N/K north, S/G south (Kuzey, Güney); E/D east, W/B west (Doğu, Batı).
    let north = ["N", "K"], south = ["S", "G"], east = ["E", "D"], west = ["W", "B"]
    guard north.contains(firstHemisphere) || south.contains(firstHemisphere),
          east.contains(secondHemisphere) || west.contains(secondHemisphere) else { return nil }
    return Coordinates(
      latitude: south.contains(firstHemisphere) ? -first : first,
      longitude: west.contains(secondHemisphere) ? -second : second
    )
  }

  private static func degrees(_ degrees: String, _ minutes: String, _ seconds: String) -> Double? {
    func value(_ text: String) -> Double? { text.isEmpty ? 0 : Double(text.replacingOccurrences(of: ",", with: ".")) }
    guard let d = value(degrees), let m = value(minutes), let s = value(seconds), m < 60, s < 60 else { return nil }
    return d + m / 60 + s / 3600
  }

  /// The capture groups of a whole-text match; empty strings for groups that didn't take part.
  private static func captures(_ pattern: String, in text: String) -> [String]? {
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
    return (1..<match.numberOfRanges).map { index in
      Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
    }
  }

  private static func format(_ value: Double) -> String {
    String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
  }
}
