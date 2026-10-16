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
