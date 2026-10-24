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
      RootView()
        .environment(ClipStore.shared)
        .modifier(AppPreferencesScope())
        .onAppear {
          // The lock, the screen-recording cover and the app-switcher cover live in a window above sheets too.
          if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            PrivacyCover.shared.attach(to: scene)
          }
        }
        .onChange(of: lock.isLocked) { _, isLocked in
          PrivacyCover.shared.update()
          // Opened with Face ID: now the clipboard may be read.
          if !isLocked, scenePhase == .active {
            Task { await saveClipboard() }
          }
        }
    }
    .onChange(of: scenePhase) { _, phase in
      PrivacyCover.shared.sceneBecame(active: phase == .active)
      if phase == .active {
        Task {
          if lock.isLocked {
            // The clipboard waits for the lock: saved by the onChange above once it opens, not when Face ID
            // fails or is cancelled.
            await lock.unlock()
          } else {
            await saveClipboard()
          }
          await ClipStore.shared.refresh()
        }
      } else if phase == .background {
        lock.lock()
        PrivacyCover.shared.update()
        Task { await ClipStore.shared.upload() }
      }
    }
  }

  private func saveClipboard() async {
    await ClipStore.shared.savePendingClipboard()
    await ClipStore.shared.autoSaveClipboard()
  }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // CKSyncEngine subscribes to changes; silent pushes wake the app so the keyboard snapshot stays fresh.
    application.registerForRemoteNotifications()
    AppPreferences.registerFirstLaunchDefaults()
    #if DEBUG
    // The end-to-end test turns "Save Clipboard on Opening" on only for its own steps ("1"), off otherwise ("0").
    if let autoSave = ProcessInfo.processInfo.environment["PT_AUTO_SAVE"] {
      UserDefaults(suiteName: PastronautIDs.appGroup)?.set(autoSave == "1", forKey: AutoCapture.settingKey)
    }
    // Stands in for another app's copy (the test runner may not write the clipboard from the background).
    // Local only, so Universal Clipboard can't carry it to the Mac and hide a failed save.
    if let text = ProcessInfo.processInfo.environment["PT_E2E_PASTEBOARD"] {
      // Empty: nothing on the clipboard at all.
      UIPasteboard.general.setItems(text.isEmpty ? [] : [["public.utf8-plain-text": text]], options: [.localOnly: true])
    }
    // 1.3: an image with this text drawn on it, as if another app had copied a screenshot. Large and plain, so the
    // text recognition reads it back and the test can find the clip by it.
    if let text = ProcessInfo.processInfo.environment["PT_E2E_PASTEBOARD_IMAGE"] {
      let image = UIGraphicsImageRenderer(size: CGSize(width: 1400, height: 320)).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1400, height: 320))
        (text as NSString).draw(at: CGPoint(x: 40, y: 110), withAttributes: [
          .font: UIFont.systemFont(ofSize: 64, weight: .bold), .foregroundColor: UIColor.black
        ])
      }
      if let png = image.pngData() {
        UIPasteboard.general.setItems([["public.png": png]], options: [.localOnly: true])
      }
    }
    // 1.3: a file saved as if shared to Pastronaut ("name|contents"; "name|@bytes:N" makes N bytes of filler).
    if let spec = ProcessInfo.processInfo.environment["PT_E2E_SAVE_FILE"] {
      let parts = spec.split(separator: "|", maxSplits: 1).map(String.init)
      if parts.count == 2 {
        let size = parts[1].hasPrefix("@bytes:") ? Int(parts[1].dropFirst(7)) : nil
        let data = size.map { Data((0..<$0).map { UInt8(truncatingIfNeeded: $0 &* 31) }) } ?? Data(parts[1].utf8)
        Task { @MainActor in
          _ = await ClipStore.shared.saveMedia([MediaIntake.file(named: parts[0], data: data)])
        }
      }
    }
    // 1.3: changes a setting every device shares, as Settings would ("maxItemBytes=…", "codes=1", "cards=0",
    // "pinnedOnly=1", "mediaSync=0"; several separated by commas).
    if let spec = ProcessInfo.processInfo.environment["PT_E2E_SHARED"] {
      let pairs = spec.split(separator: ",").compactMap { pair -> (String, String)? in
        let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
        return parts.count == 2 ? (parts[0], parts[1]) : nil
      }
      Task { @MainActor in
        // After the launch's own sync, so the change is made on top of what iCloud has.
        try? await Task.sleep(for: .seconds(4))
        ClipStore.shared.updateSharedSettings { settings in
          for (key, value) in pairs {
            switch key {
            case "maxItemBytes": settings.media.maxItemBytes = Int(value) ?? settings.media.maxItemBytes
            case "mediaSync": settings.media.syncEnabled = value == "1"
            case "codes": settings.skipOneTimeCodes = value == "1"
            case "cards": settings.skipCardNumbers = value == "1"
            case "pinnedOnly": settings.pinnedOnly = value == "1"
            default: break
            }
          }
        }
      }
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
