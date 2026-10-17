import AppKit
import Defaults
import Observation
import PastronautCore
import SwiftUI
import UniformTypeIdentifiers

// Collections on the Mac. They live in iCloud with the clips (ClipSync); this Mac keeps a copy of the list and of
// which clip is in which collection, so the popup can filter and the history can keep those clips. Without iCloud
// sync there are no collections here.

/// What the popup and the settings show about collections. Updated by SyncBridge after every sync change.
@MainActor
@Observable
final class SyncedCollections {
  static let shared = SyncedCollections()

  private(set) var collections: [ClipCollection] = []
  /// Clip ID → its collections.
  private(set) var membership: [String: [String]] = [:]
  /// iCloud sync is on, so collections can be used.
  private(set) var isAvailable = false

  private init() {}

  func update(collections: [ClipCollection], clips: [Clip], isAvailable: Bool) {
    let known = Set(collections.map(\.id))
    var membership: [String: [String]] = [:]
    for clip in clips {
      let ids = clip.collectionIDs.filter(known.contains)
      if !ids.isEmpty { membership[clip.id] = ids }
    }
    if collections != self.collections { self.collections = collections }
    if membership != self.membership { self.membership = membership }
    if isAvailable != self.isAvailable { self.isAvailable = isAvailable }
    if let filter = History.shared.collectionFilter, !known.contains(filter) {
      History.shared.collectionFilter = nil
    }
  }

  func collectionIDs(of item: HistoryItem) -> [String] {
    SyncBridge.clipID(of: item).flatMap { membership[$0] } ?? []
  }

  func contains(_ item: HistoryItem, in collectionID: String) -> Bool {
    collectionIDs(of: item).contains(collectionID)
  }

  /// In a collection: history limits, "Keep history" and Clear leave it alone, like a pinned item.
  func isKept(_ item: HistoryItem) -> Bool {
    guard !membership.isEmpty else { return false }
    return !collectionIDs(of: item).isEmpty
  }

  func count(in collectionID: String) -> Int {
    membership.values.count { $0.contains(collectionID) }
  }

  func collection(withID id: String) -> ClipCollection? {
    collections.first { $0.id == id }
  }
}

// MARK: - Asking for a name

@MainActor
enum CollectionPrompt {
  /// A small alert with a text field; nil when cancelled or empty.
  static func askName(title: String, confirm: String, initial: String = "") -> String? {
    let alert = NSAlert()
    alert.messageText = title
    alert.addButton(withTitle: confirm)
    alert.addButton(withTitle: String(localized: "Cancel", table: "Pastronaut"))
    let field = NSTextField(string: initial)
    field.placeholderString = String(localized: "Name", table: "Pastronaut")
    field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
    alert.accessoryView = field
    alert.window.initialFirstResponder = field
    NSApp.activate(ignoringOtherApps: true)
    guard alert.runModal() == .alertFirstButtonReturn else { return nil }
    return ClipCollection.cleanName(field.stringValue)
  }

  /// Asks for a name, creates the collection and puts `items` in it.
  static func createCollection(with items: [HistoryItem]) {
    AppState.shared.popup.close()
    guard let name = askName(
      title: String(localized: "New Collection", table: "Pastronaut"),
      confirm: String(localized: "Create", table: "Pastronaut")
    ) else { return }
    SyncBridge.shared.createCollection(named: name, with: items)
  }

  static func rename(_ collection: ClipCollection) {
    guard let name = askName(
      title: String(localized: "Rename Collection", table: "Pastronaut"),
      confirm: String(localized: "Rename", table: "Pastronaut"),
      initial: collection.name
    ), name != collection.name else { return }
    SyncBridge.shared.rename(collection, to: name)
  }
}

// MARK: - Popup

/// "Add to Collection" in a row's context menu.
struct CollectionsContextMenu: View {
  let item: HistoryItemDecorator
  private let collections = SyncedCollections.shared

  var body: some View {
    if collections.isAvailable, SyncBridge.shared.canCollect(item.item) {
      Menu {
        ForEach(collections.collections) { collection in
          Toggle(isOn: Binding(
            get: { collections.contains(item.item, in: collection.id) },
            set: { SyncBridge.shared.setMembership($0, of: [item.item], in: collection.id) }
          )) {
            Text(verbatim: collection.name)
          }
        }
        if !collections.collections.isEmpty {
          Divider()
        }
        Button {
          CollectionPrompt.createCollection(with: [item.item])
        } label: {
          Text("New Collection…", tableName: "Pastronaut")
        }
        .accessibilityIdentifier("context-new-collection")
      } label: {
        Label { Text("Add to Collection", tableName: "Pastronaut") } icon: { Image(systemName: "folder.badge.plus") }
      }
      .accessibilityIdentifier("context-collections")
    }
  }
}

