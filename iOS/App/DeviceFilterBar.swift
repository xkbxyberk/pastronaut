import PastronautCore
import SwiftUI

/// All, Mac and iPhone in one capsule, and a filter button beside it whose menu chooses a kind (in a submenu) and a
/// collection. Kind and collection combine with the source and with each other; what is chosen shows as removable
/// chips under the bar. On iOS 26 and later the capsule is glass and a finger slides its selection (`SourcePicker`).
///
/// The menu is a plain system menu with a glass button style. Given `glassEffect`/`glassEffectID` inside the
/// glass container, it grew out of the bar and was drawn inside it: taps below the bar went to the list behind
/// (1.3, reported on the iPhone).
struct ScopeBar: View {
  @Environment(ClipStore.self) private var store
  @Environment(CollectionActions.self) private var actions
  @Binding var scope: HistoryScope
  /// Clips of each kind with the source and collection kept; kinds without any aren't offered.
  let kindCounts: [ClipKind: Int]
  /// Clips in each collection with the source and kind kept.
  let collectionCounts: [String: Int]

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 10) {
        sources
        filterMenu
      }
      .frame(maxWidth: .infinity, alignment: .center)
      if scope.hasFilters {
        activeFilters
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .padding(.horizontal, 16)
    .animation(.snappy, value: scope)
  }

  // MARK: - Source

  @ViewBuilder
  private var sources: some View {
    if #available(iOS 26.0, *) {
      SourcePicker(selection: $scope.source)
    } else {
      Picker("Device", selection: $scope.source) {
        ForEach(DeviceFilter.allCases) { filter in
          Group {
            if filter == .all {
              Text(filter.title)
            } else {
              Image(systemName: filter.systemImage)
                .accessibilityLabel(Text(filter.title))
            }
          }
          .tag(filter)
          .accessibilityIdentifier("filter.\(filter.rawValue)")
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
      .accessibilityIdentifier("deviceFilter")
    }
  }

  // MARK: - Filter menu

  private var selectedCollection: ClipCollection? {
    scope.collectionID.flatMap { id in store.collections.first { $0.id == id } }
  }

  /// Kinds there are clips of, in the usual order; the chosen one stays even when none are left, so it can be
  /// taken away.
  private var offeredKinds: [ClipKind] {
    ClipKind.allCases.filter { (kindCounts[$0] ?? 0) > 0 || $0 == scope.kind }
  }

  @ViewBuilder
  private var filterMenu: some View {
    let menu = Menu {
      Menu {
        Picker(selection: kindBinding) {
          Text("All Kinds").tag(ClipKind?.none)
          ForEach(offeredKinds, id: \.self) { kind in
            // Menus show no second line here: the count goes after the name, as for collections.
            Label {
              Text(kind.pluralTitle) + Text(verbatim: "  ·  \(kindCounts[kind] ?? 0)")
            } icon: {
              Image(systemName: kind.symbolName)
            }
            .tag(Optional(kind))
            .accessibilityIdentifier("kind.\(kind.rawValue)")
          }
        } label: {
          EmptyView()
        }
        .pickerStyle(.inline)
      } label: {
        Label {
          if let kind = scope.kind {
            Text("Kind") + Text(verbatim: ": ") + Text(kind.pluralTitle)
          } else {
            Text("Kind")
          }
        } icon: {
          Image(systemName: "square.grid.2x2")
        }
      }
      .accessibilityIdentifier("kindMenu")

      Section("Collections") {
        ForEach(store.collections) { collection in
          Button {
            withAnimation(.bouncy(duration: 0.35)) {
              scope.collectionID = scope.collectionID == collection.id ? nil : collection.id
            }
          } label: {
            if scope.collectionID == collection.id {
              Label(collection.name, systemImage: "checkmark")
            } else {
              Text(verbatim: "\(collection.name)  ·  \(collectionCounts[collection.id] ?? 0)")
            }
          }
          .accessibilityIdentifier("collection.\(collection.name)")
        }
        Button("New Collection…", systemImage: "folder.badge.plus") { actions.create(selecting: true) }
          .accessibilityIdentifier("newCollectionChip")
        if let collection = selectedCollection {
          Button("Rename…", systemImage: "pencil") { actions.rename(collection) }
          ExportCollectionLink(collection: collection)
            .accessibilityIdentifier("exportCollection")
          Button("Delete…", systemImage: "trash", role: .destructive) { actions.deleting = collection }
        }
      }

      if scope.hasFilters {
        Section {
          Button("Clear Filters", systemImage: "xmark.circle") {
            withAnimation(.snappy) {
              scope.kind = nil
              scope.collectionID = nil
            }
          }
          .accessibilityIdentifier("clearFilters")
        }
      }
    } label: {
      Image(systemName: "line.3.horizontal.decrease")
        .font(.subheadline.weight(.semibold))
        .frame(width: 20, height: 20)
    }
    .accessibilityLabel(Text("Filters"))
    .accessibilityValue(filterSummary)
    .accessibilityIdentifier("collectionsMenu")

    if #available(iOS 26.0, *) {
      if scope.hasFilters {
        menu
          .buttonStyle(.glassProminent)
          .buttonBorderShape(.circle)
      } else {
        menu
          .buttonStyle(.glass)
          .buttonBorderShape(.circle)
      }
    } else {
      menu
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(scope.hasFilters ? .accentColor : .secondary)
    }
  }

  private var kindBinding: Binding<ClipKind?> {
    Binding { scope.kind } set: { kind in
      withAnimation(.bouncy(duration: 0.35)) { scope.kind = kind }
    }
  }

  /// For VoiceOver: the kind and collection chosen, if any.
  private var filterSummary: Text {
    switch (scope.kind, selectedCollection) {
    case let (kind?, collection?): Text(kind.pluralTitle) + Text(verbatim: ", \(collection.name)")
    case let (kind?, nil): Text(kind.pluralTitle)
    case let (nil, collection?): Text(verbatim: collection.name)
    case (nil, nil): Text(verbatim: "")
    }
  }

  // MARK: - What is chosen

  private var activeFilters: some View {
    HStack(spacing: 8) {
      if let kind = scope.kind {
        chip(Text(kind.pluralTitle), systemImage: kind.symbolName, tint: kind.tint) {
          scope.kind = nil
        }
        .accessibilityIdentifier("activeKind")
      }
      if let collection = selectedCollection {
        chip(Text(verbatim: collection.name), systemImage: "folder", tint: .secondary) {
          scope.collectionID = nil
        }
        .accessibilityIdentifier("activeCollection")
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }

  private func chip(_ title: Text, systemImage: String, tint: Color, remove: @escaping () -> Void) -> some View {
    Button {
      withAnimation(.snappy) { remove() }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: systemImage)
          .foregroundStyle(tint)
        title
          .lineLimit(1)
        Image(systemName: "xmark")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.secondary)
      }
      .font(.footnote.weight(.semibold))
      .foregroundStyle(Color.primary)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .glassBackground(in: Capsule())
    .accessibilityLabel(title)
    .accessibilityHint(Text("Removes this filter"))
  }
}

