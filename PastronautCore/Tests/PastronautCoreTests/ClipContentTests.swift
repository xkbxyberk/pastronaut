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

@Suite struct AddressAndKindTests {
  @Test(arguments: [
    "Kadıköy, Moda Cd. No: 12, İstanbul",
    "Caferağa Mah. Moda Cad. No:12 D:3 34710 Kadıköy/İstanbul",
    "Atatürk Bulvarı No:45 Çankaya Ankara",
    "1 Infinite Loop, Cupertino, CA 95014"
  ])
  func addresses(_ text: String) {
    #expect(ClipContent(text) == .address(text))
    #expect(ClipContent(text).kind == .address)
  }

  @Test(arguments: [
    "Toplantı Perşembe 14:00'te",
    "Kargo takip no: 1Z 999 AA1 0123 4567 84",
    "Moda",
    "let x = 12"
  ])
  func notAddresses(_ text: String) {
    #expect(ClipContent(text).kind != .address)
  }

  @Test func addressChip() {
    #expect(ClipSearchToken.address.matches(text: "Bağdat Cd. No: 300 Kadıköy İstanbul", pinned: false, lastCopiedAt: .now))
    #expect(!ClipSearchToken.address.matches(text: "hello", pinned: false, lastCopiedAt: .now))
  }

  @Test func everyKindHasAPaletteEntryButColor() {
    for kind in ClipKind.allCases where kind != .color {
      #expect(ClipKind.palette[kind] != nil, "\(kind)")
    }
    #expect(ClipContent("#1E6FA8").kind == .color)
    #expect(ClipContent("https://example.com").kind == .link)
  }
}
