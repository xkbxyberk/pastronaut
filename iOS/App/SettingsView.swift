import SwiftUI
import UIKit

struct SettingsView: View {
  @Environment(ClipStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  private let setup = KeyboardSetup.shared

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent("iCloud", value: store.accountStatus)
          LabeledContent("Synced clips", value: store.status.map { "\($0.syncedClips)" } ?? "–")
            .accessibilityIdentifier("syncedClips")
          LabeledContent("Last sync") {
            if let date = store.status?.lastSyncAt {
              Text(date, format: .relative(presentation: .named))
            } else {
              Text(verbatim: "–")
            }
          }
          if let error = store.status?.lastError {
            Text(error).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("syncError")
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
          NavigationLink {
            KeyboardSetupView()
          } label: {
            LabeledContent("Set Up Keyboard") {
              if setup.isComplete {
                Label("Ready", systemImage: "checkmark.circle.fill")
                  .foregroundStyle(.green)
              } else {
                Text("Not finished")
              }
            }
          }
          .accessibilityIdentifier("setupKeyboard")
        } header: {
          Text("Keyboard")
        } footer: {
          Text("To save copies without tapping the paste button, set Settings › Pastronaut › Paste from Other Apps to Allow. iOS then shows a short notice each time.")
        }

        Section("About") {
          LabeledContent("Version", value: Self.version)
          Link("Pastronaut on GitHub", destination: URL(string: "https://github.com/xkbxyberk/pastronaut")!)
          NavigationLink("Licenses") {
            LicensesView()
          }
          Text("Based on Maccy by Alexey Rodionov (MIT). Not affiliated with Maccy.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier("doneButton")
        }
      }
      .onAppear { setup.update() }
    }
  }

  private static var version: String {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "\(short) (\(build))"
  }
}

struct LicensesView: View {
  private let text: String = {
    guard let url = Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt"),
          let text = try? String(contentsOf: url, encoding: .utf8) else {
      return String(localized: "Licenses are missing from this build.")
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
