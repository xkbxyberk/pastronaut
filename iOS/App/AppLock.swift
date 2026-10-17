import LocalAuthentication
import Observation
import PastronautCore
import SwiftUI
import WidgetKit

/// Optional Face ID (or passcode) lock for the app. The keyboard can't ask for Face ID, so it stays usable;
/// widgets hide clip text while the lock is on.
@MainActor
@Observable
final class AppLock {
  static let shared = AppLock()

  private(set) var isLocked = false
  private var isAuthenticating = false

  var isEnabled: Bool {
    get {
      access(keyPath: \.isEnabled)
      return SharedSettings.isAppLockEnabled
    }
    set {
      withMutation(keyPath: \.isEnabled) {
        SharedSettings.defaults?.set(newValue, forKey: SharedSettings.appLockKey)
      }
      WidgetCenter.shared.reloadAllTimelines()
      // Spotlight would show what the lock hides.
      SpotlightIndex.update(with: ClipStore.shared.clips)
    }
  }

  /// "Face ID", "Touch ID", "Optic ID" or "Passcode", for labels.
  var methodName: String {
    let context = LAContext()
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    return switch context.biometryType {
    case .faceID: "Face ID"
    case .touchID: "Touch ID"
    case .opticID: "Optic ID"
    default: String(localized: "Passcode")
    }
  }

  private init() {
    isLocked = isEnabled && !Self.isTesting
  }

  /// Called when the app goes to the background.
  func lock() {
    guard isEnabled, !Self.isTesting else { return }
    isLocked = true
  }

  func unlock() async {
    guard isLocked, !isAuthenticating else { return }
    isAuthenticating = true
    defer { isAuthenticating = false }
    if await authenticate(reason: String(localized: "Unlock your clipboard history")) {
      withAnimation(.snappy) { isLocked = false }
    }
  }

  /// Asks once before the lock is turned on, so nobody locks themselves out by mistake.
  func setEnabled(_ enabled: Bool) async {
    if enabled {
      guard await authenticate(reason: String(localized: "Turn on the lock for Pastronaut")) else { return }
    }
    isEnabled = enabled
  }

  private func authenticate(reason: String) async -> Bool {
    let context = LAContext()
    do {
      return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    } catch {
      return false
    }
  }

  private static var isTesting: Bool {
    #if DEBUG
    // The end-to-end test can't look at a face.
    return ProcessInfo.processInfo.environment["PT_E2E"] != nil
    #else
    return false
    #endif
  }
}

/// Covers the history while locked, and in the app switcher.
struct LockScreen: View {
  let lock: AppLock

  var body: some View {
    ZStack {
      Rectangle().fill(.regularMaterial).ignoresSafeArea()
      VStack(spacing: 18) {
        Image(systemName: "lock.fill")
          .font(.system(size: 44))
          .foregroundStyle(.secondary)
        Text("Pastronaut is locked")
          .font(.title3.bold())
        Button {
          Task { await lock.unlock() }
        } label: {
          Label("Unlock with \(lock.methodName)", systemImage: "faceid")
            .padding(.horizontal, 8)
        }
        .controlSize(.large)
        .primaryActionStyle()
        .accessibilityIdentifier("unlockButton")
      }
    }
  }
}
