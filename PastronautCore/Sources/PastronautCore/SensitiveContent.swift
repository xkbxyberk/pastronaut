import Foundation

/// Recognizes copies that users may not want in iCloud. Used by the privacy switches in the Mac's Sync
/// settings; detection is local and conservative (checksums for cards and IBANs) to keep false alarms rare.
public enum SensitiveContent: Equatable, Sendable {
  case oneTimeCode
  case cardNumber
  case iban

  public init?(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 200 else { return nil }
    if Self.isCardNumber(trimmed) {
      self = .cardNumber
    } else if Self.isIBAN(trimmed) {
      self = .iban
    } else if Self.isOneTimeCode(trimmed) {
      self = .oneTimeCode
    } else {
      return nil
    }
  }

  // MARK: - One-time codes

  private static let codeWords = [
    "code", "kod", "kodu", "otp", "doğrulama", "dogrulama", "verification", "verify", "şifre", "sifre",
    "passcode", "pin", "2fa", "giriş", "login", "security"
  ]

  /// "482913", "482 913", "482-913", or a short message with a code word and a 4–8 digit number.
  static func isOneTimeCode(_ text: String) -> Bool {
    if isBareCode(text) { return true }
    guard text.count <= 160 else { return false }
    let lower = text.lowercased()
    // Whole words only: "pin" must not match "spinning".
    let words = Set(lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
    guard !words.isDisjoint(with: codeWords) else { return false }
    return lower
      .split(whereSeparator: { !$0.isNumber && $0 != "-" })
      .contains { isBareCode(String($0)) }
  }

  private static func isBareCode(_ text: String) -> Bool {
    let parts = text.split(whereSeparator: { $0 == " " || $0 == "-" })
    guard (1...2).contains(parts.count), parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }) else {
      return false
    }
    let digits = parts.reduce(0) { $0 + $1.count }
    // Years such as 2026 are four digits too, but a lone year is rarely copied on its own; keep 4 allowed.
    return (4...8).contains(digits)
  }

  // MARK: - Cards

  /// 13–19 digits, optionally grouped with spaces or dashes, with a valid Luhn check digit.
  static func isCardNumber(_ text: String) -> Bool {
    guard text.allSatisfy({ ($0.isASCII && $0.isNumber) || $0 == " " || $0 == "-" }) else { return false }
    let digits = text.compactMap(\.wholeNumberValue)
    guard (13...19).contains(digits.count) else { return false }
    var sum = 0
    for (index, digit) in digits.reversed().enumerated() {
      if index.isMultiple(of: 2) {
        sum += digit
      } else {
        let doubled = digit * 2
        sum += doubled > 9 ? doubled - 9 : doubled
      }
    }
    return sum.isMultiple(of: 10)
  }

  // MARK: - IBAN

  /// Country code, two check digits and up to 30 letters or digits, spaces allowed; mod-97 must be 1.
  static func isIBAN(_ text: String) -> Bool {
    let compact = text.replacingOccurrences(of: " ", with: "").uppercased()
    guard (15...34).contains(compact.count), compact.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
      return false
    }
    let characters = Array(compact)
    guard characters[0].isLetter, characters[1].isLetter, characters[2].isNumber, characters[3].isNumber else {
      return false
    }
    let rearranged = characters[4...] + characters[..<4]
    var remainder = 0
    for character in rearranged {
      let value: Int
      if let digit = character.wholeNumberValue {
        value = digit
      } else if let ascii = character.asciiValue {
        value = Int(ascii) - 55 // A = 10
      } else {
        return false
      }
      for digit in String(value) {
        remainder = (remainder * 10 + (digit.wholeNumberValue ?? 0)) % 97
      }
    }
    return remainder == 1
  }
}

/// Which clips may leave the Mac, as chosen in Sync settings. Off by default: everything syncs.
public struct PrivacyOptions: Equatable, Sendable {
  public var skipOneTimeCodes = false
  public var skipCardNumbers = false
  public var pinnedOnly = false

  public init(skipOneTimeCodes: Bool = false, skipCardNumbers: Bool = false, pinnedOnly: Bool = false) {
    self.skipOneTimeCodes = skipOneTimeCodes
    self.skipCardNumbers = skipCardNumbers
    self.pinnedOnly = pinnedOnly
  }

