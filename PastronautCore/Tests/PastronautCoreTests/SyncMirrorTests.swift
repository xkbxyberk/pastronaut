import Foundation
import Testing
@testable import PastronautCore

/// The mirror's rules for iCloud being wiped, account changes, local-only clips and deletions made elsewhere.
@Suite struct SyncMirrorTests {
  typealias State = ClipSync.PersistedState
  typealias Entry = ClipSync.MirrorEntry

  let synced = Data([1])
  let early = Date(timeIntervalSince1970: 1_000)
  let late = Date(timeIntervalSince1970: 2_000)

  /// Two clips that reached iCloud, one that didn't, and a synced collection.
  func populatedState() -> State {
    var state = State()
    state.key = SyncKey.generate()
    for text in ["sent a", "sent b"] {
      let clip = Clip(text: text, sourceDevice: .iphone, firstCopiedAt: early)
      state.entries[clip.id] = Entry(clip: clip, systemFields: synced)
    }
    let unsent = Clip(text: "unsent", sourceDevice: .iphone, firstCopiedAt: early)
    state.entries[unsent.id] = Entry(clip: unsent, systemFields: nil)
    let collection = ClipCollection(id: "col-1", name: "Work", order: 1, createdAt: early)
    state.collections[collection.id] = ClipSync.CollectionEntry(collection: collection, systemFields: synced)
    return state
  }

  // MARK: - iCloud data deleted

  @Test func iPhoneKeepsItsHistoryWhenICloudIsWiped() {
    var state = populatedState()
    let unsentID = Clip.id(for: "unsent")
    let forgotten = state.forgetCloud(keeping: [unsentID], keepsLocalHistory: true)

    #expect(forgotten.isEmpty)
    #expect(state.entries.count == 3)
    #expect(state.collections.count == 1)
    #expect(state.entries.values.allSatisfy { $0.systemFields == nil })
    // What was changed here and never arrived is sent again; the rest waits for "Upload to iCloud Again".
    #expect(state.localOnly.clips == [Clip.id(for: "sent a"), Clip.id(for: "sent b")])
    #expect(state.localOnly.collections == ["col-1"])
    #expect(state.unsentClipIDs == [unsentID])
    #expect(state.unsentCollectionIDs.isEmpty)
  }

  @Test func macForgetsTheSyncCopyWhenICloudIsWiped() {
    var state = populatedState()
    let unsentID = Clip.id(for: "unsent")
    let forgotten = state.forgetCloud(keeping: [unsentID], keepsLocalHistory: false)

    #expect(forgotten == [.collectionDeleted(id: "col-1")])
    #expect(Array(state.entries.keys) == [unsentID])
    #expect(state.collections.isEmpty)
    #expect(state.localOnly.isEmpty)
  }

  // MARK: - Account changes

  @Test func signingOutOnTheIPhoneKeepsEverythingOnTheDeviceOnly() {
    var state = populatedState()
    _ = state.forgetCloud(keeping: [], keepsLocalHistory: true)
    state.forgetAccount(keepsLocalHistory: true)

    #expect(state.entries.count == 3)
    #expect(state.localOnly.clips.count == 3)
    // Nothing of the old account is sent to the next one on its own.
    #expect(state.uploadableClipIDs.isEmpty)
    #expect(state.unsentClipIDs.isEmpty)
  }

  @Test func signingOutOnTheMacEmptiesTheSyncCopy() {
    var state = populatedState()
    _ = state.forgetCloud(keeping: [], keepsLocalHistory: false)
    state.forgetAccount(keepsLocalHistory: false)
    #expect(state.entries.isEmpty)
  }

  // MARK: - Local-only clips

  @Test func changesToALocalOnlyClipStayOnTheDevice() {
    var state = populatedState()
    _ = state.forgetCloud(keeping: [], keepsLocalHistory: true)
    var pinned = state.entries[Clip.id(for: "sent a")]!.clip
    pinned.pinned = true
    pinned.modifiedAt = late

    let result1 = state.stage(pinned, policy: .default)
    #expect(result1)
    #expect(state.entries[pinned.id]?.clip.pinned == true)
    #expect(state.localOnly.clips.contains(pinned.id))
  }

  @Test func copyingALocalOnlyClipAgainSyncsIt() {
    var state = populatedState()
    _ = state.forgetCloud(keeping: [], keepsLocalHistory: true)
    let id = Clip.id(for: "sent a")
    let copy = state.entries[id]!.clip.copiedAgain(Clip(text: "sent a", sourceDevice: .iphone, firstCopiedAt: late))

    let result2 = state.stage(copy, policy: .default, isCapture: true)
    #expect(result2)
    #expect(!state.localOnly.clips.contains(id))
    #expect(state.unsentClipIDs.contains(id))
  }

