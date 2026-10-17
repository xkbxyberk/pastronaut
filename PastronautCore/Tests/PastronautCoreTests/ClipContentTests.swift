import Foundation
import Testing
@testable import PastronautCore

@Suite struct ClipContentTests {
  @Test(arguments: ["https://developer.apple.com/documentation/cloudkit", "  http://example.com/a?b=c  "])
  func links(_ text: String) {
    guard case .link = ClipContent(text) else {
      Issue.record("\(text) is not a link")
      return
    }
  }

  @Test func emailsPhonesAndColors() {
    #expect(ClipContent("ayse@example.com") == .email("ayse@example.com"))
    #expect(ClipContent("+90 555 010 20 30") == .phone("+90 555 010 20 30"))
    #expect(ClipContent("0555 010 20 30") == .phone("0555 010 20 30"))
    #expect(ClipContent("(555) 010-2030") == .phone("(555) 010-2030"))
    #expect(ClipContent("#5b4bd0") == .color(hex: "#5B4BD0"))
    #expect(ClipContent("#FFF") == .color(hex: "#FFF"))
    #expect(ClipContent("c0ffee") == .color(hex: "#C0FFEE"))
    #expect(ClipContent("1E6FA8") == .color(hex: "#1E6FA8"))
  }

  @Test(arguments: ["git push origin main", "let x = foo(bar);\nreturn x", "func a() {\n  b()\n}"])
  func code(_ text: String) {
    #expect(ClipContent(text) == .code)
  }

  @Test(arguments: [
    "Toplantı Perşembe 14:00'te, 3. kattaki salonda.",
    "2026-10-16",
    "Fatura no: 2026-1043",
    "#hashtag",
    "facade",   // only letters: a word, not a color
    "235442",   // only digits: more likely a code
    "1e6fa8ff", // eight characters need "#"
    "a@b",
    "1234 5678 9012 3456",
    "example.com",
    ""
  ])
  func plainText(_ text: String) {
    #expect(ClipContent(text) == .text)
  }
}
