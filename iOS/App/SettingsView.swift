import PastronautCore
import SwiftUI
import UIKit

struct SettingsView: View {
  @Environment(ClipStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @AppStorage(AutoCapture.settingKey, store: UserDefaults(suiteName: PastronautIDs.appGroup))
  private var autoSave = false
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
          Text("Text clips sync through your private iCloud database. Clip text is stored encrypted.")
        }

        Section {
          Toggle("Save Clipboard on Opening", isOn: $autoSave)
            .accessibilityIdentifier("autoSaveToggle")
          if autoSave {
            Button("Allow Pasting Without Asking…") {
              if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
              }
            }
          }
        } header: {
          Text("Clipboard")
        } footer: {
          Text("When you open Pastronaut or its keyboard, a new copy is saved by itself. One-time codes, card numbers and IBANs are skipped. iPhone can't read the clipboard in the background, so if you copy several things in a row only the last one is saved; use the Share menu or the Paste button for the others. To stop iOS from asking each time, set Paste from Other Apps to Allow.")
        }

        Section {
          NavigationLink {
            KeyboardSetupView()
          } label: {
            // A plain row: LabeledContent inside a NavigationLink grew to several lines on iOS 27.
            HStack {
              Text("Set Up Keyboard")
              Spacer()
              if setup.isComplete {
                Label("Ready", systemImage: "checkmark.circle.fill")
                  .foregroundStyle(.green)
              } else {
                Text("Not finished")
                  .foregroundStyle(.secondary)
              }
            }
          }
          .accessibilityIdentifier("setupKeyboard")
        } header: {
          Text("Keyboard")
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