  /// Whether a clip with this text and pin state may be uploaded.
  public func allows(_ text: String, pinned: Bool) -> Bool {
    if pinnedOnly && !pinned { return false }
    switch SensitiveContent(text) {
    case .oneTimeCode: return !skipOneTimeCodes
    case .cardNumber, .iban: return !skipCardNumbers
    case nil: return true
    }
  }
}

public extension PrivacyOptions {
  /// Bools in the App Group's user defaults (iPhone Settings › Privacy). On the iPhone a matching clip is still
  /// saved, but stays on this iPhone as a local-only clip instead of syncing.
  static let phoneCodesKey = "keepOneTimeCodesOnDevice"
  static let phoneCardsKey = "keepCardNumbersOnDevice"

  /// Since 1.3 the switches are shared by every device (`SharedSyncSettings`); the app keeps this copy for the
  /// keyboard and the Share extension, which save without it.
  static let phonePinnedOnlyKey = "syncPinnedOnly"

  static func onPhone(in defaults: UserDefaults?) -> PrivacyOptions {
    PrivacyOptions(
      skipOneTimeCodes: defaults?.bool(forKey: phoneCodesKey) ?? false,
      skipCardNumbers: defaults?.bool(forKey: phoneCardsKey) ?? false,
      pinnedOnly: defaults?.bool(forKey: phonePinnedOnlyKey) ?? false
    )
  }

  /// Keeps the copy for the extensions in step with the shared settings.
  static func writeOnPhone(_ options: PrivacyOptions, in defaults: UserDefaults?) {
    defaults?.set(options.skipOneTimeCodes, forKey: phoneCodesKey)
    defaults?.set(options.skipCardNumbers, forKey: phoneCardsKey)
    defaults?.set(options.pinnedOnly, forKey: phonePinnedOnlyKey)
  }
}

/// Saving the clipboard by itself when the iPhone app or keyboard opens. Unlike a tap on the Paste button,
/// nobody looked at the text first, so sensitive-looking copies are always left out.
public enum AutoCapture {
  /// Bool in the App Group's user defaults, shared by the app and the keyboard. On by default.
  public static let settingKey = "autoSaveClipboard"
  /// The pasteboard change count that was last saved or looked at, so one copy is read once.
  public static let lastChangeCountKey = "keyboardLastCapturedChangeCount"

  public static func allows(_ text: String) -> Bool {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          SyncPolicy.default.isEligible(text) else { return false }
    return SensitiveContent(text) == nil
  }

  /// The setting is on and saving isn't paused (`SavingPause`).
  public static func isActive(in defaults: UserDefaults?, at date: Date = .now) -> Bool {
    (defaults?.object(forKey: settingKey) as? Bool ?? true) && !SavingPause.isPaused(in: defaults, at: date)
  }
}

/// "Pause Saving" on the iPhone: for a while the app and the keyboard don't save the clipboard by themselves.
/// What the person asks for (Paste button, Share, Shortcuts, the Save Clipboard control) still saves. The
/// lengths are the Mac's (`PauseLength`).
public enum SavingPause {
  /// Date in the App Group's user defaults; `Date.distantFuture` means until resumed.
  public static let untilKey = "savingPausedUntil"

  public static func pause(_ length: PauseLength, in defaults: UserDefaults?, from date: Date = .now,
                           calendar: Calendar = .current) {
    defaults?.set(length.end(from: date, calendar: calendar) ?? .distantFuture, forKey: untilKey)
  }

  public static func resume(in defaults: UserDefaults?) {
    defaults?.removeObject(forKey: untilKey)
  }

  /// When saving resumes by itself; `Date.distantFuture` waits for the person, nil when not paused.
  public static func pausedUntil(in defaults: UserDefaults?, at date: Date = .now) -> Date? {
    guard let until = defaults?.object(forKey: untilKey) as? Date, until > date else { return nil }
    return until
  }

  public static func isPaused(in defaults: UserDefaults?, at date: Date = .now) -> Bool {
    pausedUntil(in: defaults, at: date) != nil
  }
}
