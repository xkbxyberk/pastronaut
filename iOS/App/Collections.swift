import PastronautCore
import SwiftUI
import UIKit

/// What the history shows: one device's clips, or one collection.
enum HistoryScope: Hashable {
  case device(DeviceFilter)
  case collection(String)

  static let all = HistoryScope.device(.all)

  func includes(_ clip: Clip) -> Bool {
    switch self {
    case .device(let filter): filter.includes(clip)
    case .collection(let id): clip.isIn(id)
    }
  }

  var collectionID: String? {
    if case .collection(let id) = self { return id }
    return nil
  }
}

// MARK: - Creating, renaming and deleting

/// Collection prompts that any screen can open; `CollectionDialogs` shows them once, at the root.
@MainActor
@Observable
final class CollectionActions {
  /// The clips a new collection starts with; nil when no prompt is open.
  var creating: [Clip]?
  /// Show the new collection once it exists (when made from the collection list, not from a clip).
  var selectsCreated = false
  var renaming: ClipCollection?
  var deleting: ClipCollection?
  var name = ""

  func create(with clips: [Clip] = [], selecting: Bool = false) {
    name = ""
    selectsCreated = selecting
    creating = clips
  }

  func rename(_ collection: ClipCollection) {
    name = collection.name
    renaming = collection
  }
}

struct CollectionDialogs: ViewModifier {
  @Environment(ClipStore.self) private var store
  @Bindable var actions: CollectionActions
  @Binding var scope: HistoryScope

  func body(content: Content) -> some View {
    content
      .alert(
        "New Collection",
        isPresented: Binding(get: { actions.creating != nil }, set: { if !$0 { actions.creating = nil } })
      ) {
        TextField("Name", text: $actions.name)
          .accessibilityIdentifier("collectionNameField")
        Button("Create") {
          let members = actions.creating ?? []
          if let created = store.createCollection(named: actions.name, with: members), actions.selectsCreated {
            scope = .collection(created.id)
          }
          actions.creating = nil
        }
        .accessibilityIdentifier("createCollectionButton")
        Button("Cancel", role: .cancel) { actions.creating = nil }
      } message: {
        Text("Clips in a collection are kept until you delete them, like pinned ones, and sync to your Mac.")
      }
      .alert(
        "Rename Collection",
        isPresented: Binding(get: { actions.renaming != nil }, set: { if !$0 { actions.renaming = nil } })
      ) {
        TextField("Name", text: $actions.name)
        Button("Rename") {
          if let collection = actions.renaming { store.rename(collection, to: actions.name) }
          actions.renaming = nil
        }
        Button("Cancel", role: .cancel) { actions.renaming = nil }
      }
      .confirmationDialog(
        Text("Delete \"\(actions.deleting?.name ?? "")\"?"),
        isPresented: Binding(get: { actions.deleting != nil }, set: { if !$0 { actions.deleting = nil } }),
        titleVisibility: .visible
      ) {
        Button("Delete Collection", role: .destructive) {
          if let collection = actions.deleting {
            if scope == .collection(collection.id) { scope = .all }
            store.deleteCollection(collection)
          }
          actions.deleting = nil
        }
      } message: {
        Text("The collection is removed from all your devices. Its clips stay in your history.")
      }
  }
}

/// "Add to Collection" for one clip or a selection: a toggle per collection and "New Collection…".
struct CollectionMenu<Label: View>: View {
  @Environment(ClipStore.self) private var store
  @Environment(CollectionActions.self) private var actions
  let clips: [Clip]
  @ViewBuilder let label: () -> Label

  var body: some View {
    Menu {
      ForEach(store.collections) { collection in
        Toggle(isOn: Binding(
          get: { !clips.isEmpty && clips.allSatisfy { $0.isIn(collection.id) } },
          set: { store.setMembership($0, of: clips, in: collection.id) }
        )) {
          SwiftUI.Label(collection.name, systemImage: "folder")
        }
      }
      if !store.collections.isEmpty {
        Divider()
      }
      Button {
        actions.create(with: clips)
      } label: {
        SwiftUI.Label("New Collection…", systemImage: "folder.badge.plus")
      }
      .accessibilityIdentifier("newCollectionMenuItem")
    } label: {
      label()
    }
    .accessibilityIdentifier("collectionMenu")
  }
}

