import Foundation

/// Colors code in the iPhone's code cards, on the device. A light, rule-based scanner: it guesses the language and
/// marks keywords, type names, strings, numbers and comments; everything else stays plain.
public enum CodeHighlighter {
  public enum Language: String, Sendable {
    case swift, javascript, python, shell, json, generic

    public var title: String {
      switch self {
      case .swift: "Swift"
      case .javascript: "JavaScript"
      case .python: "Python"
      case .shell: "Shell"
      case .json: "JSON"
      case .generic: "Code"
      }
    }
  }

  public enum TokenKind: Sendable, Equatable {
    case keyword, type, string, number, comment
  }

  public struct Token: Equatable, Sendable {
    public let kind: TokenKind
    /// UTF-16 offsets into the text, ready for NSAttributedString or AttributedString conversion.
    public let range: NSRange
  }

  public static func language(of text: String) -> Language {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if let first = trimmed.first, first == "{" || first == "[",
       let data = trimmed.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
      return .json
    }
    func has(_ markers: [String]) -> Bool { markers.contains { trimmed.contains($0) } }
    if has(["func ", "guard ", "import SwiftUI", "import Foundation", "struct ", "@State", "let ", "var "])
      && !has(["const ", "function ", "def "]) {
      return .swift
    }
    if has(["def ", "self.", "elif ", "import numpy", "print("]) && !has(["{", ";"]) {
      return .python
    }
    if has(["const ", "function ", "=> ", "console.", "require(", "export "]) {
      return .javascript
    }
    let commands = ["git ", "sudo ", "brew ", "npm ", "cd ", "ls ", "swift ", "xcodebuild ", "curl ", "./", "$ ", "echo "]
    if commands.contains(where: { trimmed.hasPrefix($0) }) || has([" && ", " | ", " --"]) {
      return .shell
    }
    return .generic
  }

  public static func tokens(in text: String, language: Language? = nil) -> [Token] {
    let language = language ?? self.language(of: text)
    let ns = text as NSString
    let whole = NSRange(location: 0, length: ns.length)
    var taken = IndexSet()
    var result: [Token] = []

    func scan(_ pattern: String, _ kind: TokenKind, options: NSRegularExpression.Options = [], group: Int = 0) {
      guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
      for match in regex.matches(in: text, range: whole) {
        let range = match.range(at: group)
        guard range.location != NSNotFound, range.length > 0 else { continue }
        let span = IndexSet(integersIn: range.location..<(range.location + range.length))
        guard taken.intersection(span).isEmpty else { continue }
        taken.formUnion(span)
        result.append(Token(kind: kind, range: range))
      }
    }

    // Comments and strings first, so keywords inside them stay part of them.
    switch language {
    case .python, .shell:
      scan(#"#[^\n]*"#, .comment)
    case .json:
      break
    default:
      scan(#"//[^\n]*"#, .comment)
      scan(#"/\*[\s\S]*?\*/"#, .comment)
    }
    if language == .json {
      scan(#"("(?:[^"\\]|\\.)*")\s*:"#, .type, group: 1)
    }
    scan(#""(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'"#, .string)
    if language == .javascript || language == .shell {
      scan(#"`[^`]*`"#, .string)
    }
    scan(#"\b\d+(?:\.\d+)?\b"#, .number)

    let words = keywords[language] ?? keywords[.generic] ?? []
    if !words.isEmpty {
      scan(#"\b(?:"# + words.joined(separator: "|") + #")\b"#, .keyword)
    }
    switch language {
    case .swift, .javascript, .generic:
      scan(#"\b[A-Z][A-Za-z0-9_]*\b"#, .type)
    case .shell:
      // Flags such as -m or --filter.
      scan(#"(?<=\s)--?[A-Za-z][A-Za-z0-9-]*"#, .type)
    case .python, .json:
      break
    }
    return result.sorted { $0.range.location < $1.range.location }
  }

  static let keywords: [Language: [String]] = [
    .swift: ["let", "var", "func", "struct", "class", "enum", "protocol", "extension", "import", "return", "if", "else",
             "guard", "for", "in", "while", "switch", "case", "default", "some", "any", "self", "Self", "true", "false",
             "nil", "private", "public", "static", "async", "await", "try", "throws", "init", "where", "@State"],
    .javascript: ["const", "let", "var", "function", "return", "if", "else", "for", "while", "class", "new", "import",
                  "export", "from", "async", "await", "true", "false", "null", "undefined", "this", "typeof"],
    .python: ["def", "class", "return", "if", "elif", "else", "for", "while", "in", "import", "from", "as", "with",
              "try", "except", "None", "True", "False", "self", "lambda", "yield", "pass", "and", "or", "not"],
    .shell: ["git", "sudo", "brew", "npm", "cd", "ls", "echo", "export", "if", "then", "fi", "for", "do", "done",
             "swift", "xcodebuild", "curl"],
    .json: ["true", "false", "null"],
    .generic: ["if", "else", "for", "while", "return", "function", "class", "def", "let", "var", "const", "true",
               "false", "null", "nil", "import"]
  ]
}

/// Which links the iPhone may open to show a page preview. Opening a link tells the site our address, and some links
/// work only once (a password reset, a sign-in link, unsubscribing): those are never opened.
public enum LinkPreviewPolicy {
  static let sensitiveWords = [
    "token", "reset", "verify", "verification", "confirm", "activate", "login", "signin", "sign-in", "logout",
    "magic", "unsubscribe", "auth", "oauth", "otp", "password", "passwd", "invite", "session", "secret", "key=",
    "code=", "sig=", "signature"
  ]

  public static func mayFetch(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
          let host = url.host?.lowercased(), !host.isEmpty else { return false }
    // Nothing on this network: no local names, no IP addresses.
    if host == "localhost" || host.hasSuffix(".local") || host.hasSuffix(".lan") || !host.contains(".") {
      return false
    }
    if host.allSatisfy({ $0.isNumber || $0 == "." }) || host.contains(":") {
      return false
    }
    let rest = (url.path + "?" + (url.query ?? "") + "#" + (url.fragment ?? "")).lowercased()
    if sensitiveWords.contains(where: rest.contains) {
      return false
    }
    // Long opaque values look like one-time tokens.
    if (url.query ?? "").count > 80 {
      return false
    }
    let pieces = rest.split(whereSeparator: { "/?&=#".contains($0) })
    if pieces.contains(where: { piece in
      piece.count >= 24 && piece.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        && piece.contains(where: \.isNumber)
    }) {
      return false
    }
    return true
  }
}
