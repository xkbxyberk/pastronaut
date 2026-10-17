import PastronautCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
  @Environment(ClipStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @AppStorage(AutoCapture.settingKey, store: UserDefaults(suiteName: PastronautIDs.appGroup))
  private var autoSave = false
  @AppStorage(SpotlightIndex.settingKey) private var spotlight = false
  @AppStorage(PreviewChoice.key) private var previewChoice = PreviewChoice.unasked.rawValue
  @State private var isImporting = false
  @State private var importMessage: String?
  private let setup = KeyboardSetup.shared
  private let lock = AppLock.shared

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
          Text("Text clips sync through your private iCloud database. Clip text and collection names are end-to-end encrypted, and iCloud can't tell which texts you saved.")
        }

        Section {
          Toggle("Link and Map Previews", isOn: Binding(
            get: { previewChoice == PreviewChoice.on.rawValue },
            set: { isOn in
              previewChoice = isOn ? PreviewChoice.on.rawValue : PreviewChoice.off.rawValue
              if !isOn { PreviewStore.shared.clear() }
            }
          ))
          .accessibilityIdentifier("previewsToggle")
        } header: {
          Text("Appearance")
        } footer: {
          Text("With previews on, the history shows cards: links with their page, addresses with a map, code in color. This iPhone opens the link and asks Apple Maps for the address; sign-in and reset links are never opened. With previews off, the history is a compact list.")
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
          Toggle(isOn: Binding(get: { lock.isEnabled }, set: { value in Task { await lock.setEnabled(value) } })) {
            Text("Lock with \(lock.methodName)")
          }
          .accessibilityIdentifier("appLockToggle")
          Toggle("Show Pinned Clips in Search", isOn: $spotlight)
            .disabled(lock.isEnabled)
            .onChange(of: spotlight) { SpotlightIndex.update(with: store.clips) }
            .accessibilityIdentifier("spotlightToggle")
        } header: {
          Text("Privacy")
        } footer: {
          Text("Pastronaut asks for \(lock.methodName) when you open it, and widgets hide your clips. The keyboard stays available, because iPhone keyboards can't ask for \(lock.methodName). Pinned clips can show up when you search your iPhone; choosing one copies it. Search stays off while the lock is on.")
        }

        Section {
          ShareLink(
            item: ArchiveFile(archive: store.makeArchive()),
            preview: SharePreview(Text(verbatim: ClipArchive.suggestedFileName()), image: Image(systemName: "doc.text"))
          ) {
            Label("Export History", systemImage: "square.and.arrow.up")
          }
          .accessibilityIdentifier("exportButton")
          Button {
            isImporting = true
          } label: {
            Label("Import…", systemImage: "square.and.arrow.down")
          }
          .accessibilityIdentifier("importButton")
        } header: {
          Text("Your Data")
        } footer: {
          Text("Text clips, pins and collections in one file, for a backup or another device. Importing only adds; nothing is removed.")
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
      .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
        guard case .success(let url) = result else { return }
        importFile(at: url)
      }
      .alert(
        Text(importMessage ?? ""),
        isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })
      ) {
        Button("OK", role: .cancel) { importMessage = nil }
      }
    }
  }

  private func importFile(at url: URL) {
    let isScoped = url.startAccessingSecurityScopedResource()
    let data = Result { try Data(contentsOf: url) }
    if isScoped { url.stopAccessingSecurityScopedResource() }
    Task {
      do {
        let archive = try ClipArchive.decode(data.get())
        let added = await store.importArchive(archive)
        importMessage = String(localized: "Imported \(added) new clips.")
      } catch ClipArchive.ReadError.newerVersion {
        importMessage = String(localized: "This file was made by a newer Pastronaut.")
      } catch ClipArchive.ReadError.notAnArchive {
        importMessage = String(localized: "This isn't a Pastronaut export.")
      } catch {
        importMessage = error.localizedDescription
      }
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

/// The export as a file for the share sheet (Save to Files, AirDrop, Mail…).
struct ArchiveFile: Transferable {
  let archive: ClipArchive

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .json) { file in
      try file.archive.encoded()
    }
    .suggestedFileName(ClipArchive.suggestedFileName())
  }
}