  @Test func capturingTheSameLocalOnlyTextReleasesItEvenWithoutAChange() {
    var state = populatedState()
    _ = state.forgetCloud(keeping: [], keepsLocalHistory: true)
    let clip = state.entries[Clip.id(for: "sent b")]!.clip
    let result3 = state.stage(clip, policy: .default, isCapture: true)
    #expect(result3)
    #expect(!state.localOnly.clips.contains(clip.id))
  }

  @Test func uploadAgainReleasesEveryLocalOnlyClipAndCollection() {
    var state = populatedState()
    _ = state.forgetCloud(keeping: [], keepsLocalHistory: true)
    let released = state.releaseLocalOnly()

    #expect(released.clips.count == 3)
    #expect(released.collections == ["col-1"])
    #expect(state.localOnly.isEmpty)
    #expect(Set(state.unsentClipIDs) == Set(state.entries.keys))
    #expect(state.unsentCollectionIDs == ["col-1"])
  }

  // MARK: - Deleted on another device

  @Test func aPinMadeHereDoesNotBringBackAClipDeletedElsewhere() {
    var state = populatedState()
    let id = Clip.id(for: "sent a")
    var pinned = state.entries[id]!.clip
    pinned.pinned = true
    pinned.modifiedAt = late
    let result4 = state.stage(pinned, policy: .default)
    #expect(result4)
    #expect(state.entries[id]?.hasUnsentCopy == false)

    let result5 = state.resolveDeletedElsewhere(clipID: id)
    #expect(result5 == .deleted)
    #expect(state.entries[id] == nil)
  }

  @Test func aNewCopyMadeHereBringsBackAClipDeletedElsewhere() {
    var state = populatedState()
    let id = Clip.id(for: "sent a")
    let copy = state.entries[id]!.clip.copiedAgain(Clip(text: "sent a", sourceDevice: .mac, firstCopiedAt: late))
    let result6 = state.stage(copy, policy: .default)
    #expect(result6)
    #expect(state.entries[id]?.hasUnsentCopy == true)

    let result7 = state.resolveDeletedElsewhere(clipID: id)
    #expect(result7 == .recreate)
    #expect(state.entries[id] != nil)
    #expect(state.entries[id]?.systemFields == nil)
  }

  // MARK: - Eligibility

  /// Only the mirror is ever sent (`ClipSync.record(for:)` builds records from it), so content the policy
  /// rejects can never reach iCloud.
  @Test func ineligibleContentNeverEntersTheMirror() {
    var state = State()
    let tooLarge = String(repeating: "a", count: SyncPolicy.default.maxTextBytes + 1)
    let result8 = state.stage(Clip(text: tooLarge, sourceDevice: .iphone), policy: .default)
    #expect(!result8)
    let result9 = state.stage(Clip(text: "  \n ", sourceDevice: .iphone), policy: .default)
    #expect(!result9)
    let result10 = state.stage(Clip(text: tooLarge, sourceDevice: .iphone), policy: .default, isCapture: true)
    #expect(!result10)
    #expect(state.entries.isEmpty)
    #expect(state.unsentClipIDs.isEmpty)
  }

  // MARK: - Files from 1.1

  @Test func mirrorFromBeforeLocalOnlyMarksDecodes() throws {
    let clip = Clip(text: "old", sourceDevice: .mac, firstCopiedAt: early)
    let entryJSON = String(decoding: try JSONEncoder().encode(clip), as: UTF8.self)
    let json = #"{"schema":2,"entries":{"\#(clip.id)":{"clip":\#(entryJSON)}},"collections":{}}"#
    let state = try JSONDecoder().decode(State.self, from: Data(json.utf8))
    #expect(state.entries[clip.id]?.clip == clip)
    #expect(state.entries[clip.id]?.isLocalOnly == false)
    #expect(state.entries[clip.id]?.hasUnsentCopy == false)
    #expect(state.uploadableClipIDs == [clip.id])
  }

  @Test func localOnlyMarksRoundTrip() throws {
    var state = populatedState()
    _ = state.forgetCloud(keeping: [], keepsLocalHistory: true)
    let decoded = try JSONDecoder().decode(State.self, from: JSONEncoder().encode(state))
    #expect(decoded.localOnly == state.localOnly)
  }
}

@Suite struct LocalOnlyFilesTests {
  let files = SharedClipFiles(directory: FileManager.default.temporaryDirectory.appending(path: "pastronaut-\(UUID().uuidString)"))

