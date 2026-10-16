import CloudKit
import PastronautCore
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
  private let model = KeyboardModel()

  override func viewDidLoad() {
    super.viewDidLoad()
    model.insert = { [weak self] in self?.textDocumentProxy.insertText($0) }
    model.deleteBackward = { [weak self] in self?.textDocumentProxy.deleteBackward() }
    model.nextKeyboard = { [weak self] in self?.advanceToNextInputMode() }

    let host = UIHostingController(rootView: KeyboardView(model: model))
    host.view.translatesAutoresizingMaskIntoConstraints = false
    host.view.backgroundColor = .clear
    addChild(host)
    view.addSubview(host.view)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      host.view.topAnchor.constraint(equalTo: view.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      host.view.heightAnchor.constraint(equalToConstant: 290)
    ])
    host.didMove(toParent: self)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    model.appeared(hasFullAccess: hasFullAccess, showsNextKeyboard: needsInputModeSwitchKey)
  }
}

@MainActor
@Observable
final class KeyboardModel {
  private(set) var clips: [Clip] = []
  private(set) var hasFullAccess = false
  private(set) var showsNextKeyboard = true
  /// The pasteboard changed since the last capture. Detected from metadata only, so iOS shows no prompt.
  private(set) var hasNewClip = false
  /// Last iCloud fetch or upload outcome; shown in Debug builds for the end-to-end test.
  private(set) var cloudStatus = "cloud: idle"

  var insert: (String) -> Void = { _ in }
  var deleteBackward: () -> Void = {}
  var nextKeyboard: () -> Void = {}

  private let files: SharedClipFiles?
  /// Network needs Full Access; only used when the keyboard has it.
  private let cloud: KeyboardCloud?
  /// Writable only with Full Access, like the rest of the App Group.
  private let defaults = UserDefaults(suiteName: PastronautIDs.appGroup)
  private let lastCapturedChangeCountKey = "keyboardLastCapturedChangeCount"
  @ObservationIgnored private var lastCloudRefresh = Date.distantPast

  init() {
    let files = SharedClipFiles()
    self.files = files
    cloud = files.map { KeyboardCloud(containerIdentifier: PastronautIDs.iCloudContainer, files: $0) }
  }

  func appeared(hasFullAccess: Bool, showsNextKeyboard: Bool) {
    self.hasFullAccess = hasFullAccess
    self.showsNextKeyboard = showsNextKeyboard
    reload()

    let pasteboard = UIPasteboard.general
    let lastCaptured = defaults?.object(forKey: lastCapturedChangeCountKey) as? Int
    hasNewClip = hasFullAccess && pasteboard.hasStrings && pasteboard.changeCount != lastCaptured
    refreshFromCloud()
  }

  /// The app may not have run since the last change (iOS rations background pushes), so with Full
  /// Access the keyboard fetches the latest state itself.
  private func refreshFromCloud() {
    guard hasFullAccess, let cloud, Date.now.timeIntervalSince(lastCloudRefresh) > 5 else { return }
    lastCloudRefresh = .now
    cloudStatus = "cloud: fetching"
    Task {
      do {
        let cache = try await cloud.refresh()
        cloudStatus = "cloud: fetched \(cache.clips.count)"
      } catch {
        cloudStatus = "cloud: fetch failed \(Self.describe(error))"
      }
      reload()
    }
  }

  private static func describe(_ error: Error) -> String {
    if let error = error as? CKError { return "CKError \(error.code.rawValue) \(error.localizedDescription)" }
    return String(describing: error)
  }

  /// Receives text from the system Paste button and saves it to iCloud, so the Mac gets it without the
  /// app being opened. The inbox is written first and kept if the upload fails; the app sends it later.
  func capture(_ strings: [String]) {
    guard let files, let text = strings.first, !text.isEmpty else { return }
    let clip = Clip(text: text, sourceDevice: .iphone)
    try? files.appendToInbox(clip)
    defaults?.set(UIPasteboard.general.changeCount, forKey: lastCapturedChangeCountKey)
    hasNewClip = false
    reload()
    guard hasFullAccess, let cloud else { return }
    Task {
      do {
        try await cloud.save(clip)
        cloudStatus = "cloud: saved"
        try? files.removeFromInbox(id: clip.id)
        // Makes the cache newer than the app's snapshot, so the saved clip stays listed.
        _ = try? await cloud.refresh()
        reload()
      } catch {
        // Offline or not eligible: the inbox keeps it for the app.
        cloudStatus = "cloud: save failed \(Self.describe(error))"
      }
    }
  }

