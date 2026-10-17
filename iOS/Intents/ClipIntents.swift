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
