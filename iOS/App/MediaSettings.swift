import PastronautCore
import SwiftUI

/// Settings › Images & Files (1.3). Everything but the image quality is shared by every device.
struct MediaSettingsView: View {
  @Environment(ClipStore.self) private var store
  /// In the App Group: the Share extension sends images the same way.
  @AppStorage(AppPreferences.mediaQualityKey, store: UserDefaults(suiteName: PastronautIDs.appGroup))
  private var quality = MediaQuality.optimized.rawValue
  @State private var onThisIPhone: Int?
  @State private var isUploading = false

  private var settings: MediaSettings { store.sharedSettings.media }

  var body: some View {
    Form {
      Section {
        Toggle(isOn: shared(\.syncEnabled)) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Sync Images and Files")
            Text("On all your devices")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
        .accessibilityIdentifier("syncMediaToggle")
        Picker("Image Quality", selection: $quality) {
          Text("Optimized").tag(MediaQuality.optimized.rawValue)
          Text("Original").tag(MediaQuality.original.rawValue)
        }
        Picker("Largest Item", selection: shared(\.maxItemBytes)) {
          ForEach(MediaSettings.maxItemChoices, id: \.self) { Text(verbatim: MediaFiles.size($0)).tag($0) }
        }
        Picker("iCloud Space", selection: shared(\.cloudBudgetBytes)) {
          ForEach(MediaSettings.cloudBudgetChoices, id: \.self) { Text(verbatim: MediaFiles.size($0)).tag($0) }
        }
      } footer: {
        VStack(alignment: .leading, spacing: 6) {
          Text("Optimized: HEIC, at most 4,096 pixels. This iPhone's own setting.")
          Text("Every device downloads all images and files, up to the iCloud space. To keep them off mobile data, turn off Mobile Data for Pastronaut in iOS Settings.")
        }
      }
      .disabled(store.status == nil)

      Section {
        let used = store.status?.mediaBytesInCloud ?? 0
        VStack(alignment: .leading, spacing: 8) {
          LabeledContent("Used in iCloud") {
            Text(verbatim: "\(MediaFiles.size(used)) / \(MediaFiles.size(settings.cloudBudgetBytes))")
          }
          ProgressView(value: Double(min(used, settings.cloudBudgetBytes)), total: Double(max(settings.cloudBudgetBytes, 1)))
            .tint(used >= settings.cloudBudgetBytes ? .orange : .accentColor)
        }
        LabeledContent("On This iPhone") {
          if let onThisIPhone {
            Text(verbatim: MediaFiles.size(onThisIPhone))
          } else {
            ProgressView()
          }
        }
      }

      let localMedia = store.clips.filter { $0.isMedia && store.localOnly.clips.contains($0.id) }
      if !localMedia.isEmpty {
        Section {
          LabeledContent("Only on This iPhone") {
            Text(localMedia.count, format: .number)
          }
          Button {
            isUploading = true
            Task {
              await store.uploadLocalOnly()
              isUploading = false
            }
          } label: {
            if isUploading {
              ProgressView()
            } else {
              Text("Upload to iCloud Again")
            }
          }
          .disabled(isUploading)
        } footer: {
          Text("Larger than the limit, or saved while iCloud space was full. Those that fit go up, newest first.")
        }
      }
    }
    .navigationTitle(AppPreferences.shared.string("Images & Files"))
    .navigationBarTitleDisplayMode(.inline)
    .task {
      let store = MediaFiles.store
      onThisIPhone = await Task.detached { store?.totalBytes ?? 0 }.value
    }
  }

  /// A shared setting: shown from iCloud's copy, changed for every device.
  private func shared<Value: Sendable>(_ path: WritableKeyPath<MediaSettings, Value>) -> Binding<Value> {
    Binding {
      store.sharedSettings.media[keyPath: path]
    } set: { value in
      nonisolated(unsafe) let path = path
      store.updateSharedSettings { $0.media[keyPath: path] = value }
    }
  }
}

extension HistoryAge {
  var title: LocalizedStringKey {
    switch self {
    case .forever: "Forever"
    case .day: "1 Day"
    case .week: "1 Week"
    case .month: "1 Month"
    case .year: "1 Year"
    }
  }
}
