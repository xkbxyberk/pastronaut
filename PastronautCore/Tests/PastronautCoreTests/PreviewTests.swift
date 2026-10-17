import Foundation
import Testing
@testable import PastronautCore

@Suite struct CodeHighlighterTests {
  private func kinds(_ text: String, _ language: CodeHighlighter.Language? = nil) -> [(String, CodeHighlighter.TokenKind)] {
    let ns = text as NSString
    return CodeHighlighter.tokens(in: text, language: language).map { (ns.substring(with: $0.range), $0.kind) }
  }

  @Test func languages() {
    #expect(CodeHighlighter.language(of: "struct ClipRow: View {\n  let clip: Clip\n}") == .swift)
    #expect(CodeHighlighter.language(of: "const x = () => console.log(1)") == .javascript)
    #expect(CodeHighlighter.language(of: "def main():\n    print('hi')") == .python)
    #expect(CodeHighlighter.language(of: "git commit -m \"Dalga 3\"") == .shell)
    #expect(CodeHighlighter.language(of: #"{"name": "Pastronaut", "v": 1}"#) == .json)
  }

  @Test func swiftTokens() {
    let tokens = kinds(#"let clip = Clip(text: "Merhaba") // greet"#)
    #expect(tokens.contains { $0 == ("let", .keyword) })
    #expect(tokens.contains { $0 == ("Clip", .type) })
    #expect(tokens.contains { $0 == ("\"Merhaba\"", .string) })
    #expect(tokens.contains { $0 == ("// greet", .comment) })
  }

  @Test func keywordsInsideStringsStayStrings() {
    let tokens = kinds(#"print("let me in")"#, .swift)
    #expect(tokens.map(\.1) == [.string])
  }

  @Test func shellFlagsAndJSONKeys() {
    #expect(kinds("git commit -m \"x\"").contains { $0 == ("-m", .type) })
    let json = kinds(#"{"name": "P", "count": 2, "on": true}"#, .json)
    #expect(json.contains { $0 == ("\"name\"", .type) })
    #expect(json.contains { $0 == ("\"P\"", .string) })
    #expect(json.contains { $0 == ("2", .number) })
    #expect(json.contains { $0 == ("true", .keyword) })
  }

  @Test func tokensDontOverlap() {
    let tokens = CodeHighlighter.tokens(in: #"let s = "a // b" // c"#, language: .swift)
    for (a, b) in zip(tokens, tokens.dropFirst()) {
      #expect(a.range.location + a.range.length <= b.range.location)
    }
  }
}

@Suite struct LinkPreviewPolicyTests {
  @Test(arguments: [
    "https://developer.apple.com/documentation/swiftui",
    "https://github.com/xkbxyberk/pastronaut",
    "https://tr.wikipedia.org/wiki/Kad%C4%B1k%C3%B6y",
    "https://example.com/blog?page=2"
  ])
  func ordinaryLinksAreFetched(_ link: String) {
    #expect(LinkPreviewPolicy.mayFetch(URL(string: link)!))
  }

  @Test(arguments: [
    "https://accounts.example.com/reset?token=abc",
    "https://example.com/verify-email/8f14e45fceea167a5a36dedd4bea2543",
    "https://app.example.com/login/magic?code=1234",
    "https://news.example.com/unsubscribe?u=99",
    "https://example.com/s/Zx81kLmQ2pRt7vWy3nBc5dFg",
    "http://localhost:8080/admin",
    "http://192.168.1.1/",
    "http://printer.local/",
    "ftp://example.com/file",
    "https://intranet/"
  ])
  func riskyLinksAreNot(_ link: String) {
    #expect(!LinkPreviewPolicy.mayFetch(URL(string: link)!))
  }
}
