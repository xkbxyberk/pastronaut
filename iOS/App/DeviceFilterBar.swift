import PastronautCore
import SwiftUI

/// All / Mac / iPhone and one chip for collections, which opens a menu (choose, new, rename, delete). The bar never
/// scrolls: when space runs short the chips drop their counts, then their titles. On iOS 26 and later: glass
/// capsules whose tinted selection flows between them.
struct ScopeBar: View {
  @Environment(ClipStore.self) private var store
  @Environment(CollectionActions.self) private var actions
  @Binding var scope: HistoryScope
  /// How many clips each chip shows, for the small count next to the title.
  let counts: [DeviceFilter: Int]
  let collectionCounts: [String: Int]
  @Namespace private var glassNamespace

  enum Density { case full, noCounts, iconsOnly }

  var body: some View {
    if #available(iOS 26.0, *) {
      ViewThatFits(in: .horizontal) {
        glassRow(.full)
        glassRow(.noCounts)
        glassRow(.iconsOnly)
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("deviceFilter")
    } else {
      HStack(spacing: 8) {
        Picker("Device", selection: $scope) {
          ForEach(DeviceFilter.allCases) { filter in
            Text(filter.title).tag(HistoryScope.device(filter))
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("deviceFilter")
        collectionsMenu {
          collectionLabel(.noCounts)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(selectedCollection == nil ? Color(uiColor: .tertiarySystemFill) : Color.accentColor))
            .foregroundStyle(selectedCollection == nil ? Color.primary : Color.onAccent)
        }
      }
    }
  }

  private var selectedCollection: ClipCollection? {
    scope.collectionID.flatMap { id in store.collections.first { $0.id == id } }
  }

  @available(iOS 26.0, *)
  private func glassRow(_ density: Density) -> some View {
    GlassEffectContainer(spacing: 8) {
      HStack(spacing: 6) {
        ForEach(DeviceFilter.allCases) { filter in
          deviceChip(filter, density: density)
            .accessibilityIdentifier("filter.\(filter.rawValue)")
        }
        collectionsMenu {
          collectionLabel(density)
            .padding(.horizontal, selectedCollection == nil ? 11 : 12)
            .padding(.vertical, 9)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(
          selectedCollection == nil ? .regular.interactive() : .regular.tint(.accentColor).interactive(),
          in: Capsule()
        )
        .glassEffectID("collections", in: glassNamespace)
      }
      .fixedSize()
    }
  }

  @available(iOS 26.0, *)
  private func deviceChip(_ filter: DeviceFilter, density: Density) -> some View {
    let isSelected = scope == .device(filter)
    return Button {
      withAnimation(.bouncy(duration: 0.35)) { scope = .device(filter) }
    } label: {
      HStack(spacing: 5) {
        Image(systemName: filter.systemImage)
          .font(.footnote.weight(.semibold))
        if density != .iconsOnly {
          Text(filter.title)
            .lineLimit(1)
        }
        if density == .full, let count = counts[filter] {
          Text(count, format: .number)
            .font(.footnote.monospacedDigit())
            .opacity(0.7)
        }
      }
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(isSelected ? Color.onAccent : Color.primary)
      .padding(.horizontal, density == .iconsOnly ? 11 : 12)
      .padding(.vertical, 9)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .glassEffect(isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: Capsule())
    .glassEffectID(HistoryScope.device(filter), in: glassNamespace)
    .accessibilityLabel(Text(filter.title))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  /// A folder, or the chosen collection's name, with a small chevron: it opens a menu.
  private func collectionLabel(_ density: Density) -> some View {
    HStack(spacing: 5) {
      if let collection = selectedCollection {
        Image(systemName: "folder.fill")
          .font(.footnote.weight(.semibold))
        Text(verbatim: collection.name)
          .lineLimit(1)
          .frame(maxWidth: density == .iconsOnly ? 70 : 110, alignment: .leading)
          .fixedSize(horizontal: density != .iconsOnly, vertical: false)
        if density == .full, let count = collectionCounts[collection.id] {
          Text(count, format: .number)
            .font(.footnote.monospacedDigit())
            .opacity(0.7)
        }
      } else {
        Image(systemName: "folder")
          .font(.footnote.weight(.semibold))
      }
      Image(systemName: "chevron.down")
        .font(.caption2.weight(.bold))
        .opacity(0.6)
    }
    .font(.subheadline.weight(.semibold))
    .foregroundStyle(selectedCollection == nil ? Color.primary : Color.onAccent)
  }

  private func collectionsMenu(@ViewBuilder label: () -> some View) -> some View {
    Menu {
      Section {
        ForEach(store.collections) { collection in
          Button {
            withAnimation(.bouncy(duration: 0.35)) { scope = .collection(collection.id) }
          } label: {
            if scope == .collection(collection.id) {
              Label(collection.name, systemImage: "checkmark")
            } else {
              Text(verbatim: "\(collection.name)  ·  \(collectionCounts[collection.id] ?? 0)")
            }
          }
          .accessibilityIdentifier("collection.\(collection.name)")
        }
      }
      Section {
        Button("New Collection…", systemImage: "folder.badge.plus") { actions.create(selecting: true) }
          .accessibilityIdentifier("newCollectionChip")
        if let collection = selectedCollection {
          Button("Rename…", systemImage: "pencil") { actions.rename(collection) }
          Button("Delete…", systemImage: "trash", role: .destructive) { actions.deleting = collection }
        }
      }
    } label: {
      label()
    }
    .accessibilityLabel(Text("Collections"))
    .accessibilityValue(Text(verbatim: selectedCollection?.name ?? ""))
    .accessibilityIdentifier("collectionsMenu")
  }
}
