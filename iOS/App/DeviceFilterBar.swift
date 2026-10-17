import PastronautCore
import SwiftUI

/// All / Mac / iPhone, then the collections and a button for a new one. On iOS 26 and later: glass capsules whose
/// tinted selection flows between them, in a row that scrolls when collections don't fit.
struct ScopeBar: View {
  @Environment(ClipStore.self) private var store
  @Environment(CollectionActions.self) private var actions
  @Binding var scope: HistoryScope
  /// How many clips each chip shows, for the small count next to the title.
  let counts: [DeviceFilter: Int]
  let collectionCounts: [String: Int]
  @Namespace private var glassNamespace

  var body: some View {
    if #available(iOS 26.0, *) {
      ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        GlassEffectContainer(spacing: 10) {
          HStack(spacing: 8) {
            ForEach(DeviceFilter.allCases) { filter in
              chip(.device(filter), systemImage: filter.systemImage, count: counts[filter]) {
                Text(filter.title)
              }
              .accessibilityIdentifier("filter.\(filter.rawValue)")
            }
            ForEach(store.collections) { collection in
              chip(.collection(collection.id), systemImage: "folder", count: collectionCounts[collection.id]) {
                Text(verbatim: collection.name)
              }
              .contextMenu { collectionMenu(collection) }
              .accessibilityIdentifier("collection.\(collection.name)")
            }
            Button {
              actions.create(selecting: true)
            } label: {
              Image(systemName: "folder.badge.plus")
                .font(.subheadline.weight(.semibold))
                .padding(9)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel(Text("New Collection"))
            .accessibilityIdentifier("newCollectionChip")
          }
          .padding(.vertical, 2)
        }
      }
      .contentMargins(.horizontal, 16, for: .scrollContent)
      .scrollIndicators(.hidden)
      .scrollClipDisabled()
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("deviceFilter")
      // A collection chosen elsewhere (a new one, the iPad sidebar) is brought into view.
      .onChange(of: scope) {
        withAnimation(.snappy) { proxy.scrollTo(scope, anchor: .center) }
      }
      .onAppear { proxy.scrollTo(scope, anchor: .center) }
      }
    } else {
      VStack(alignment: .leading, spacing: 8) {
        Picker("Device", selection: $scope) {
          ForEach(DeviceFilter.allCases) { filter in
            Text(filter.title).tag(HistoryScope.device(filter))
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("deviceFilter")
        ScrollView(.horizontal) {
          HStack(spacing: 6) {
            ForEach(store.collections) { collection in
              let isSelected = scope == .collection(collection.id)
              Button {
                scope = isSelected ? .all : .collection(collection.id)
              } label: {
                Label(collection.name, systemImage: "folder")
                  .font(.subheadline)
              }
              .buttonStyle(.bordered)
              .buttonBorderShape(.capsule)
              .tint(isSelected ? .accentColor : .secondary)
              .contextMenu { collectionMenu(collection) }
            }
            Button {
              actions.create(selecting: true)
            } label: {
              Label("New Collection", systemImage: "folder.badge.plus")
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("newCollectionChip")
          }
        }
        .scrollIndicators(.hidden)
      }
    }
  }

  @ViewBuilder
  private func collectionMenu(_ collection: ClipCollection) -> some View {
    Button("Rename…", systemImage: "pencil") { actions.rename(collection) }
    Button("Delete…", systemImage: "trash", role: .destructive) { actions.deleting = collection }
  }

  @available(iOS 26.0, *)
  private func chip(_ chipScope: HistoryScope, systemImage: String, count: Int?, @ViewBuilder title: () -> Text) -> some View {
    let isSelected = scope == chipScope
    return Button {
      withAnimation(.bouncy(duration: 0.35)) { scope = chipScope }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: systemImage)
          .font(.footnote.weight(.semibold))
        title()
          .lineLimit(1)
        if let count {
          Text(count, format: .number)
            .font(.footnote.monospacedDigit())
            .opacity(0.7)
        }
      }
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(isSelected ? Color.onAccent : Color.primary)
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .glassEffect(isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: Capsule())
    .glassEffectID(chipScope, in: glassNamespace)
    .id(chipScope)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
