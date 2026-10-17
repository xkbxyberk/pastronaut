import PastronautCore
import SwiftUI
import UIKit

@main
struct PastronautApp: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
  @Environment(\.scenePhase) private var scenePhase
  private let lock = AppLock.shared

  var body: some Scene {
    WindowGroup {
      HistoryView()
        .environment(ClipStore.shared)
        .overlay {
          // Also hides the history in the app switcher while the lock is on.
          if lock.isLocked || (lock.isEnabled && scenePhase != .active) {
            LockScreen(lock: lock)
              .transition(.opacity)
          }
        }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        Task {
          if lock.isLocked { await lock.unlock() }
          await ClipStore.shared.savePendingClipboard()
          await ClipStore.shared.autoSaveClipboard()
          await ClipStore.shared.refresh()
        }
      } else if phase == .background {
        lock.lock()
        Task { await ClipStore.shared.upload() }
      }
    }
  }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // CKSyncEngine subscribes to changes; silent pushes wake the app so the keyboard snapshot stays fresh.
    application.registerForRemoteNotifications()
    #if DEBUG
    // The end-to-end test turns "Save Clipboard on Opening" on only for its own steps ("1"), off otherwise ("0").
    if let autoSave = ProcessInfo.processInfo.environment["PT_AUTO_SAVE"] {
      UserDefaults(suiteName: PastronautIDs.appGroup)?.set(autoSave == "1", forKey: AutoCapture.settingKey)
    }
    // Stands in for another app's copy (the test runner may not write the clipboard from the background).
    // Local only, so Universal Clipboard can't carry it to the Mac and hide a failed save.
    if let text = ProcessInfo.processInfo.environment["PT_E2E_PASTEBOARD"] {
      UIPasteboard.general.setItems([["public.utf8-plain-text": text]], options: [.localOnly: true])
    }
    // The end-to-end test cannot tap the system Paste button (it rejects synthetic touches), so it
    // hands the text over at launch and the same save path runs.
    if let text = ProcessInfo.processInfo.environment["PT_E2E_SAVE"] {
      Task { @MainActor in _ = await ClipStore.shared.saveNow(text) }
    }
    // Runs the keyboard's direct upload (KeyboardCloud) without the app's sync engine, since the test
    // cannot tap the keyboard's Paste button either.
    if let text = ProcessInfo.processInfo.environment["PT_E2E_KEYBOARD_SAVE"], let files = SharedClipFiles() {
      Task {
        let cloud = KeyboardCloud(containerIdentifier: PastronautIDs.iCloudContainer, files: files)
        try? await cloud.save(Clip(text: text, sourceDevice: .iphone))
      }
    }
    #endif
    return true
  }

  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
  ) async -> UIBackgroundFetchResult {
    await ClipStore.shared.refresh()
    return .newData
  }
}
