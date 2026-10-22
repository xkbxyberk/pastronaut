import PastronautCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
  @Environment(ClipStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @AppStorage(AutoCapture.settingKey, store: UserDefaults(suiteName: PastronautIDs.appGroup))
  private var autoSave = true
  @AppStorage(SpotlightIndex.settingKey) private var spotlight = false
  @AppStorage(PreviewChoice.key) private var previewChoice = PreviewChoice.on.rawValue
  @AppStorage(AppPreferences.appearanceKey) private var appearance = AppAppearance.system
  @AppStorage(PrivacyCover.recordingKey) private var hidesWhileRecording = true
  @AppStorage(PrivacyCover.switcherKey) private var hidesInSwitcher = false
  @AppStorage(PrivacyOptions.phoneCodesKey, store: UserDefaults(suiteName: PastronautIDs.appGroup))
  private var keepsCodes = false
  @AppStorage(PrivacyOptions.phoneCardsKey, store: UserDefaults(suiteName: PastronautIDs.appGroup))
  private var keepsCards = false
  @State private var pausedUntil: Date?
  @State private var isUploadingLocalOnly = false
  @State private var isImporting = false
  @State private var importMessage: String?
  private let setup = KeyboardSetup.shared
  private let lock = AppLock.shared
  private let preferences = AppPreferences.shared

  var body: some View {
    NavigationStack {
      Form {
        setupSection
        syncSection
        languageSection
        appearanceSection
        clipboardSection
        privacySection
        dataSection
        aboutSection
      }
      .id(preferences.language)
      .navigationTitle(preferences.string("Settings"))
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier("doneButton")
        }
      }
      .onAppear {
        setup.update()
        pausedUntil = store.savingPausedUntil
      }
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

  private var setupSection: some View {
    Section {
      NavigationLink {
        OnboardingView(presentation: .settings)
      } label: {
        HStack(spacing: 14) {
          Image(systemName: setup.isComplete ? "checkmark.seal.fill" : "keyboard.badge.ellipsis")
            .font(.title2)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(setup.isComplete ? Color.green : Color.accentColor)
            .frame(width: 44, height: 44)
            .background(
              (setup.isComplete ? Color.green : Color.accentColor).opacity(0.14),
              in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 3) {
            Text("Setup Guide")
              .font(.headline)
            Text("Keyboard, Full Access and pasting without asking")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          if setup.isComplete {
            Text("Ready")
              .font(.subheadline)
              .foregroundStyle(.green)
          } else if setup.isWaitingForKeyboardCheck {
            Text("Almost done")
              .font(.subheadline)
              .foregroundStyle(.orange)
          } else {
            Text("Not finished")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 4)
      }
      .accessibilityIdentifier("setupKeyboard")
    }
  }

  private var syncSection: some View {
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
      if !store.localOnly.clips.isEmpty {
        LabeledContent("Only on This iPhone", value: "\(store.localOnly.clips.count)")
          .accessibilityIdentifier("localOnlyCount")
        Button {
          isUploadingLocalOnly = true
          Task {
            await store.uploadLocalOnly()
            isUploadingLocalOnly = false
          }
        } label: {
          if isUploadingLocalOnly {
            ProgressView()
          } else {
            Text("Upload to iCloud Again")
          }
        }
        .disabled(isUploadingLocalOnly)
        .accessibilityIdentifier("uploadLocalOnly")
      }
      Button("Sync Now") {
        Task { await store.refresh() }
      }
    } header: {
      Text("Sync")
    } footer: {
      if !store.localOnly.clips.isEmpty {
        Text("These clips stayed on this iPhone when iCloud no longer had them (its data was deleted, or the iPhone used another account), or because Privacy keeps them here. They are sent only when you choose Upload to iCloud Again; codes and cards Privacy keeps here stay.")
      }
      Text("Text clips sync through your private iCloud database. Clip text and collection names are encrypted on this device before upload (end-to-end with Advanced Data Protection), and iCloud can't tell which texts you saved.")
    }
  }

  private var languageSection: some View {
    Section {
      Picker(selection: Binding(get: { preferences.language }, set: { preferences.language = $0 })) {
        ForEach(AppLanguage.allCases) { language in
          Text(verbatim: language.nativeName).tag(language)
        }
      } label: {
        Label {
          Text("Language")
        } icon: {
          SettingsIcon(systemImage: "globe", color: .blue)
        }
      }
      .pickerStyle(.menu)
      .accessibilityIdentifier("languagePicker")
    } footer: {
      Text("Pastronaut starts in your iPhone's language when it is Turkish or English, and in English otherwise. The keyboard and widgets follow your iPhone's language.")
    }
  }

  private var appearanceSection: some View {
    Section {
      Picker(selection: $appearance) {
        ForEach(AppAppearance.allCases) { option in
          Text(option.title).tag(option)
        }
      } label: {
        Label {
          Text("Theme")
        } icon: {
          SettingsIcon(systemImage: "circle.lefthalf.filled", color: .indigo)
        }
      }
      .pickerStyle(.menu)
      .accessibilityIdentifier("themePicker")
      Toggle(isOn: Binding(
        get: { previewChoice == PreviewChoice.on.rawValue },
        set: { isOn in
          previewChoice = isOn ? PreviewChoice.on.rawValue : PreviewChoice.off.rawValue
          if !isOn { PreviewStore.shared.clear() }
        }
      )) {
        Label {
          Text("Link and Map Previews")
        } icon: {
          SettingsIcon(systemImage: "rectangle.and.text.magnifyingglass", color: .teal)
        }
      }
      .accessibilityIdentifier("previewsToggle")
    } header: {
      Text("Appearance")
    } footer: {
      Text("With previews on, the history shows cards: links with their page, addresses with a map, code in color. This iPhone opens the link and asks Apple Maps for the address; sign-in and reset links are never opened. With previews off, the history is a compact list.")
    }
  }

  private var clipboardSection: some View {
    Section {
      Toggle(isOn: $autoSave) {
        Label {
          Text("Save Clipboard on Opening")
        } icon: {
          SettingsIcon(systemImage: "doc.on.clipboard", color: .orange)
        }
      }
      .accessibilityIdentifier("autoSaveToggle")
      if autoSave {
        NavigationLink {
          OnboardingView(presentation: .settings, initialStep: .paste)
        } label: {
          Label {
            Text("Allow Pasting Without Asking…")
          } icon: {
            SettingsIcon(systemImage: "hand.raised.fill", color: .green)
          }
        }
        .accessibilityIdentifier("pasteGuide")
      }
      if let until = pausedUntil {
        LabeledContent {
          if until == .distantFuture {
            Text("Until you resume")
          } else {
            Text(until, format: .dateTime.hour().minute())
          }
        } label: {
          Label {
            Text("Saving Paused")
          } icon: {
            SettingsIcon(systemImage: "pause.fill", color: .gray)
          }
        }
        Button("Resume Saving") {
          store.resumeSaving()
          pausedUntil = store.savingPausedUntil
        }
        .accessibilityIdentifier("resumeSaving")
      } else {
        Menu {
          ForEach(PauseLength.allCases, id: \.self) { length in
            Button(length.title) {
              store.pauseSaving(length)
              pausedUntil = store.savingPausedUntil
            }
          }
        } label: {
          Label {
            Text("Pause Saving")
          } icon: {
            SettingsIcon(systemImage: "pause.fill", color: .gray)
          }
        }
        .accessibilityIdentifier("pauseSaving")
      }
    } header: {
      Text("Clipboard")
    } footer: {
      Text("While saving is paused, Pastronaut and its keyboard don't save the clipboard by themselves; the Paste button, Share and Shortcuts still do. When you open Pastronaut or its keyboard, a new copy is saved by itself. One-time codes, card numbers and IBANs are skipped. iPhone can't read the clipboard in the background, so if you copy several things in a row only the last one is saved; use the Share menu or the Paste button for the others. To stop iOS from asking each time, set Paste from Other Apps to Allow.")
    }
  }

  private var privacySection: some View {
    Section {
      Toggle(isOn: Binding(get: { lock.isEnabled }, set: { value in Task { await lock.setEnabled(value) } })) {
        Label {
          Text("Lock with \(lock.methodName)")
        } icon: {
          SettingsIcon(systemImage: "lock.fill", color: .gray)
        }
      }
      .accessibilityIdentifier("appLockToggle")
      Toggle(isOn: $spotlight) {
        Label {
          Text("Show Pinned Clips in Search")
        } icon: {
          SettingsIcon(systemImage: "magnifyingglass", color: .purple)
        }
      }
      .disabled(lock.isEnabled)
      .onChange(of: spotlight) { SpotlightIndex.update(with: store.clips) }
      .accessibilityIdentifier("spotlightToggle")
      Toggle(isOn: $hidesWhileRecording) {
        Label {
          Text("Hide During Screen Recording")
        } icon: {
          SettingsIcon(systemImage: "record.circle", color: .red)
        }
      }
      .onChange(of: hidesWhileRecording) { PrivacyCover.shared.update() }
      .accessibilityIdentifier("hideWhileRecording")
      Toggle(isOn: $hidesInSwitcher) {
        Label {
          Text("Hide in App Switcher")
        } icon: {
          SettingsIcon(systemImage: "rectangle.stack", color: .gray)
        }
      }
      .disabled(lock.isEnabled)
      .accessibilityIdentifier("hideInSwitcher")
      Toggle(isOn: $keepsCodes) {
        Label {
          Text("Keep One-Time Codes on This iPhone")
        } icon: {
          SettingsIcon(systemImage: "number", color: .orange)
        }
      }
      .onChange(of: keepsCodes) { Task { await store.updatePrivacy() } }
      .accessibilityIdentifier("keepCodes")
      Toggle(isOn: $keepsCards) {
        Label {
          Text("Keep Card Numbers and IBANs on This iPhone")
        } icon: {
          SettingsIcon(systemImage: "creditcard", color: .green)
        }
      }
      .onChange(of: keepsCards) { Task { await store.updatePrivacy() } }
      .accessibilityIdentifier("keepCards")
    } header: {
      Text("Privacy")
    } footer: {
      Text("While the screen is recorded or shown on another display, your clips are covered. Kept codes and cards are saved here but never sent to iCloud, from now on. Pastronaut asks for \(lock.methodName) when you open it, and widgets hide your clips. The keyboard stays available, because iPhone keyboards can't ask for \(lock.methodName). Pinned clips can show up when you search your iPhone; choosing one copies it. Search stays off while the lock is on.")
    }
  }

  private var dataSection: some View {
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
  }

  private var aboutSection: some View {
    Section("About") {
      LabeledContent("Version", value: Self.version)
      Link("Privacy Policy", destination: URL(string: "https://xkbxyberk.github.io/pastronaut/privacy.html")!)
        .accessibilityIdentifier("privacyPolicy")
      Link("Pastronaut on GitHub", destination: URL(string: "https://github.com/xkbxyberk/pastronaut")!)
      NavigationLink("Licenses") {
        LicensesView()
      }
      Text("Based on Maccy by Alexey Rodionov (MIT). Not affiliated with Maccy.")
        .font(.footnote)
        .foregroundStyle(.secondary)
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
        importMessage = preferences.string("Imported \(added) new clips.")
      } catch ClipArchive.ReadError.newerVersion {
        importMessage = preferences.string("This file was made by a newer Pastronaut.")
      } catch ClipArchive.ReadError.notAnArchive {
        importMessage = preferences.string("This isn't a Pastronaut export.")
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
    .navigationTitle(AppPreferences.shared.string("Licenses"))
  }
}

/// The export as a file for the share sheet (Save to Files, AirDrop, Mail…).
struct ArchiveFile: Transferable {
  let archive: ClipArchive
  var fileName = ClipArchive.suggestedFileName()

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .json) { file in
      try file.archive.encoded()
    }
    .suggestedFileName { $0.fileName }
  }
}

/// "Export Collection": one collection's clips as an export file, for Files, AirDrop or Mail. Imports with
/// Settings › Import on another iPhone or Mac.
struct ExportCollectionLink: View {
  @Environment(ClipStore.self) private var store
  let collection: ClipCollection

  var body: some View {
    let fileName = ClipArchive.suggestedFileName(for: collection)
    ShareLink(
      item: ArchiveFile(archive: ClipArchive(collection: collection, from: store.clips), fileName: fileName),
      preview: SharePreview(Text(verbatim: fileName), image: Image(systemName: "doc.text"))
    ) {
      Label("Export Collection…", systemImage: "square.and.arrow.up")
    }
  }
}

extension PauseLength {
  var title: LocalizedStringKey {
    switch self {
    case .fifteenMinutes: "For 15 Minutes"
    case .oneHour: "For 1 Hour"
    case .untilTomorrow: "Until Tomorrow"
    case .indefinitely: "Until I Resume"
    }
  }
}
