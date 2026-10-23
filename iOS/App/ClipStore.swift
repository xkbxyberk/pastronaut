import CloudKit
import Observation
import PastronautCore
import SwiftUI
import UIKit
import WidgetKit

/// The iOS app's view of the synced history. `ClipSync` is the source of truth; every change is
/// mirrored into the App Group snapshot that the keyboard reads.
@MainActor
@Observable
final class ClipStore {
  static let shared = ClipStore()

  private(set) var clips: [Clip] = []
  /// In list order.
  private(set) var collections: [ClipCollection] = []
  /// Kept on this iPhone after iCloud data was deleted or the account changed; sent only on request.
  private(set) var localOnly = LocalOnlyIDs()
  private(set) var status: SyncStatus?
  private(set) var hasFinishedFirstSync = false
  private var runningRefreshes = 0
  private var accountState: CKAccountStatus?
  private var accountError: String?
  enum Notice: Equatable {
    case savedFromClipboard
    case clipboardEmpty
    case tooLarge
    case noTextFound
  }

  /// A short message for the history screen; set again for every event, so the same notice shows twice.
  var notice: Notice? {
    didSet { if notice != nil { noticeID += 1 } }
  }
  private(set) var noticeID = 0
  var searchText = ""

  private let sync: ClipSync
  private let files: SharedClipFiles?
  private let sharedDefaults = UserDefaults(suiteName: PastronautIDs.appGroup)
  /// The one start: sets up the sync engine. Everything that needs it waits for this, so the inbox is never
  /// read before the engine exists (its clips would be dropped). The first iCloud sync is not part of it, so a
  /// save doesn't wait for the network.
  private var startTask: Task<Void, Never>?

  private init() {
    files = SharedClipFiles()
    let directory = files?.directory ?? URL.applicationSupportDirectory.appending(path: "Pastronaut")
    // The mirror is the iPhone's history: what iCloud forgets stays here as local-only clips.
    sync = ClipSync(
      containerIdentifier: PastronautIDs.iCloudContainer, storageDirectory: directory, keepsLocalHistory: true
    )
    showSavedSnapshot()
  }

  private func showSavedSnapshot() {
    #if DEBUG
    if DemoClips.isOn || SharedSettings.defaults?.object(forKey: SharedSettings.demoUntilKey) != nil { return }
    #endif
    guard let files else { return }
    clips = files.currentClips().inHistoryOrder
    collections = files.currentCollections()
  }

  var isSyncing: Bool { runningRefreshes > 0 }

  var isWaitingForFirstSync: Bool {
    clips.isEmpty && !hasFinishedFirstSync
  }

  var accountStatus: String {
    if let accountError { return accountError }
    let preferences = AppPreferences.shared
    return switch accountState {
    case nil: "…"
    case .available: preferences.string("Signed in")
    case .noAccount: preferences.string("Not signed in to iCloud")
    case .restricted: preferences.string("Restricted")
    case .temporarilyUnavailable: preferences.string("Temporarily unavailable")
    case .couldNotDetermine: preferences.string("Unknown")
    @unknown default: preferences.string("Unknown")
    }
  }

  func start() async {
    if let startTask { return await startTask.value }
    let task = Task { await performStart() }
    startTask = task
    await task.value
    await refreshStarted()
  }

  private func performStart() async {
    #if DEBUG
    if DemoClips.isOn {
      SharedSettings.defaults?.set(Date.now.addingTimeInterval(15 * 60), forKey: SharedSettings.demoUntilKey)
      SharedSettings.defaults?.set(Bundle.main.preferredLocalizations.first ?? "en", forKey: SharedSettings.demoLanguageKey)
      clips = DemoClips.clips.inHistoryOrder
      collections = DemoClips.collections
      hasFinishedFirstSync = true
      try? files?.writeSnapshot(clips)
      try? files?.writeCollections(collections)
      return
    }
    SharedSettings.defaults?.removeObject(forKey: SharedSettings.demoUntilKey)
    #endif
    await sync.setChangeHandler { _ in
      await ClipStore.shared.reload()
    }
    await updatePrivacy()
    await sync.start()
    await ingestInbox()
    await reload()
    PreviewStore.shared.prune(keeping: Set(clips.map(\.id)))
  }

