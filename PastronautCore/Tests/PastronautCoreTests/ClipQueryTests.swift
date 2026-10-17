import Foundation
import Testing
@testable import PastronautCore

@Suite struct ClipQueryTests {
  @Test func plainTextStaysAsTyped() {
    for text in ["toplantı notu", "https://example.com/a", "10:30", "a  b ", "key: value"] {
      let query = ClipQuery.parse(text)
      #expect(query.text == text)
      #expect(!query.hasFilters)
    }
  }

  @Test func englishAndTurkishKeys() {
    let english = ClipQuery.parse("app:Safari type:link date:yesterday from:iphone invoice")
    #expect(english.app == "safari")
    #expect(english.kinds == [.link])
    #expect(english.day == .yesterday)
    #expect(english.device == .iphone)
    #expect(english.text == "invoice")

    let turkish = ClipQuery.parse("uygulama:Notlar tür:Bağlantı tür:kod tarih:dün cihaz:mac fatura")
    #expect(turkish.app == "notlar")
    #expect(turkish.kinds == [.link, .code])
    #expect(turkish.day == .yesterday)
    #expect(turkish.device == .mac)
    #expect(turkish.text == "fatura")
  }

  @Test func quotedValues() {
    let query = ClipQuery.parse(#"app:"Google Chrome" sepet"#)
    #expect(query.app == "google chrome")
    #expect(query.text == "sepet")
  }

  @Test func unknownValuesStayWords() {
    let query = ClipQuery.parse("type:banana tarih:yarın")
    #expect(!query.hasFilters)
    #expect(query.text == "type:banana tarih:yarın")
  }

  @Test func dayAndApp() {
    let calendar = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSince1970: 1_760_000_000)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
    let query = ClipQuery.parse("tarih:dün app:chrome")
    #expect(query.matchesDay(yesterday, now: now, calendar: calendar))
    #expect(!query.matchesDay(now, now: now, calendar: calendar))
    #expect(query.matchesApp(name: "Google Chrome", bundleIdentifier: nil))
    #expect(query.matchesApp(name: nil, bundleIdentifier: "com.google.Chrome"))
    #expect(!query.matchesApp(name: "Safari", bundleIdentifier: "com.apple.Safari"))
  }
}