/// The collections section of the filter menu: one collection at a time.
struct CollectionFilterSection: View {
  @Environment(AppState.self) private var appState
  private let collections = SyncedCollections.shared

  var body: some View {
    if collections.isAvailable, !collections.collections.isEmpty {
      Section {
        ForEach(collections.collections) { collection in
          Toggle(isOn: Binding(
            get: { appState.history.collectionFilter == collection.id },
            set: { appState.history.collectionFilter = $0 ? collection.id : nil }
          )) {
            Label { Text(verbatim: collection.name) } icon: { Image(systemName: "folder") }
          }
        }
      } header: {
        Text("Collections", tableName: "Pastronaut")
      }
    }
  }
}

/// The collections an item belongs to, under its preview.
struct CollectionBadges: View {
  let item: HistoryItem
  private let collections = SyncedCollections.shared

  var body: some View {
    let names = collections.collectionIDs(of: item).compactMap { collections.collection(withID: $0)?.name }
    if !names.isEmpty {
      HStack(spacing: 4) {
        Image(systemName: "folder")
        Text(verbatim: names.formatted(.list(type: .and)))
          .lineLimit(1)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.bottom, 8)
    }
  }
}

// MARK: - Settings

/// Rename and delete collections, in Sync settings.
struct CollectionsSettingsSection: View {
  private let collections = SyncedCollections.shared
  @State private var deleting: ClipCollection?

  var body: some View {
    Section {
      if collections.collections.isEmpty {
        Text("Right-click a clip and choose Add to Collection to start one.", tableName: "Pastronaut")
          .foregroundStyle(.secondary)
      }
      ForEach(collections.collections) { collection in
        HStack {
          Label { Text(verbatim: collection.name) } icon: { Image(systemName: "folder") }
          Spacer()
          Text(collections.count(in: collection.id), format: .number)
            .foregroundStyle(.secondary)
            .monospacedDigit()
          Menu {
            Button {
              CollectionPrompt.rename(collection)
            } label: {
              Text("Rename…", tableName: "Pastronaut")
            }
            Button(role: .destructive) {
              deleting = collection
            } label: {
              Text("Delete…", tableName: "Pastronaut")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
          .menuStyle(.borderlessButton)
          .menuIndicator(.hidden)
          .fixedSize()
        }
      }
      Button {
        CollectionPrompt.createCollection(with: [])
      } label: {
        Text("New Collection…", tableName: "Pastronaut")
      }
    } header: {
      Text("Collections", tableName: "Pastronaut")
    } footer: {
      Text("Collections sync with your iPhone. Clips in a collection are kept like pinned ones: the history limit, Keep history and Clear leave them alone.", tableName: "Pastronaut")
        .foregroundStyle(.secondary)
    }
    .disabled(!collections.isAvailable)
    .confirmationDialog(
      Text("Delete \"\(deleting?.name ?? "")\"?", tableName: "Pastronaut"),
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button(role: .destructive) {
        if let deleting { SyncBridge.shared.deleteCollection(deleting) }
        deleting = nil
      } label: {
        Text("Delete Collection", tableName: "Pastronaut")
      }
    } message: {
      Text("The collection is removed from all your devices. Its clips stay in your history.", tableName: "Pastronaut")
    }
  }
}

// MARK: - Export and import

/// Export and import in Storage settings: text clips with pins and collections, in Pastronaut's JSON file.
struct HistoryArchiveSetting: View {
  @State private var message: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Button {
          export()
        } label: {
          Text("Export…", tableName: "Pastronaut")
        }
        Button {
          importFile()
        } label: {
          Text("Import…", tableName: "Pastronaut")
        }
      }
      Text(message ?? String(localized: "Text clips, pins and collections. Images and files are not included.", table: "Pastronaut"))
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func export() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = ClipArchive.suggestedFileName()
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let archive = SyncBridge.shared.makeArchive()
      try archive.encoded().write(to: url, options: .atomic)
      message = String(localized: "Exported \(archive.clips.count) clips.", table: "Pastronaut")
    } catch {
      message = error.localizedDescription
    }
  }

  private func importFile() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let archive = try ClipArchive.decode(Data(contentsOf: url))
      let added = SyncBridge.shared.importArchive(archive)
      message = String(localized: "Imported \(added) new clips.", table: "Pastronaut")
    } catch ClipArchive.ReadError.newerVersion {
      message = String(localized: "This file was made by a newer Pastronaut.", table: "Pastronaut")
    } catch ClipArchive.ReadError.notAnArchive {
      message = String(localized: "This isn't a Pastronaut export.", table: "Pastronaut")
    } catch {
      message = error.localizedDescription
    }
  }
}
