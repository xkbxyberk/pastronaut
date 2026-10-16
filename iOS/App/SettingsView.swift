import SwiftUI
import UIKit

struct SettingsView: View {
  @Environment(ClipStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent("iCloud", value: store.accountStatus)
          LabeledContent("Synced clips", value: store.status.map { "\($0.syncedClips)" } ?? "–")
          LabeledContent("Last sync") {
            if let date = store.status?.lastSyncAt {
              Text(date, style: .relative)
            } else {
              Text("–")
            }
          }
          if let error = store.status?.lastError {
            Text(error).font(.footnote).foregroundStyle(.red)
          }
          Button("Sync Now") {
            Task { await store.refresh() }
          }
        } header: {
          Text("Sync")
        } footer: {
          Text("Text clips sync through your private iCloud database. Clip text is end-to-end encrypted.")
        }

        Section {
          Text("1. Open Settings › General › Keyboard › Keyboards › Add New Keyboard and choose Pastronaut.")
          Text("2. Tap Pastronaut in the list and turn on Allow Full Access. Without it the keyboard still shows your history, but cannot save new copies.")
          Text("3. In any text field, hold 🌐 and pick Pastronaut. Tap a clip to type it.")
          Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
          }
        } header: {
          Text("Keyboard")
        } footer: {
          Text("To save copies without tapping the paste button, set Settings › Pastronaut › Paste from Other Apps to Allow. iOS then shows a short notice each time.")
        }

        Section("About") {
          Link("Pastronaut on GitHub", destination: URL(string: "https://github.com/xkbxyberk/pastronaut")!)
          Text("Based on Maccy by Alexey Rodionov (MIT). Not affiliated with Maccy.")
            .font(.footnote)
          NavigationLink("Licenses") {
            LicensesView()
          }
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}

struct LicensesView: View {
  private let text: String = {
    guard let url = Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt"),
          let text = try? String(contentsOf: url, encoding: .utf8) else {
      return "Licenses are missing from this build."
    }
    return text
  }()

  var body: some View {
    ScrollView {
      Text(text)
        .font(.caption.monospaced())
        .textSelection(.enabled)
        .padding()
    }
    .navigationTitle("Licenses")
  }
}
