import SwiftUI
import UIKit

@main
struct PastronautApp: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      HistoryView()
        .environment(ClipStore.shared)
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        Task { await ClipStore.shared.refresh() }
      } else if phase == .background {
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
    // The end-to-end test cannot tap the system Paste button (it rejects synthetic touches), so it
    // hands the text over at launch and the same save path runs.
    if let text = ProcessInfo.processInfo.environment["PT_E2E_SAVE"] {
      Task { @MainActor in
        await ClipStore.shared.start()
        ClipStore.shared.save(text)
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