  #if DEBUG
  /// Why the list is empty, read by the end-to-end test.
  var diagnostics: String {
    guard let files else { return "diag: no app group container" }
    let url = files.directory.appending(path: "clips.json")
    guard let data = FileManager.default.contents(atPath: url.path) else {
      let exists = FileManager.default.fileExists(atPath: url.path)
      return "diag: cannot read snapshot (exists: \(exists), dir: \(files.directory.path))"
    }
    do {
      return "diag: \(try JSONDecoder().decode([Clip].self, from: data).count) clips in \(data.count) bytes"
    } catch {
      return "diag: decode failed \(error)"
    }
  }
  #endif

  private func reload() {
    guard let files else {
      clips = []
      return
    }
    // The app's snapshot, or the keyboard's own fetch when that is newer, plus captures not yet synced.
    var base = files.readSnapshot()
    if hasFullAccess, let cache = files.readKeyboardCache(), let fetchedAt = cache.fetchedAt,
       fetchedAt > files.snapshotDate ?? .distantPast {
      base = cache.clips
    }
    var byID: [String: Clip] = [:]
    for clip in base + files.readInbox() {
      byID[clip.id] = byID[clip.id].map { $0.merged(with: clip) } ?? clip
    }
    clips = Array(byID.values.inHistoryOrder.prefix(100))
  }
}

struct KeyboardView: View {
  let model: KeyboardModel

  var body: some View {
    VStack(spacing: 6) {
      header
      list
      keys
      #if DEBUG
      Text(verbatim: model.cloudStatus).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
        .accessibilityIdentifier("cloudStatus")
      #endif
    }
    .padding(6)
  }

  @ViewBuilder
  private var header: some View {
    if model.hasFullAccess {
      if model.hasNewClip {
        HStack {
          Text("New text on the clipboard").font(.caption)
          Spacer()
          PasteButton(payloadType: String.self) { strings in
            Task { @MainActor in model.capture(strings) }
          }
          .labelStyle(.titleAndIcon)
          .font(.caption)
        }
      }
    } else {
      Text("Turn on Allow Full Access in Settings to save new copies from this keyboard.")
        .accessibilityIdentifier("fullAccessHint")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private var list: some View {
    if model.clips.isEmpty {
      VStack {
        Text("No clips yet. Open Pastronaut once to sync your history.")
          .accessibilityIdentifier("emptyState")
        #if DEBUG
        Text(verbatim: model.diagnostics).font(.caption2).accessibilityIdentifier("diagnostics")
        #endif
      }
      .font(.footnote)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 4) {
          ForEach(model.clips, id: \.id) { clip in
            Button {
              model.insert(clip.text)
            } label: {
              HStack(alignment: .firstTextBaseline, spacing: 6) {
                if clip.pinned {
                  Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange)
                    .accessibilityIdentifier("pinIcon")
                }
                Text(clip.text.replacingOccurrences(of: "\n", with: " ⏎ "))
                  .lineLimit(2)
                  .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: clip.sourceDevice == .mac ? "laptopcomputer" : "iphone")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              .padding(8)
              .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  // Basic input row: App Review 4.4.1 expects real input and a way to switch keyboards.
  private var keys: some View {
    HStack(spacing: 6) {
      if model.showsNextKeyboard {
        key(systemImage: "globe") { model.nextKeyboard() }
      }
      key(title: "space") { model.insert(" ") }
        .accessibilityIdentifier("spaceKey")
        .frame(maxWidth: .infinity)
      key(systemImage: "delete.left") { model.deleteBackward() }
      key(systemImage: "return") { model.insert("\n") }
    }
  }

  private func key(title: LocalizedStringKey? = nil, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Group {
        if let systemImage {
          Image(systemName: systemImage)
        } else {
          Text(title ?? "")
        }
      }
      .frame(maxWidth: .infinity, minHeight: 42)
      .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
  }
}
