import Testing
@testable import PastronautCore

@Suite struct SensitiveContentTests {
  @Test(arguments: [
    "482913", "482 913", "4829-13", "1234",
    "Doğrulama kodunuz: 482913. Kimseyle paylaşmayın.",
    "Your verification code is 739201",
    "G-482913 is your Google verification code."
  ])
  func oneTimeCodes(_ text: String) {
    #expect(SensitiveContent(text) == .oneTimeCode)
  }

  @Test(arguments: [
    "4111 1111 1111 1111", "4111-1111-1111-1111", "5555555555554444", "378282246310005"
  ])
  func cardNumbers(_ text: String) {
    #expect(SensitiveContent(text) == .cardNumber)
  }

  @Test(arguments: ["TR33 0006 1005 1978 6457 8413 26", "DE89370400440532013000", "GB82 WEST 1234 5698 7654 32"])
  func ibans(_ text: String) {
    #expect(SensitiveContent(text) == .iban)
  }

  @Test(arguments: [
    "4111 1111 1111 1112",                  // fails Luhn
    "TR33 0006 1005 1978 6457 8413 27",     // fails mod 97
    "+90 555 010 20 30",                    // phone
    "Toplantı Perşembe 14:00'te",
    "123",                                  // too short for a code
    "Fatura no: 2026-1043 · Tutar: 1.250,00 TL", // no code word
    "https://example.com/12345678",
    "Spinning wheel order 123456",          // "pin" only inside a word
    ""
  ])
  func notSensitive(_ text: String) {
    #expect(SensitiveContent(text) == nil)
  }

  @Test func privacyOptions() {
    let all = PrivacyOptions()
    #expect(all.allows("482913", pinned: false))
    #expect(all.allows("4111 1111 1111 1111", pinned: false))

    let careful = PrivacyOptions(skipOneTimeCodes: true, skipCardNumbers: true)
    #expect(!careful.allows("482913", pinned: false))
    #expect(!careful.allows("4111 1111 1111 1111", pinned: true))
    #expect(!careful.allows("DE89370400440532013000", pinned: false))
    #expect(careful.allows("merhaba", pinned: false))

    let pinnedOnly = PrivacyOptions(pinnedOnly: true)
    #expect(!pinnedOnly.allows("merhaba", pinned: false))
    #expect(pinnedOnly.allows("merhaba", pinned: true))
  }
}
