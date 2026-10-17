import AppIntents
import PastronautCore
import UIKit
import WidgetKit

// Compiled into the app and the widget extension: widget buttons and controls run these intents.

/// Which clips a widget or Shortcuts action uses.
enum ClipSourceOption: String, AppEnum {
  case all
  case mac
  case iphone
  case pinned

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Source"
  static let caseDisplayRepresentations: [ClipSourceOption: DisplayRepresentation] = [
    .all: DisplayRepresentation(title: "All Devices", image: .init(systemName: "tray")),
    .mac: DisplayRepresentation(title: "Mac", image: .init(systemName: "laptopcomputer")),
    .iphone: DisplayRepresentation(title: "iPhone", image: .init(systemName: "iphone")),
    .pinned: DisplayRepresentation(title: "Pinned", image: .init(systemName: "pin"))
  ]

  var source: ClipSource { ClipSource(rawValue: rawValue) ?? .all }
}

enum ClipClipboard {
  /// Puts a clip on the clipboard and notes it, so "Save Clipboard on Opening" doesn't save it again.
  static func copy(_ text: String) {
    UIPasteboard.general.string = text
    SharedSettings.defaults?.set(UIPasteboard.general.changeCount, forKey: AutoCapture.lastChangeCountKey)
  }

  static var clips: [Clip] { SharedClipFiles()?.currentClips() ?? [] }
}

/// The copy button on a widget row.
struct CopyClipIntent: AppIntent {
  static let title: LocalizedStringResource = "Copy Clip"
  static let isDiscoverable = false

  @Parameter(title: "Clip")
  var clipID: String

  init() {}

  init(clipID: String) {
    self.clipID = clipID
  }

  func perform() async throws -> some IntentResult {
    guard !SharedSettings.isAppLockEnabled,
          let clip = ClipClipboard.clips.first(where: { $0.id == clipID }) else { return .result() }
    ClipClipboard.copy(clip.text)
    let defaults = SharedSettings.defaults
    defaults?.set(clip.id, forKey: SharedSettings.widgetCopiedIDKey)
    defaults?.set(Date.now, forKey: SharedSettings.widgetCopiedAtKey)
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}

/// "Save Clipboard": the Control Center control, the Action button and Siri. iPhone only lets the app in
/// front read the clipboard, so this opens Pastronaut, which saves it.
struct SaveClipboardIntent: AppIntent {
  static let title: LocalizedStringResource = "Save Clipboard"
  static let description = IntentDescription("Opens Pastronaut and saves what's on the clipboard to your history.")
  static let openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    SharedSettings.defaults?.set(true, forKey: SharedSettings.pendingClipboardSaveKey)
    #if !WIDGET_EXTENSION
    await ClipStore.shared.savePendingClipboard()
    #endif
    return .result()
  }
}