  /// The keyboard's cache only knows iCloud. When it is newer than the app's snapshot it must not hide the
  /// clips the app keeps on this iPhone only.
  @Test func keyboardCacheDoesNotHideLocalOnlyClips() throws {
    let kept = Clip(text: "kept here", sourceDevice: .iphone)
    let inCloud = Clip(text: "in iCloud", sourceDevice: .mac)
    let collection = ClipCollection(id: "col-k", name: "Kept", order: 1, createdAt: .now)
    try files.writeSnapshot([kept, inCloud])
    try files.writeCollections([collection])
    try files.writeLocalOnly(LocalOnlyIDs(clips: [kept.id], collections: [collection.id]))
    try files.writeKeyboardCache(KeyboardCache(clips: [inCloud], fetchedAt: .now.addingTimeInterval(60)))

    #expect(Set(files.currentClips().map(\.id)) == [kept.id, inCloud.id])
    #expect(files.currentCollections().map(\.id) == [collection.id])
  }

  @Test func missingLocalOnlyFileReadsAsEmpty() {
    #expect(files.readLocalOnly().isEmpty)
  }

  /// The app removes only what it stored: a capture copied again in the meantime stays for the next time.
  @Test func inboxKeepsCapturesThatChangedAfterReading() throws {
    let first = Clip(text: "x", sourceDevice: .iphone, firstCopiedAt: Date(timeIntervalSince1970: 1_000))
    let other = Clip(text: "y", sourceDevice: .iphone, firstCopiedAt: Date(timeIntervalSince1970: 1_000))
    try files.appendToInbox(first)
    try files.appendToInbox(other)
    let read = files.readInbox()

    try files.appendToInbox(Clip(text: "x", sourceDevice: .iphone, firstCopiedAt: Date(timeIntervalSince1970: 3_000)))
    try files.removeFromInbox(handled: read)

    let left = files.readInbox()
    #expect(left.map(\.text) == ["x"])
    #expect(left.first?.lastCopiedAt == Date(timeIntervalSince1970: 3_000))
  }
}

/// iPhone Settings › Privacy: codes and cards are saved but kept on the iPhone.
@Suite struct PhonePrivacyTests {
  let keepCodes = PrivacyOptions(skipOneTimeCodes: true)

  @Test func aNewCodeIsLocalOnlyFromTheStart() {
    var state = ClipSync.PersistedState()
    let code = Clip(text: "482913", sourceDevice: .iphone)
    let staged = state.stage(code, policy: .default, isCapture: true, privacy: keepCodes)
    #expect(staged)
    #expect(state.entries[code.id] != nil)
    #expect(state.localOnly.clips == [code.id])
    #expect(state.unsentClipIDs.isEmpty)
  }

  @Test func otherTextStillSyncs() {
    var state = ClipSync.PersistedState()
    let note = Clip(text: "Buy milk", sourceDevice: .iphone)
    let staged = state.stage(note, policy: .default, isCapture: true, privacy: keepCodes)
    #expect(staged)
    #expect(state.localOnly.isEmpty)
    #expect(state.unsentClipIDs == [note.id])
  }

  @Test func copyingAKeptCodeAgainDoesNotSendIt() {
    var state = ClipSync.PersistedState()
    let code = Clip(text: "482913", sourceDevice: .iphone, firstCopiedAt: Date(timeIntervalSince1970: 1_000))
    _ = state.stage(code, policy: .default, isCapture: true, privacy: keepCodes)
    let again = state.entries[code.id]!.clip.copiedAgain(Clip(text: "482913", sourceDevice: .iphone))
    _ = state.stage(again, policy: .default, isCapture: true, privacy: keepCodes)
    #expect(state.localOnly.clips == [code.id])
  }

  @Test func uploadAgainLeavesKeptCodesHere() {
    var state = ClipSync.PersistedState()
    let code = Clip(text: "482913", sourceDevice: .iphone)
    let note = Clip(text: "Buy milk", sourceDevice: .iphone)
    for clip in [code, note] {
      state.entries[clip.id] = ClipSync.MirrorEntry(clip: clip, systemFields: nil, isLocalOnly: true)
    }
    let released = state.releaseLocalOnly(privacy: keepCodes)
    #expect(released.clips == [note.id])
    #expect(state.localOnly.clips == [code.id])
  }

  @Test func phoneOptionsComeFromTheAppGroupSettings() {
    let defaults = UserDefaults(suiteName: "pastronaut-tests-\(UUID().uuidString)")!
    #expect(PrivacyOptions.onPhone(in: defaults) == PrivacyOptions())
    defaults.set(true, forKey: PrivacyOptions.phoneCardsKey)
    #expect(PrivacyOptions.onPhone(in: defaults) == PrivacyOptions(skipCardNumbers: true))
  }
}
