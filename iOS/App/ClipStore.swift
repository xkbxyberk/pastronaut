import CloudKit
import Observation
import PastronautCore
import UIKit

/// The iOS app's view of the synced history. `ClipSync` is the source of truth; every change is
/// mirrored into the App Group snapshot that the keyboard reads.
@MainActor
@Observable
final class ClipStore {
  static let shared = ClipStore()

  private(set) var clips: [Clip] = []
  private(set) var status: SyncStatus?
  private(set) var accountStatus: String = "…"
  var searchText = ""

  private let sync: ClipSync
  private let files: SharedClipFiles?
  private var isStarted = false

  var filteredClips: [Clip] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return query.isEmpty ? clips : clips.filter { $0.text.localizedCaseInsensitiveContains(query) }
  }

  private init() {
    files = SharedClipFiles()
    let directory = files?.directory ?? URL.applicationSupportDirectory.appending(path: "Pastronaut")
    sync = ClipSync(containerIdentifier: PastronautIDs.iCloudContainer, storageDirectory: directory)
  }

  func start() async {
    guard !isStarted else { return }
    isStarted = true
    await sync.setChangeHandler { _ in
      await ClipStore.shared.reload()
    }
    await sync.start()
    await refresh()
  }

  /// Pulls the keyboard's captures and the latest iCloud changes. Called on launch, foreground and push.
  func refresh() async {
    await start()
    await ingestInbox()
    try? await sync.syncNow()
    await updateAccountStatus()
    await reload()
  }

  func reload() async {
    clips = await sync.clips.inHistoryOrder
    status = await sync.status
    try? files?.writeSnapshot(clips)
  }

  // MARK: - User actions

  func copy(_ clip: Clip) {
    UIPasteboard.general.string = clip.text
    var used = clip
    used.lastCopiedAt = .now
    used.modifiedAt = .now
    used.sourceDevice = .iphone
    upsert(used)
  }

  func togglePin(_ clip: Clip) {
    var changed = clip
    changed.pinned.toggle()
    changed.modifiedAt = .now
    upsert(changed)
  }

  func delete(_ clip: Clip) {
    clips.removeAll { $0.id == clip.id }
    Task {
      await sync.delete(ids: [clip.id])
      await reload()
      await upload()
    }
  }

  /// Saves text from the system Paste button (no paste permission prompt).
  func save(_ text: String?) {
    guard let text, !text.isEmpty else { return }
    upsert(Clip(text: text, sourceDevice: .iphone))
  }

  private func upsert(_ clip: Clip) {
    Task {
      await sync.upsert(clip)
      await reload()
      await upload()
    }
  }

  /// Sends local changes right away and asks iOS for time to finish if the app is leaving the foreground.
  /// Without this a pin or delete made just before switching apps waited until Pastronaut was opened again.
  func upload() async {
    let application = UIApplication.shared
    let task = BackgroundTask()
    task.id = application.beginBackgroundTask(withName: "Upload clip changes") {
      task.end(application)
    }
    try? await sync.sendNow()
    task.end(application)
  }

  private func ingestInbox() async {
    guard let files, let captured = try? files.drainInbox() else { return }
    for clip in captured {
      await sync.upsert(clip)
    }
  }

  private func updateAccountStatus() async {
    do {
      accountStatus = switch try await CKContainer(identifier: PastronautIDs.iCloudContainer).accountStatus() {
      case .available: "Signed in"
      case .noAccount: "Not signed in to iCloud"
      case .restricted: "Restricted"
      case .temporarilyUnavailable: "Temporarily unavailable"
      case .couldNotDetermine: "Unknown"
      @unknown default: "Unknown"
      }
    } catch {
      accountStatus = error.localizedDescription
    }
  }
}

@MainActor
private final class BackgroundTask {
  var id = UIBackgroundTaskIdentifier.invalid

  func end(_ application: UIApplication) {
    guard id != .invalid else { return }
    application.endBackgroundTask(id)
    id = .invalid
  }
}
