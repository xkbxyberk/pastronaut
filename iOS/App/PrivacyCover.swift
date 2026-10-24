import Observation
import PastronautCore
import SwiftUI
import UIKit

/// One window above everything the app shows, sheets included, that covers the history when it must not be seen:
/// while the lock is closed, while the screen is recorded or mirrored ("Hide During Screen Recording"), and in the
/// app switcher. iOS can't keep a window out of a recording; it can only notice one, so the cover goes up.
@MainActor
@Observable
final class PrivacyCover {
  static let shared = PrivacyCover()

  /// Bools in the app's own user defaults.
  static let recordingKey = "hideDuringScreenRecording"
  static let switcherKey = "hideInAppSwitcher"

  enum Reason: Equatable {
    case locked
    case recording
    case switcher
  }

  private(set) var reason: Reason?
  private(set) var isCaptured = false
  /// "Show Anyway" while recording; until the recording stops.
  private var showsDuringThisRecording = false
  private var isActive = true
  @ObservationIgnored private var window: UIWindow?
  @ObservationIgnored private var observers: [NSObjectProtocol] = []

  private init() {
    UserDefaults.standard.register(defaults: [Self.recordingKey: true, Self.switcherKey: false])
  }

  /// Called once the app has a window scene.
  func attach(to scene: UIWindowScene) {
    guard window == nil else { return }
    let window = UIWindow(windowScene: scene)
    window.windowLevel = .alert + 1
    window.backgroundColor = .clear
    let host = UIHostingController(rootView: CoverView(cover: self))
    host.view.backgroundColor = .clear
    // VoiceOver reads only the cover, not the history under it.
    host.view.accessibilityViewIsModal = true
    window.rootViewController = host
    window.isHidden = true
    self.window = window
    window.registerForTraitChanges([UITraitSceneCaptureState.self]) { [weak self] (_: UIWindow, _: UITraitCollection) in
      self?.update()
    }
    observers.append(NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.update() }
    })
    update()
  }

  func sceneBecame(active: Bool) {
    isActive = active
    update()
  }

  func showDuringThisRecording() {
    showsDuringThisRecording = true
    update()
  }

  /// Works out what to cover from the lock, the recording and the scene's state.
  func update() {
    let captured = window?.windowScene?.traitCollection.sceneCaptureState == .active && !Self.isTesting
    if captured != isCaptured {
      isCaptured = captured
      if !captured { showsDuringThisRecording = false }
    }
    let lock = AppLock.shared
    let defaults = UserDefaults.standard
    let next: Reason? = if lock.isLocked {
      .locked
    } else if isCaptured, defaults.bool(forKey: Self.recordingKey), !showsDuringThisRecording {
      .recording
    } else if !isActive, lock.isEnabled || defaults.bool(forKey: Self.switcherKey) {
      .switcher
    } else {
      nil
    }
    if next != reason {
      reason = next
    }
    window?.isHidden = next == nil
  }
}

extension PrivacyCover {
  /// UI tests capture the screen, which iOS reports as a recording; the cover would hide what they look for.
  /// Made-up clips (PT_DEMO) have nothing to hide either.
  fileprivate static var isTesting: Bool {
    #if DEBUG
    let environment = ProcessInfo.processInfo.environment
    return environment["PT_E2E"] != nil || environment["PT_DEMO"] != nil
    #else
    return false
    #endif
  }
}

private struct CoverView: View {
  let cover: PrivacyCover

  var body: some View {
    Group {
      switch cover.reason {
      case .locked:
        LockScreen(lock: AppLock.shared)
      case .recording:
        Message(
          systemImage: "record.circle",
          title: "Hidden while the screen is recorded",
          text: "Your clips are covered while this screen is recorded or shown on another display."
        ) {
          Button("Show Anyway") { cover.showDuringThisRecording() }
            .controlSize(.large)
            .secondaryActionStyle()
            .accessibilityIdentifier("showDuringRecording")
        }
      case .switcher, nil:
        Message(systemImage: "lock.fill", title: nil, text: nil) { EmptyView() }
      }
    }
    .modifier(AppPreferencesScope())
  }
}

private struct Message<Actions: View>: View {
  let systemImage: String
  let title: LocalizedStringKey?
  let text: LocalizedStringKey?
  @ViewBuilder let actions: () -> Actions

  var body: some View {
    ZStack {
      Rectangle().fill(.regularMaterial).ignoresSafeArea()
      VStack(spacing: 14) {
        Image(systemName: systemImage)
          .font(.largeTitle)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        if let title {
          Text(title)
            .font(.title3.bold())
            .multilineTextAlignment(.center)
        }
        if let text {
          Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        actions()
      }
      .padding(32)
    }
  }
}
