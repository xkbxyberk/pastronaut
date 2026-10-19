import PastronautCore
import SwiftUI
import UIKit

/// Live state of the keyboard setup, re-read whenever the app comes back from Settings.
@MainActor
@Observable
final class KeyboardSetup {
  static let shared = KeyboardSetup()
  static let keyboardBundleID = "com.xkbxyberk.pastronaut.keyboard"
  /// Written by the keyboard each time it appears with Full Access (it cannot write the App Group without it).
  static let fullAccessSeenKey = "keyboardFullAccessSeenAt"

  private(set) var isKeyboardAdded = false
  private(set) var hasFullAccess = false

  var isComplete: Bool { isKeyboardAdded && hasFullAccess }
  var isWaitingForKeyboardCheck: Bool { isKeyboardAdded && !hasFullAccess }

  func update() {
    // The system's list of enabled keyboards, readable by any app.
    let keyboards = UserDefaults.standard.stringArray(forKey: "AppleKeyboards") ?? []
    isKeyboardAdded = keyboards.contains(Self.keyboardBundleID)
    hasFullAccess = UserDefaults(suiteName: PastronautIDs.appGroup)?.object(forKey: Self.fullAccessSeenKey) != nil
  }
}

extension View {
  /// The heading scrolls under the back button: on iOS 26 and later a hard edge keeps the button on a calm band
  /// instead of over the large text.
  @ViewBuilder
  func solidTopEdge() -> some View {
    if #available(iOS 26.0, *) {
      scrollEdgeEffectStyle(.hard, for: .top)
    } else {
      self
    }
  }
}