/// The source as a glass capsule: All (symbol and name), Mac and iPhone (symbols). Touch and slide along it and the
/// selection lens follows the finger, lifted, and settles on the nearest choice when the finger lifts; a tap picks
/// the choice under it. Each choice is still a button for VoiceOver and UI tests.
@available(iOS 26.0, *)
private struct SourcePicker: View {
  @Binding var selection: DeviceFilter
  @State private var frames: [DeviceFilter: CGRect] = [:]
  /// Where the finger is, while it touches the capsule.
  @State private var fingerX: CGFloat?
  private static let space = "sourcePicker"

  var body: some View {
    HStack(spacing: 0) {
      ForEach(DeviceFilter.allCases) { filter in
        segment(filter)
      }
    }
    .padding(3)
    .background(alignment: .topLeading) { lens }
    .coordinateSpace(name: Self.space)
    .contentShape(Capsule())
    .gesture(
      DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
        .onChanged { value in
          if fingerX == nil {
            withAnimation(.snappy(duration: 0.2)) { fingerX = value.location.x }
          } else {
            fingerX = value.location.x
          }
        }
        .onEnded { value in
          let chosen = nearest(to: value.location.x)
          withAnimation(.bouncy(duration: 0.35)) {
            selection = chosen
            fingerX = nil
          }
        }
    )
    .glassEffect(.regular.interactive(), in: Capsule())
    .sensoryFeedback(.selection, trigger: highlighted)
    .fixedSize()
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("deviceFilter")
  }

  /// The choice under the finger while sliding, else the selection.
  private var highlighted: DeviceFilter {
    fingerX.map(nearest(to:)) ?? selection
  }

  private func segment(_ filter: DeviceFilter) -> some View {
    let isOn = highlighted == filter
    return HStack(spacing: 5) {
      Image(systemName: filter.systemImage)
        .font(.footnote.weight(.semibold))
      if filter == .all {
        Text(filter.title)
          .font(.footnote.weight(.semibold))
          .lineLimit(1)
      }
    }
    .foregroundStyle(isOn && fingerX == nil ? Color.onAccent : Color.primary)
    .padding(.horizontal, filter == .all ? 13 : 15)
    .frame(height: 32)
    .contentShape(Capsule())
    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frames[filter] = $0 }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(filter.title))
    .accessibilityAddTraits(selection == filter ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction {
      withAnimation(.bouncy(duration: 0.35)) { selection = filter }
    }
    .accessibilityIdentifier("filter.\(filter.rawValue)")
  }

  /// The tinted capsule behind the selection; while a finger slides, a lifted clear lens that follows it.
  @ViewBuilder
  private var lens: some View {
    if let frame = lensFrame {
      Capsule()
        .fill(fingerX == nil ? Color.accentColor : Color.clear)
        .glassEffect(fingerX == nil ? .identity : .clear.interactive(), in: Capsule())
        .frame(width: frame.width, height: frame.height)
        .scaleEffect(fingerX == nil ? 1 : 1.12)
        .shadow(color: .black.opacity(fingerX == nil ? 0 : 0.15), radius: 8, y: 3)
        .offset(x: frame.minX, y: frame.minY)
        .allowsHitTesting(false)
    }
  }

  private var lensFrame: CGRect? {
    guard let selected = frames[selection] else { return nil }
    guard let fingerX, let first = frames[DeviceFilter.allCases.first!],
          let last = frames[DeviceFilter.allCases.last!] else { return selected }
    // Follows the finger, as wide as the choice under it, kept inside the capsule.
    let width = frames[nearest(to: fingerX)]?.width ?? selected.width
    let x = min(max(fingerX - width / 2, first.minX), last.maxX - width)
    return CGRect(x: x, y: selected.minY, width: width, height: selected.height)
  }

  private func nearest(to x: CGFloat) -> DeviceFilter {
    DeviceFilter.allCases.min { a, b in
      abs((frames[a]?.midX ?? .infinity) - x) < abs((frames[b]?.midX ?? .infinity) - x)
    } ?? selection
  }
}