  /// Pulls the keyboard's captures and the latest iCloud changes. Called on launch, foreground and push.
  func refresh() async {
    await start()
    await refreshStarted()
  }

  private func refreshStarted() async {
    #if DEBUG
    if DemoClips.isOn { return }
    #endif
    runningRefreshes += 1
    defer { runningRefreshes -= 1 }
    await ingestInbox()
    try? await sync.syncNow()
    await reload()
    hasFinishedFirstSync = true
    await updateAccountStatus()
  }

  func reload() async {
    #if DEBUG
    if DemoClips.isOn { return }
    #endif
    // Images and files arrive from 1.3 on; shown once this app can (PLAN-1.3 step 3).
    let latest = await sync.clips.filter { !$0.isMedia }.inHistoryOrder
    let latestCollections = await sync.collections
    let changed = latest != clips
    if changed {
      withAnimation(.snappy) { clips = latest }
    }
    if latestCollections != collections {
      collections = latestCollections
    }
    status = await sync.status
    let latestLocalOnly = await sync.localOnly
    if latestLocalOnly != localOnly {
      localOnly = latestLocalOnly
    }
    try? files?.writeSnapshot(clips)
    try? files?.writeCollections(collections)
    try? files?.writeLocalOnly(localOnly)
    SpotlightIndex.update(with: clips)
    if changed {
      // Reloads requested by the app in front don't use up the widgets' daily refresh budget.
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  // MARK: - User actions

  func copy(_ clip: Clip) {
    UIPasteboard.general.string = clip.text
    // Our own copy is already in the history; don't save it again on the next launch.
    sharedDefaults?.set(UIPasteboard.general.changeCount, forKey: AutoCapture.lastChangeCountKey)
    // Copying moves the clip up but keeps where it came from: a Mac clip stays under the Mac filter.
    var used = clip
    used.lastCopiedAt = .now
    used.modifiedAt = .now
    upsert(used)
  }

  func togglePin(_ clip: Clip) {
    var changed = clip
    changed.pinned.toggle()
    changed.modifiedAt = .now
    upsert(changed)
  }

  /// Replaces a clip's text. The ID follows the text, so this is a delete plus a new clip that keeps the
  /// pin and copy dates, the same as an edit on the Mac. Returns the new ID.
  @discardableResult
  func edit(_ clip: Clip, to text: String) -> String? {
    guard !text.isEmpty, text != clip.text, SyncPolicy.default.isEligible(text) else { return nil }
    var edited = Clip(
      text: text,
      sourceApp: clip.sourceApp,
      sourceAppName: clip.sourceAppName,
      sourceDevice: clip.sourceDevice,
      firstCopiedAt: clip.firstCopiedAt,
      lastCopiedAt: clip.lastCopiedAt,
      modifiedAt: .now,
      pinned: clip.pinned,
      collectionIDs: clip.collectionIDs
    )
    edited.takeTitle(from: clip)
    clips.removeAll { $0.id == clip.id }
    clips.append(edited)
    Task {
      await sync.delete(ids: [clip.id])
      await sync.upsert(edited)
      await reload()
      await upload()
    }
    return edited.id
  }

  /// Gives a clip a title, or clears it with nil or blank text. Only the title changes: the pin and the rest come
  /// from the sync mirror, so a stale copy of the clip can't undo changes from another device.
  func setTitle(_ title: String?, for clip: Clip) {
    var titled = clip
    titled.setTitle(title)
    guard titled.title != clip.title else { return }
    upsert(titled)
  }

  func delete(_ clip: Clip) {
    delete([clip])
  }

  /// The last deletion, for "Undo".
  private(set) var lastDeleted: [Clip] = []

  func delete(_ removed: [Clip]) {
    let ids = Set(removed.map(\.id))
    guard !ids.isEmpty else { return }
    lastDeleted = clips.filter { ids.contains($0.id) }
    clips.removeAll { ids.contains($0.id) }
    Task {
      await sync.delete(ids: Array(ids))
      await reload()
      await upload()
    }
  }

  /// Brings back what the last deletion removed, on every device.
  func undoDelete() {
    let restored = lastDeleted
    lastDeleted = []
    guard !restored.isEmpty else { return }
    Task {
      await sync.restore(restored)
      await reload()
      await upload()
    }
  }

  /// Pins every clip when any of them is unpinned, otherwise unpins them all.
  func togglePin(_ changed: [Clip]) {
    let pin = changed.contains { !$0.pinned }
    Task {
      for var clip in changed where clip.pinned != pin {
        clip.pinned = pin
        clip.modifiedAt = .now
        await sync.upsert(clip)
      }
      await reload()
      await upload()
    }
  }

  // MARK: - Collections

  func clips(in collectionID: String) -> [Clip] {
    clips.filter { $0.isIn(collectionID) }
  }

  /// Creates a collection at the end of the list and puts `members` in it.
  @discardableResult
  func createCollection(named name: String, with members: [Clip] = []) -> ClipCollection? {
    guard let name = ClipCollection.cleanName(name) else { return nil }
    let collection = ClipCollection(name: name, order: collections.nextOrder)
    collections.append(collection)
    let ids = members.map(\.id)
    Task {
      await sync.upsertCollection(collection)
      await sync.setMembership(true, of: ids, in: collection.id)
      await reload()
      await upload()
    }
    return collection
  }

  func rename(_ collection: ClipCollection, to name: String) {
    guard let name = ClipCollection.cleanName(name), name != collection.name else { return }
    var renamed = collection
    renamed.name = name
    renamed.modifiedAt = .now
    let change = renamed
    Task {
      await sync.upsertCollection(change)
      await reload()
      await upload()
    }
  }

  /// Removes the collection everywhere; its clips stay in the history.
  func deleteCollection(_ collection: ClipCollection) {
    collections.removeAll { $0.id == collection.id }
    Task {
      await sync.deleteCollection(id: collection.id)
      await reload()
      await upload()
    }
  }

  func setMembership(_ isMember: Bool, of members: [Clip], in collectionID: String) {
    let ids = members.map(\.id)
    Task {
      await sync.setMembership(isMember, of: ids, in: collectionID)
      await reload()
      await upload()
    }
  }

  /// Adds every clip when any of them is outside the collection, otherwise takes them all out.
  func toggleMembership(of members: [Clip], in collectionID: String) {
    setMembership(members.contains { !$0.isIn(collectionID) }, of: members, in: collectionID)
  }

  /// Text dropped on the history or on a collection (iPad drag and drop): saved when new, and added to the
  /// collection. Dragging an existing clip onto a collection doesn't count as copying it again.
  func addDropped(_ texts: [String], to collectionID: String?) {
    let eligible = texts.filter { SyncPolicy.default.isEligible($0) }
    guard !eligible.isEmpty else { return }
    Task {
      await start()
      for text in eligible {
        let id = Clip.id(for: text)
        if await sync.clip(withID: id) == nil {
          await sync.recordCopy(Clip(text: text, sourceDevice: .iphone))
        }
        if let collectionID {
          await sync.setMembership(true, of: [id], in: collectionID)
        }
      }
      await reload()
      await upload()
    }
  }

  // MARK: - Export and import

  func makeArchive() -> ClipArchive {
    ClipArchive(clips: clips, collections: collections)
  }

  /// Adds an export's clips and collections. Returns how many clips were new.
  func importArchive(_ archive: ClipArchive) async -> Int {
    await start()
    let plan = archive.importPlan(existingClips: clips, existingCollections: collections, device: .iphone)
    for collection in plan.collections {
      await sync.upsertCollection(collection)
    }
    await sync.upsert(contentsOf: plan.clips)
    await reload()
    await upload()
    return plan.newClipCount
  }

  // MARK: - Saving the clipboard on request

  /// Runs the "Save Clipboard" control or Siri request once the app is in front: unlike the automatic save,
  /// the person asked for it, so codes are saved too and an existing clip moves to the top.
  func savePendingClipboard() async {
    guard SharedSettings.defaults?.bool(forKey: SharedSettings.pendingClipboardSaveKey) == true,
          UIApplication.shared.applicationState == .active else { return }
    SharedSettings.defaults?.set(false, forKey: SharedSettings.pendingClipboardSaveKey)
    let pasteboard = UIPasteboard.general
    sharedDefaults?.set(pasteboard.changeCount, forKey: AutoCapture.lastChangeCountKey)
    guard pasteboard.hasStrings, let text = pasteboard.string else {
      notice = .clipboardEmpty
      return
    }
    switch await saveNow(text) {
    case .saved: notice = .savedFromClipboard
    case .empty: notice = .clipboardEmpty
    case .tooLarge: notice = .tooLarge
    }
  }

  // MARK: - Saving the clipboard on launch

  var isAutoSaveEnabled: Bool {
    sharedDefaults?.object(forKey: AutoCapture.settingKey) as? Bool ?? true
  }

  /// "Pause Saving": automatic saves stop until the chosen time; what the person asks for still saves.
  func pauseSaving(_ length: PauseLength) {
    SavingPause.pause(length, in: sharedDefaults)
    reloadPauseControl()
  }

  func resumeSaving() {
    SavingPause.resume(in: sharedDefaults)
    reloadPauseControl()
  }

  private func reloadPauseControl() {
    if #available(iOS 18.0, *) {
      ControlCenter.shared.reloadControls(ofKind: PauseSavingIntent.controlKind)
    }
  }

  var savingPausedUntil: Date? {
    SavingPause.pausedUntil(in: sharedDefaults)
  }

  private var isOnboardingFinished: Bool {
    #if DEBUG
    if ProcessInfo.processInfo.environment["PT_E2E"] != nil { return true }
    #endif
    return UserDefaults.standard.bool(forKey: AppPreferences.onboardingKey)
  }

  enum ClipboardTrial: Equatable {
    case saved
    case empty
    case denied
    case sensitive
    case tooLarge
  }

  func trySavingClipboard() async -> ClipboardTrial {
    #if DEBUG
    if DemoClips.isOn { return .saved }
    #endif
    let pasteboard = UIPasteboard.general
    guard pasteboard.hasStrings else { return .empty }
    sharedDefaults?.set(pasteboard.changeCount, forKey: AutoCapture.lastChangeCountKey)
    guard let text = pasteboard.string else { return .denied }
    guard AutoCapture.allows(text) else { return .sensitive }
    switch await saveNow(text) {
    case .saved: return .saved
    case .empty: return .empty
    case .tooLarge: return .tooLarge
    }
  }

  /// With "Save Clipboard on Opening" on, a new copy is saved when the app comes to the foreground. Reading
  /// the text asks for permission unless Paste from Other Apps is set to Allow; checking for text doesn't.
  func autoSaveClipboard() async {
    #if DEBUG
    if DemoClips.isOn { return }
    #endif
    guard AutoCapture.isActive(in: sharedDefaults), isOnboardingFinished else { return }
    let pasteboard = UIPasteboard.general
    let changeCount = pasteboard.changeCount
    guard pasteboard.hasStrings,
          changeCount != sharedDefaults?.object(forKey: AutoCapture.lastChangeCountKey) as? Int else { return }
    // Marked before reading, so a declined permission prompt isn't shown again for the same copy.
    sharedDefaults?.set(changeCount, forKey: AutoCapture.lastChangeCountKey)
    guard let text = pasteboard.string, AutoCapture.allows(text) else { return }
    // Already in the history, usually a Mac copy that Universal Clipboard put here: leave it as it is, so it
    // isn't relabelled as an iPhone copy or moved to the top.
    let id = Clip.id(for: text)
    guard !clips.contains(where: { $0.id == id }) else { return }
    if await saveNow(text) == .saved {
      notice = .savedFromClipboard
    }
  }

  /// Saves text from the system Paste button (no paste permission prompt) or the new clip editor.
  func save(_ text: String?) {
    guard let text else { return }
    Task {
      if await saveNow(text) == .tooLarge { notice = .tooLarge }
    }
  }

  enum SaveResult {
    case saved
    case empty
    case tooLarge
  }

  /// Saves and uploads a copy, keeping the pin if the text is already in the history. Used by the
  /// Paste button and the Shortcuts action, which waits for the upload before it finishes.
  func saveNow(_ text: String, to collectionID: String? = nil) async -> SaveResult {
    guard !text.isEmpty else { return .empty }
    guard SyncPolicy.default.isEligible(text) else { return .tooLarge }
    await start()
    await sync.recordCopy(Clip(text: text, sourceDevice: .iphone))
    if let collectionID {
      await sync.setMembership(true, of: [Clip.id(for: text)], in: collectionID)
    }
    await reload()
    await upload()
    return .saved
  }

  private func upsert(_ clip: Clip) {
    #if DEBUG
    if DemoClips.isOn { return }
    #endif
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

  /// Stores the keyboard's and Share's captures, then takes them out of the inbox: a crash in between
  /// stores them twice (harmless) instead of losing them.
  private func ingestInbox() async {
    guard let files else { return }
    let captured = files.readInbox()
    guard !captured.isEmpty else { return }
    await sync.recordCopies(captured)
    // A capture keeps the collections the history already has; ones chosen in the Share sheet are added here.
    for clip in captured {
      for collectionID in clip.collectionIDs {
        await sync.setMembership(true, of: [clip.id], in: collectionID)
      }
    }
    try? files.removeFromInbox(handled: captured)
  }

  /// Settings › Privacy changed: codes and cards copied from now on stay on this iPhone, or sync again.
  func updatePrivacy() async {
    await sync.setPrivacy(PrivacyOptions.onPhone(in: sharedDefaults))
  }

  // MARK: - Queue and combining

  /// Starts a queue for the keyboard: each tap on its queue key types the next of these, in this order.
  func startQueue(_ queued: [Clip]) {
    guard !queued.isEmpty else { return }
    try? files?.writeQueue(QueueRequest(clipIDs: queued.map(\.id)))
  }

  func endQueue() {
    try? files?.writeQueue(nil)
  }

  var hasQueue: Bool { files?.readQueue() != nil }

  /// Copies several clips as one text and saves that text as a clip of its own, so it can be pasted again
  /// later and reaches the Mac. Returns false when it is too large to save (it is still copied).
  @discardableResult
  func copyCombined(_ combined: [Clip], separator: ClipSeparator) -> Bool {
    let text = combined.combinedText(separator: separator)
    UIPasteboard.general.string = text
    sharedDefaults?.set(UIPasteboard.general.changeCount, forKey: AutoCapture.lastChangeCountKey)
    guard SyncPolicy.default.isEligible(text) else { return false }
    save(text)
    return true
  }

  // MARK: - Local-only clips

  /// "Upload to iCloud Again": sends what was kept on this iPhone only. Returns how many clips go up.
  @discardableResult
  func uploadLocalOnly() async -> Int {
    await start()
    let count = await sync.uploadLocalOnly()
    try? await sync.syncNow()
    await reload()
    await upload()
    return count
  }

  private func updateAccountStatus() async {
    do {
      accountState = try await CKContainer(identifier: PastronautIDs.iCloudContainer).accountStatus()
      accountError = nil
    } catch {
      accountError = error.localizedDescription
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
