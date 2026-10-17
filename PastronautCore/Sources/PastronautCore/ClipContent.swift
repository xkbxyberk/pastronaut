import Foundation

/// What a clip's text looks like, for icons and smart actions. Computed on the device, never synced,
/// so detection can improve without a schema change.
public enum ClipContent: Equatable, Sendable {
  case link(URL)
  case email(String)
  case phone(String)
  case color(hex: String)
  case code
  case text

  public init(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if Self.isSingleToken(trimmed) {
      if let color = Self.hexColor(trimmed) {
        self = .color(hex: color)
        return
      }
      if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
         ["http", "https"].contains(scheme), url.host != nil {
        self = .link(url)
        return
      }
      if Self.isEmail(trimmed) {
        self = .email(trimmed)
        return
      }
    }
    if Self.isPhone(trimmed) {
      self = .phone(trimmed)
    } else if Self.looksLikeCode(trimmed) {
      self = .code
    } else {
      self = .text
    }
  }

  // MARK: - Rules

  private static func isSingleToken(_ text: String) -> Bool {
    !text.isEmpty && !text.contains(where: \.isWhitespace)
  }

  /// `#RGB`, `#RRGGBB` or `#RRGGBBAA`.
  ///
  /// Without `#`, only six hex characters mixing digits and the letters A–F count: "c0ffee" is a color, but
  /// "235442" stays text (it is more likely a one-time code) and so does "facade" (a word).
  private static func hexColor(_ text: String) -> String? {
    if text.hasPrefix("#") {
      let digits = text.dropFirst()
      guard [3, 6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
      return text.uppercased()
    }
    guard text.count == 6, text.allSatisfy({ $0.isASCII && $0.isHexDigit }),
          text.contains(where: \.isNumber), text.contains(where: \.isLetter) else { return nil }
    return "#" + text.uppercased()
  }

  private static func isEmail(_ text: String) -> Bool {
    let parts = text.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty else { return false }
    let domain = parts[1]
    return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
  }

  /// 10–15 digits (7–15 after a leading "+"), with spaces, dashes, dots or parentheses between them.
  /// The higher bare minimum keeps dates such as 2026-10-16 out.
  private static func isPhone(_ text: String) -> Bool {
    guard !text.isEmpty, text.count <= 24 else { return false }
    var digits = 0
    for (index, character) in text.enumerated() {
      if character.isASCII, character.isNumber {
        digits += 1
      } else if character == "+" {
        guard index == 0 else { return false }
      } else if !" -.()".contains(character) {
        return false
      }
    }
    return ((text.hasPrefix("+") ? 7 : 10)...15).contains(digits)
  }

  /// Shell commands and source code: a few strong signals rather than full parsing.
  private static func looksLikeCode(_ text: String) -> Bool {
    let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
    let commands = ["git ", "cd ", "npm ", "brew ", "swift ", "xcodebuild ", "curl ", "sudo ", "ssh ", "docker ",
                    "python ", "python3 ", "pip ", "ls ", "mkdir ", "rm ", "cp ", "mv ", "echo ", "export "]
    if commands.contains(where: firstLine.hasPrefix) { return true }
    let markers = ["func ", "let ", "var ", "class ", "struct ", "import ", "return ", "=> ", "();", "{\n",
                   "</", "#include", "def ", "SELECT ", "const "]
    let hits = markers.filter(text.contains).count
    let symbols = text.filter { "{}();=<>[]".contains($0) }.count
    return hits >= 2 || (hits >= 1 && symbols >= 4) || (text.contains("\n") && symbols * 12 >= text.count)
  }
}
