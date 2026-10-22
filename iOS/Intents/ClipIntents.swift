import AppIntents
import PastronautCore
import UIKit
import WidgetKit

// Compiled into the app and the widget extension: widget buttons and controls run these intents.

/// Which clips a widget or Shortcuts action uses. Shortcuts and Siri names can't contain Apple product names
/// ("Mac", "iPhone"; App Review ITMS-90626), so the devices are "Computer" and "Phone" here.
enum ClipSourceOption: String, AppEnum {
  case all
  case computer
  case phone
  case pinned

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Source"
  static let caseDisplayRepresentations: [ClipSourceOption: DisplayRepresentation] = [
    .all: DisplayRepresentation(title: "All Devices", image: .init(systemName: "tray")),
    .computer: DisplayRepresentation(title: "Computer", image: .init(systemName: "laptopcomputer")),
    .phone: DisplayRepresentation(title: "Phone", image: .init(systemName: "smartphone")),
    .pinned: DisplayRepresentation(title: "Pinned", image: .init(systemName: "pin"))
  ]

  var source: ClipSource {
    switch self {
    case .all: .all
    case .computer: .mac
    case .phone: .iphone
    case .pinned: .pinned
    }
  }
}

/// A collection for Shortcuts parameters and the widget's settings, read from the app group's collections.json.
struct CollectionEntity: AppEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Collection"
  static let defaultQuery = CollectionEntityQuery()

  let id: String
  let name: String

  init(_ collection: ClipCollection) {
    id = collection.id
    name = collection.name
  }

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)", image: .init(systemName: "folder"))
  }

  static var all: [CollectionEntity] {
    (SharedClipFiles()?.currentCollections() ?? []).sorted { $0.order < $1.order }.map(CollectionEntity.init)
  }
}

struct CollectionEntityQuery: EntityStringQuery {
  func entities(for identifiers: [String]) async throws -> [CollectionEntity] {
    CollectionEntity.all.filter { identifiers.contains($0.id) }
  }

  func entities(matching string: String) async throws -> [CollectionEntity] {
    CollectionEntity.all.filter { $0.name.localizedStandardContains(string) }
  }

  func suggestedEntities() async throws -> [CollectionEntity] {
    CollectionEntity.all
  }
}

extension ClipSourceOption {
  /// The newest `count` clips from this source, only those in `collection` when one is given.
  func latest(in collection: CollectionEntity?, count: Int) -> [Clip] {
    let clips = ClipClipboard.clips.filter { clip in collection.map { clip.isIn($0.id) } ?? true }
    return source.latest(from: clips, count: count)
  }
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

/// "Pause Saving" (Control Center, Lock Screen, Action button): while on, Pastronaut and its keyboard don't save
/// the clipboard by themselves. On is for an hour, so a forgotten pause ends by itself.
struct PauseSavingIntent: SetValueIntent {
  static let title: LocalizedStringResource = "Pause Saving"
  static let description = IntentDescription("Pastronaut and its keyboard stop saving the clipboard by themselves for an hour.")

  @Parameter(title: "Paused")
  var value: Bool

  static let controlKind = "com.xkbxyberk.pastronaut.pause-saving"

  func perform() async throws -> some IntentResult {
    if value {
      SavingPause.pause(.oneHour, in: SharedSettings.defaults)
    } else {
      SavingPause.resume(in: SharedSettings.defaults)
    }
    return .result()
  }
}