extension CollectionMenu where Label == SwiftUI.Label<Text, Image> {
  init(clips: [Clip]) {
    self.init(clips: clips) {
      SwiftUI.Label("Add to Collection", systemImage: "folder.badge.plus")
    }
  }
}

// MARK: - iPad

/// The iPad's sidebar: devices, then collections. Clips dropped on a collection join it.
struct ScopeSidebar: View {
  @Environment(ClipStore.self) private var store
  @Environment(CollectionActions.self) private var actions
  @Binding var scope: HistoryScope

  var body: some View {
    List(selection: Binding<HistoryScope?>(get: { scope }, set: { scope = $0 ?? .all })) {
      Section {
        ForEach(DeviceFilter.allCases) { filter in
          row(title: filter.title, systemImage: filter.systemImage, count: store.clips.filter(filter.includes).count)
            .tag(HistoryScope.device(filter))
            .accessibilityIdentifier("sidebar.\(filter.rawValue)")
        }
      }
      Section {
        ForEach(store.collections) { collection in
          row(title: LocalizedStringKey(collection.name), verbatim: collection.name, systemImage: "folder",
              count: store.clips(in: collection.id).count)
            .tag(HistoryScope.collection(collection.id))
            .dropDestination(for: String.self) { texts, _ in
              store.addDropped(texts, to: collection.id)
              return !texts.isEmpty
            }
            .contextMenu {
              Button("Rename…", systemImage: "pencil") { actions.rename(collection) }
              ExportCollectionLink(collection: collection)
              Button("Delete…", systemImage: "trash", role: .destructive) { actions.deleting = collection }
            }
        }
        Button {
          actions.create(selecting: true)
        } label: {
          Label("New Collection", systemImage: "plus")
        }
        .accessibilityIdentifier("sidebarNewCollection")
      } header: {
        Text("Collections")
      }
    }
    .navigationTitle(Text(verbatim: "Pastronaut"))
  }

  private func row(title: LocalizedStringKey, verbatim: String? = nil, systemImage: String, count: Int) -> some View {
    HStack {
      if let verbatim {
        Label { Text(verbatim: verbatim) } icon: { Image(systemName: systemImage) }
      } else {
        Label(title, systemImage: systemImage)
      }
      Spacer()
      Text(count, format: .number)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
  }
}

/// The phone shows the history with a scope bar; a regular-width iPad adds the sidebar instead.
struct RootView: View {
  @Environment(ClipStore.self) private var store
  @Environment(\.horizontalSizeClass) private var sizeClass
  @Environment(\.scenePhase) private var scenePhase
  @State private var scope = HistoryScope.all
  @State private var actions = CollectionActions()

  var body: some View {
    Group {
      if sizeClass == .regular {
        NavigationSplitView {
          ScopeSidebar(scope: $scope)
        } detail: {
          HistoryView(scope: $scope, showsScopeBar: false)
        }
      } else {
        HistoryView(scope: $scope, showsScopeBar: true)
      }
    }
    .environment(actions)
    .modifier(CollectionDialogs(actions: actions, scope: $scope))
    // The collection on screen was deleted on another device: back to all clips.
    .onChange(of: store.collections) {
      if let id = scope.collectionID, !store.collections.contains(where: { $0.id == id }) {
        scope = .all
      }
    }
    .task(id: scenePhase) {
      // iPad: Pastronaut can stay on screen next to the app you copy from. With "Save Clipboard on Opening" on,
      // a new copy is saved while it is visible (checking for one never shows the paste prompt).
      guard UIDevice.current.userInterfaceIdiom == .pad, scenePhase == .active else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1.5))
        await ClipStore.shared.autoSaveClipboard()
      }
    }
  }
}
