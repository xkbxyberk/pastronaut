import CloudKit
import Observation
import UniformTypeIdentifiers
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
  /// Media clips whose files are still on their way.
  private(set) var pendingFiles: Set<String> = []
  /// Settings every device shares (privacy filters, Images & Files); see `updateSharedSettings`.
  private(set) var sharedSettings = SharedSyncSettings()
  private(set) var hasFinishedFirstSync = false
  private var runningRefreshes = 0
  private var accountState: CKAccountStatus?
  private var accountError: String?
  enum Notice: Equatable {
    case savedFromClipboard
    case clipboardEmpty
    case tooLarge
    case noTextFound
    /// An image or a file was tapped before its files arrived.
    case stillDownloading
    /// Saved, but kept on this iPhone: larger than the limit, iCloud space full, or Images & Files off.
    case keptOnThisIPhone
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
      containerIdentifier: PastronautIDs.iCloudContainer, storageDirectory: directory, keepsLocalHistory: true,
      environment: Self.iCloudEnvironment
    )
    showSavedSnapshot()
  }

  /// "development" for builds installed from Xcode, "production" for TestFlight and the App Store: only
  /// development builds carry a provisioning profile, and its push environment follows the iCloud one. A Debug
  /// build opens the same App Group as the real app.
  static var iCloudEnvironment: String {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let profile = try? String(contentsOf: url, encoding: .isoLatin1),
          let key = profile.range(of: "<key>aps-environment</key>"),
          let value = profile[key.upperBound...].range(of: "<string>"),
          let end = profile[value.upperBound...].range(of: "</string>") else { return "production" }
    return String(profile[value.upperBound..<end.lowerBound])
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
      clips = (DemoClips.clips + (await DemoMedia.make())).inHistoryOrder
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
    // This iPhone's copy until the shared settings are read (`reconcileSharedSettings`).
    await sync.setPrivacy(PrivacyOptions.onPhone(in: sharedDefaults))
    await sync.start()
    await ingestInbox()
    await reload()
    PreviewStore.shared.prune(keeping: Set(clips.map(\.id)))
    // After the inbox: what the keyboard and Share saved is in the mirror now.
    await sync.pruneMedia()
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
    await reconcileSharedSettings()
    await reload()
    applyHistoryAge()
    hasFinishedFirstSync = true
    await updateAccountStatus()
  }

  func reload() async {
    #if DEBUG
    if DemoClips.isOn { return }
    #endif
    let latest = await sync.visibleClips.inHistoryOrder
    let latestCollections = await sync.collections
    let changed = latest != clips
    if changed {
      withAnimation(.snappy) { clips = latest }
    }
    if latestCollections != collections {
      collections = latestCollections
    }
    status = await sync.status
    let latestPending = await sync.pendingFileIDs
    if latestPending != pendingFiles { pendingFiles = latestPending }
    let latestSettings = await sync.sharedSettings
    if latestSettings != sharedSettings {
      // Another device changed them: the filters and the extensions' copy follow.
      sharedSettings = latestSettings
      PrivacyOptions.writeOnPhone(latestSettings.privacy, in: sharedDefaults)
      await sync.setPrivacy(latestSettings.privacy)
    }
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
    if clip.isMedia {
      guard MediaPasteboard.copy(clip) else {
        notice = .stillDownloading
        Task { await sync.fetchPendingFiles() }
        return
      }
    } else {
      UIPasteboard.general.string = clip.text
    }
    // Our own copy is already in the history; don't save it again on the next launch.
    sharedDefaults?.set(UIPasteboard.general.changeCount, forKey: AutoCapture.lastChangeCountKey)
    noteOwnCopy()
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

  /// Copies text that isn't a clip yet (the text read from an image) and keeps it as one.
  func copyText(_ text: String) {
    UIPasteboard.general.string = text
    sharedDefaults?.set(UIPasteboard.general.changeCount, forKey: AutoCapture.lastChangeCountKey)
    noteOwnCopy()
    save(text)
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
    /// Pastronaut put it there: reading it never asks, so it tests nothing.
    case ownCopy
  }

  /// What the setup's check found, and whether iPhone asked first. Reading the clipboard waits while iOS shows its
  /// paste prompt, so a read that takes a while means iPhone asked: Paste from Other Apps isn't Allow yet. Before
  /// the first prompt that setting isn't even in Settings, so the setup tries first and allows after.
  struct ClipboardCheck: Equatable {
    var trial: ClipboardTrial
    var asked = false
  }

  /// Longer than any read without a prompt, shorter than anyone answers one.
  static let promptDelay: TimeInterval = 0.35

  /// The pasteboard change count of the last copy this app made itself (the setup's check skips it).
  private static let ownCopyChangeCountKey = "ownCopyChangeCount"

  private func noteOwnCopy() {
    UserDefaults.standard.set(UIPasteboard.general.changeCount, forKey: Self.ownCopyChangeCountKey)
  }

  func trySavingClipboard() async -> ClipboardCheck {
    #if DEBUG
    if DemoClips.isOn { return ClipboardCheck(trial: .saved) }
    #endif
    let pasteboard = UIPasteboard.general
    guard pasteboard.hasStrings else { return ClipboardCheck(trial: .empty) }
    if pasteboard.changeCount == UserDefaults.standard.object(forKey: Self.ownCopyChangeCountKey) as? Int {
      return ClipboardCheck(trial: .ownCopy)
    }
    sharedDefaults?.set(pasteboard.changeCount, forKey: AutoCapture.lastChangeCountKey)
    let start = Date.now
    let text = pasteboard.string
    let asked = Date.now.timeIntervalSince(start) > Self.promptDelay
    guard let text else { return ClipboardCheck(trial: .denied, asked: asked) }
    guard AutoCapture.allows(text) else { return ClipboardCheck(trial: .sensitive, asked: asked) }
    switch await saveNow(text) {
    case .saved: return ClipboardCheck(trial: .saved, asked: asked)
    case .empty: return ClipboardCheck(trial: .empty, asked: asked)
    case .tooLarge: return ClipboardCheck(trial: .tooLarge, asked: asked)
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
    guard changeCount != sharedDefaults?.object(forKey: AutoCapture.lastChangeCountKey) as? Int else { return }
    if pasteboard.contains(pasteboardTypes: [AutoCapture.finderCopyType]) {
      sharedDefaults?.set(changeCount, forKey: AutoCapture.lastChangeCountKey)
      return
    }
    if !pasteboard.hasStrings, MediaLoader.hasMedia(pasteboard) {
      sharedDefaults?.set(changeCount, forKey: AutoCapture.lastChangeCountKey)
      let parts = MediaLoader.parts(from: pasteboard, quality: mediaQuality, maxBytes: Self.maxLocalMediaBytes)
      // Saved like text: never one that shows a code or a card number.
      if await saveMedia(parts, sensitiveCheck: true) == .saved {
        notice = .savedFromClipboard
      }
      return
    }
    guard pasteboard.hasStrings else { return }
    // Marked before reading, so a declined permission prompt isn't shown again for the same copy.
    sharedDefaults?.set(changeCount, forKey: AutoCapture.lastChangeCountKey)
    guard let text = pasteboard.string, AutoCapture.allows(text) else { return }
    // Already in the history, usually a Mac copy that Universal Clipboard put here: leave it as it is, so it
    // isn't relabelled as an iPhone copy or moved to the top.
    let id = Clip.id(for: text)
    guard !clips.contains(where: { $0.id == id }) else { return }
    // The name of a file the Mac copied, which Universal Clipboard brings as text: the Mac's clip is the copy.
    guard clips.fileNamed(by: text, near: .now) == nil else { return }
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

  // MARK: - Keep History (1.3)

  var historyAge: HistoryAge {
    HistoryAge(rawValue: UserDefaults.standard.string(forKey: AppPreferences.historyAgeKey) ?? "") ?? .forever
  }

  private func expired(for age: HistoryAge, now: Date = .now) -> [Clip] {
    clips.filter { age.isExpired(lastCopiedAt: $0.lastCopiedAt, pinned: $0.isKept, now: now) }
  }

  func expiredCount(for age: HistoryAge) -> Int {
    expired(for: age).count
  }

  /// Removes clips older than "Keep History": this iPhone's own copies everywhere, other devices' copies from this
  /// iPhone only (they stay in iCloud and on the Mac). Pinned clips and clips in collections stay.
  func applyHistoryAge() {
    let old = expired(for: historyAge)
    guard !old.isEmpty else { return }
    let own = old.filter { $0.sourceDevice != .mac }.map(\.id)
    let others = old.filter { $0.sourceDevice == .mac }.map(\.id)
    clips.removeAll { clip in old.contains { $0.id == clip.id } }
    Task {
      await sync.delete(ids: own)
      await sync.dismiss(ids: others)
      await reload()
      await upload()
    }
  }

  // MARK: - Images, PDFs and files (1.3)

  /// Larger things are not kept at all: the history is no place for a film.
  static let maxLocalMediaBytes = 200 * MediaSettings.megabyte

  /// The quality this iPhone sends images in (Settings › Images & Files).
  var mediaQuality: MediaQuality {
    MediaQuality(rawValue: sharedDefaults?.string(forKey: AppPreferences.mediaQualityKey) ?? "") ?? .optimized
  }

  /// Saves an image, a PDF or files as one clip. It goes to iCloud when the shared limits allow, otherwise it stays on
  /// this iPhone (and says so). `sensitiveCheck` keeps automatic saves from storing an image with a code in it.
  @discardableResult
  func saveMedia(
    _ parts: [MediaIntake.Part],
    to collectionID: String? = nil,
    sensitiveCheck: Bool = false
  ) async -> SaveResult {
    guard !parts.isEmpty else { return .empty }
    guard parts.reduce(0, { $0 + $1.data.count }) <= Self.maxLocalMediaBytes else { return .tooLarge }
    await start()
    guard let prepared = await MediaIntake.prepare(parts, device: .iphone) else { return .empty }
    if sensitiveCheck, let text = prepared.clip.media?.recognizedText, !AutoCapture.allows(text) { return .empty }
    // An automatic save of a picture the Mac copied: Universal Clipboard put it here, and sync already brought the
    // Mac's own clip of it (same picture, other bytes). Keeping both showed it twice.
    if sensitiveCheck, let media = prepared.clip.media, let width = media.pixelWidth, let height = media.pixelHeight,
       let copied = parts.first?.original,
       clips.contains(where: { clip in
         guard clip.sourceDevice == .mac, clip.media?.isSamePicture(
           width: width, height: height, copiedAt: prepared.clip.firstCopiedAt, as: clip.firstCopiedAt
         ) == true, let url = sync.media.fileURLs(for: clip).first, let data = try? Data(contentsOf: url) else { return false }
         return MediaProcessing.isSamePicture(copied, data)
       }) {
      return .empty
    }
    do {
      try MediaIntake.store(prepared, in: sync.media)
    } catch {
      return .empty
    }
    let goesToICloud = await sync.allowsMedia(prepared.clip)
    await sync.recordCopy(prepared.clip)
    if let collectionID {
      await sync.setMembership(true, of: [prepared.clip.id], in: collectionID)
    }
    await reload()
    await upload()
    if !goesToICloud { notice = .keptOnThisIPhone }
    return .saved
  }

  /// What the system Paste button hands over: text, an image, a PDF or files.
  func save(providers items: [NSItemProvider]) {
    let providers = MediaLoader.Providers(items: items)
    Task {
      let result: SaveResult
      if let text = await MediaLoader.text(from: providers) {
        result = await saveNow(text)
      } else {
        let parts = await MediaLoader.parts(from: providers, quality: mediaQuality, maxBytes: Self.maxLocalMediaBytes)
        result = await saveMedia(parts)
      }
      // Always say what happened: a clip already in the history only moves up, which is easy to miss.
      switch result {
      case .saved: notice = .savedFromClipboard
      case .empty: notice = .clipboardEmpty
      case .tooLarge: notice = .tooLarge
      }
    }
  }

  /// A copy Markup made of an image or a PDF: a new clip, in the same collections.
  func saveEdited(_ url: URL, from original: Clip) async {
    guard let data = try? Data(contentsOf: url) else { return }
    let part = MediaIntake.file(named: url.lastPathComponent, data: data)
    let parts = MediaProcessing.isImage(part.type)
      ? [MediaIntake.image(data, quality: mediaQuality, maxBytes: Self.maxLocalMediaBytes)].compactMap { $0 }
      : [part]
    _ = await saveMedia(parts, to: original.collectionIDs.first)
  }

  /// Scanned pages as a PDF clip, next to the text read from them.
  func saveScannedPDF(_ pages: [CGImage]) async {
    guard let pdf = MediaLoader.pdf(from: pages) else { return }
    _ = await saveMedia([MediaIntake.pdf(pdf, name: MediaProcessing.defaultName(prefix: "Scan", type: UTType.pdf.identifier))])
  }

  /// Changes the settings every device shares; the other devices follow.
  func updateSharedSettings(_ change: @escaping @Sendable (inout SharedSyncSettings) -> Void) {
    Task {
      await start()
      await sync.updateSharedSettings(change)
      await updatePrivacy()
      await reload()
      await upload()
    }
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
  /// The privacy filters every device shares decide what leaves this iPhone; the keyboard and Share keep a copy.
  func updatePrivacy() async {
    let privacy = await sync.sharedSettings.privacy
    PrivacyOptions.writeOnPhone(privacy, in: sharedDefaults)
    await sync.setPrivacy(privacy)
  }

  private var reconciledSettings = false

  /// Once per launch, after the first sync: before 1.3 the code and card switches were this iPhone's own. If
  /// nobody changed the shared ones yet, these become everyone's.
  private func reconcileSharedSettings() async {
    guard !reconciledSettings else { return }
    reconciledSettings = true
    let shared = await sync.sharedSettings
    let local = PrivacyOptions.onPhone(in: sharedDefaults)
    if shared.modifiedAt == nil, local != shared.privacy {
      await sync.updateSharedSettings { $0.privacy = local }
    }
    await updatePrivacy()
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
    noteOwnCopy()
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
