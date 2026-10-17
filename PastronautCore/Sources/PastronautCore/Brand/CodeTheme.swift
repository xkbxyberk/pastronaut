import Foundation
import SwiftUI

/// The dark code panel the iPhone's cards and the Mac's preview share: one background, one plain color, and one
/// color per token kind from `CodeHighlighter`.
public enum CodeTheme {
  public static let background = Color(red: 0.114, green: 0.153, blue: 0.2)
  public static let plain = Color(red: 0.847, green: 0.882, blue: 0.918)
  /// The language label above the code.
  public static let label = Color(red: 0.73, green: 0.63, blue: 1)

  public static func color(_ kind: CodeHighlighter.TokenKind) -> Color {
    switch kind {
    case .keyword: Color(red: 1, green: 0.54, blue: 0.79)
    case .type: Color(red: 0.5, green: 0.82, blue: 0.91)
    case .string: Color(red: 0.95, green: 0.76, blue: 0.55)
    case .number: Color(red: 0.77, green: 0.69, blue: 1)
    case .comment: Color(red: 0.54, green: 0.6, blue: 0.66)
    }
  }

  /// The text with each token in its color, everything else plain.
  public static func attributed(_ text: String, language: CodeHighlighter.Language? = nil) -> AttributedString {
    var string = AttributedString(text)
    string.foregroundColor = plain
    for token in CodeHighlighter.tokens(in: text, language: language) {
      guard let range = Range(token.range, in: string) else { continue }
      string[range].foregroundColor = color(token.kind)
    }
    return string
  }
}

/// Reading a "#RRGGBB" (or "#RGB") clip as numbers, for the swatch's caption and its text color.
public enum HexColor {
  public static func rgb(_ hex: String) -> (Int, Int, Int)? {
    var digits = hex.drop { $0 == "#" }.map(String.init)
    if digits.count == 3 { digits = digits.flatMap { [$0, $0] } }
    guard digits.count >= 6, let value = Int(digits.prefix(6).joined(), radix: 16) else { return nil }
    return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
  }

  /// Light colors get dark text (perceived brightness above 0.6).
  public static func isLight(_ hex: String) -> Bool {
    guard let (r, g, b) = rgb(hex) else { return false }
    return (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255 > 0.6
  }
}
