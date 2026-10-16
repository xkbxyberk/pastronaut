import PastronautCore
import SwiftUI

/// All / Mac / iPhone. On iOS 26 and later: glass capsules whose tinted selection flows between them.
struct DeviceFilterBar: View {
  @Binding var selection: DeviceFilter
  /// How many clips each filter shows, for the small count next to the title.
  let counts: [DeviceFilter: Int]
  @Namespace private var glassNamespace

  var body: some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer(spacing: 10) {
        HStack(spacing: 8) {
          ForEach(DeviceFilter.allCases) { filter in
            chip(filter)
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("deviceFilter")
    } else {
      Picker("Device", selection: $selection) {
        ForEach(DeviceFilter.allCases) { filter in
          Text(filter.title).tag(filter)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .accessibilityIdentifier("deviceFilter")
    }
  }

  @available(iOS 26.0, *)
  private func chip(_ filter: DeviceFilter) -> some View {
    let isSelected = selection == filter
    return Button {
      withAnimation(.bouncy(duration: 0.35)) { selection = filter }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: filter.systemImage)
          .font(.footnote.weight(.semibold))
        Text(filter.title)
        if let count = counts[filter] {
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
    .glassEffectID(filter, in: glassNamespace)
    .accessibilityIdentifier("filter.\(filter.rawValue)")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
