import Foundation
import Testing
@testable import PastronautCore

@Suite struct CollectionsTests {
  let date = Date(timeIntervalSince1970: 1_700_000_000)

  @Test func membershipIsSortedAndUnique() {
    var clip = Clip(text: "a", sourceDevice: .mac, collectionIDs: ["col-b", "col-a", "col-b"])
    #expect(clip.collectionIDs == ["col-a", "col-b"])
    clip.collectionIDs.append("col-a")
    #expect(clip.collectionIDs == ["col-a", "col-b"])
  }

  @Test func clipsInACollectionAreKept() {
    #expect(!Clip(text: "a", sourceDevice: .mac).isKept)
    #expect(Clip(text: "a", sourceDevice: .mac, pinned: true).isKept)
    #expect(Clip(text: "a", sourceDevice: .mac, collectionIDs: ["col-1"]).isKept)
  }

  @Test func membershipFollowsTheNewerChange() {
    let old = Clip(text: "a", sourceDevice: .mac, firstCopiedAt: date, collectionIDs: ["col-1"])
    var newer = old
    newer.collectionIDs = []
    newer.modifiedAt = date.addingTimeInterval(10)
    #expect(old.merged(with: newer).collectionIDs.isEmpty)
    #expect(newer.merged(with: old).collectionIDs.isEmpty)
  }

  @Test func anotherCopyKeepsCollections() {
    let saved = Clip(text: "a", sourceDevice: .mac, firstCopiedAt: date, collectionIDs: ["col-1"])
    let copy = Clip(text: "a", sourceDevice: .iphone, firstCopiedAt: date.addingTimeInterval(60))
    let result = saved.copiedAgain(copy)
    #expect(result.collectionIDs == ["col-1"])
    #expect(result.sourceDevice == .iphone)
  }

  @Test func clipsFromBeforeCollectionsStillDecode() throws {
    let json = """
      {"id":"\(Clip.id(for: "x"))","text":"x","kind":"text","sourceDevice":"mac","firstCopiedAt":0,
       "lastCopiedAt":0,"modifiedAt":0,"pinned":true}
      """
    let clip = try JSONDecoder().decode(Clip.self, from: Data(json.utf8))
    #expect(clip.collectionIDs.isEmpty)
    #expect(clip.pinned)
    let encoded = String(decoding: try JSONEncoder().encode(clip), as: UTF8.self)
    #expect(!encoded.contains("collectionIDs"))
    var member = clip
    member.collectionIDs = ["col-1"]
    #expect(try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(member)) == member)
  }

  @Test func collectionOrderAndNames() {
    let a = ClipCollection(id: "col-a", name: "Work", order: 2, createdAt: date)
    let b = ClipCollection(id: "col-b", name: "Adresler", order: 1, createdAt: date)
    let c = ClipCollection(id: "col-c", name: "Kod", order: 2, createdAt: date)
    #expect([a, b, c].ordered.map(\.name) == ["Adresler", "Kod", "Work"])
    #expect([a, b, c].nextOrder == 3)
    #expect(ClipCollection.cleanName("  Adres \n") == "Adres")
    #expect(ClipCollection.cleanName("   ") == nil)
    #expect(ClipCollection.cleanName(String(repeating: "x", count: 100))?.count == 60)
    #expect(ClipCollection.isValidID(ClipCollection.newID()))
  }

  @Test func newerRenameWins() {
    let original = ClipCollection(id: "col-a", name: "Old", order: 1, createdAt: date)
    var renamed = original
    renamed.name = "New"
    renamed.modifiedAt = date.addingTimeInterval(5)
    #expect(original.merged(with: renamed).name == "New")
    #expect(renamed.merged(with: original).name == "New")
  }

  @Test func keyboardCacheTracksCollections() {
    var cache = KeyboardCache()
    let work = ClipCollection(id: "col-w", name: "Work", order: 1, createdAt: date)
    cache.apply(fetched: [], deletedIDs: [], fetchedCollections: [work], isFullFetch: true, token: nil, at: date)
    #expect(cache.collections == [work])
    cache.apply(fetched: [], deletedIDs: [], deletedCollectionIDs: ["col-w"], isFullFetch: false, token: nil, at: date)
    #expect(cache.collections.isEmpty)
  }

  @Test func keyboardCacheFromTheOldZoneStartsOver() throws {
    let json = #"{"clips":[],"token":"AQ==","fetchedAt":0}"#
    let cache = try JSONDecoder().decode(KeyboardCache.self, from: Data(json.utf8))
    #expect(cache.zone == nil)
    #expect(cache.collections.isEmpty)
    #expect(KeyboardCache().zone == ClipRecord.zoneName)
  }

  @Test func sharedCollectionsFile() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let files = SharedClipFiles(directory: directory)
    defer { try? FileManager.default.removeItem(at: directory) }
    #expect(files.currentCollections().isEmpty)
    let work = ClipCollection(id: "col-w", name: "Work", order: 2, createdAt: date)
    let home = ClipCollection(id: "col-h", name: "Home", order: 1, createdAt: date)
    try files.writeCollections([work, home])
    #expect(files.currentCollections().map(\.name) == ["Home", "Work"])
  }
}

@Suite struct SyncStateTests {
  @Test func stateFromVersionOneNeedsTheMove() throws {
    let json = #"{"entries":{}}"#
    let state = try JSONDecoder().decode(ClipSync.PersistedState.self, from: Data(json.utf8))
    #expect(state.schema == 1)
    #expect(state.needsLegacyCleanup)
    #expect(state.key == nil)
    #expect(state.collections.isEmpty)
  }

  @Test func newStateRoundTrips() throws {
    var state = ClipSync.PersistedState()
    #expect(state.schema == ClipSync.PersistedState.currentSchema)
    state.key = SyncKey.generate()
    state.needsLegacyCleanup = false
    state.legacyTombstones = ["clip-1"]
    let decoded = try JSONDecoder().decode(ClipSync.PersistedState.self, from: JSONEncoder().encode(state))
    #expect(decoded.key == state.key)
    #expect(decoded.schema == 2)
    #expect(!decoded.needsLegacyCleanup)
    #expect(decoded.legacyTombstones == ["clip-1"])
  }

  @Test func keyFileRoundTrip() {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = SyncKeyFile(directory: directory)
    #expect(file.read() == nil)
    let key = SyncKey.generate()
    file.write(key)
    #expect(file.read() == key)
    file.write(nil)
    #expect(file.read() == nil)
  }

  @Test func keysMustBe256Bits() {
    #expect(SyncKey(data: Data(count: 16)) == nil)
    #expect(SyncKey.generate().data.count == 32)
    #expect(SyncKey.generate() != SyncKey.generate())
  }

  @Test func onlyKeyedNamesCountAsClipRecords() {
    #expect(ClipSync.isClipRecordName(SyncKey.generate().recordName(forClipID: "clip-x")))
    #expect(!ClipSync.isClipRecordName(SettingsRecord.recordName))
    #expect(!ClipSync.isClipRecordName(ClipCollection.newID()))
  }
}

@Suite struct ClipArchiveTests {
  let date = Date(timeIntervalSince1970: 1_700_000_000)
  let now = Date(timeIntervalSince1970: 1_800_000_000)

  private var collections: [ClipCollection] {
    [ClipCollection(id: "col-1", name: "Adresler", order: 1, createdAt: date)]
  }

  private var clips: [Clip] {
    [
      Clip(text: "Kadıköy, İstanbul", sourceDevice: .iphone, firstCopiedAt: date, pinned: true, collectionIDs: ["col-1", "col-gone"]),
      Clip(text: "https://example.com", sourceApp: "com.apple.Safari", sourceAppName: "Safari", sourceDevice: .mac, firstCopiedAt: date)
    ]
  }

  @Test func roundTrip() throws {
    let archive = ClipArchive(clips: clips, collections: collections, exportedAt: date)
    let data = try archive.encoded()
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains("\"format\" : \"pastronaut-archive\""))
    #expect(text.contains("https://example.com"))
    let read = try ClipArchive.decode(data)
    #expect(read == archive)
    // Collections the file doesn't describe are dropped.
    #expect(read.clips.first { $0.pinned }?.collections == ["col-1"])
  }

  @Test func rejectsOtherFiles() {
    #expect(throws: ClipArchive.ReadError.notAnArchive) { try ClipArchive.decode(Data("[1,2]".utf8)) }
    #expect(throws: ClipArchive.ReadError.notAnArchive) { try ClipArchive.decode(Data("not json".utf8)) }
    let newer = #"{"format":"pastronaut-archive","version":99}"#
    #expect(throws: ClipArchive.ReadError.newerVersion(99)) { try ClipArchive.decode(Data(newer.utf8)) }
  }

  @Test func importIntoEmptyHistory() throws {
    let archive = try ClipArchive.decode(ClipArchive(clips: clips, collections: collections, exportedAt: date).encoded())
    let plan = archive.importPlan(existingClips: [], existingCollections: [], device: .mac, now: now)
    #expect(plan.newClipCount == 2)
    #expect(plan.collections.map(\.name) == ["Adresler"])
    let address = try #require(plan.clips.first { $0.pinned })
    #expect(address.collectionIDs == [plan.collections[0].id])
    #expect(address.sourceDevice == .iphone)
    #expect(address.firstCopiedAt == date)
  }

  @Test func importOnlyAddsAndIsIdempotent() throws {
    let archive = ClipArchive(clips: clips, collections: collections, exportedAt: date)
    let existingCollection = ClipCollection(id: "col-mine", name: "adresler", order: 5, createdAt: date)
    let existingAddress = Clip(text: "Kadıköy, İstanbul", sourceDevice: .mac, firstCopiedAt: date.addingTimeInterval(-60))
    let plan = archive.importPlan(existingClips: [existingAddress], existingCollections: [existingCollection], device: .mac, now: now)
    // The collection with the same name (any case) is reused.
    #expect(plan.collections.isEmpty)
    #expect(plan.newClipCount == 1)
    let merged = try #require(plan.clips.first { $0.id == existingAddress.id })
    #expect(merged.pinned)
    #expect(merged.collectionIDs == ["col-mine"])
    #expect(merged.firstCopiedAt == existingAddress.firstCopiedAt)
    #expect(merged.modifiedAt == now)

    let again = archive.importPlan(existingClips: plan.clips, existingCollections: [existingCollection], device: .mac, now: now)
    #expect(again.clips.isEmpty)
    #expect(again.newClipCount == 0)
  }

  @Test func importNeverUnpins() {
    let archive = ClipArchive(clips: [Clip(text: "x", sourceDevice: .mac, firstCopiedAt: date)], collections: [], exportedAt: date)
    let pinned = Clip(text: "x", sourceDevice: .mac, firstCopiedAt: date, pinned: true)
    #expect(archive.importPlan(existingClips: [pinned], existingCollections: [], device: .mac, now: now).clips.isEmpty)
  }

  @Test func fileName() {
    #expect(ClipArchive.suggestedFileName(on: date).hasPrefix("Pastronaut 2023-11-1"))
    #expect(ClipArchive.suggestedFileName(on: date).hasSuffix(".json"))
  }
}

@Suite struct CollectionLookTests {
  @Test func tintIsStableAndInitialIsTurkish() {
    let work = ClipCollection(id: "col-1234", name: "iş", order: 1)
    #expect(work.tintIndex == ClipCollection(id: "col-1234", name: "renamed", order: 9).tintIndex)
    #expect((0..<ClipCollection.tints.count).contains(work.tintIndex))
    #expect(work.initial == "İ")
    #expect(ClipCollection(id: "col-x", name: "  adresler", order: 1).initial == "A")
  }
}
