import CloudKit
import Foundation
import Testing
@testable import PastronautCore

@Suite struct ClipIDTests {
  @Test func sameTextSameID() {
    #expect(Clip.id(for: "hello") == Clip.id(for: "hello"))
  }

  @Test func lineEndingsAreUnified() {
    #expect(Clip.id(for: "a\r\nb") == Clip.id(for: "a\nb"))
    #expect(Clip.id(for: "a\rb") == Clip.id(for: "a\nb"))
  }

  @Test func otherWhitespaceIsSignificant() {
    #expect(Clip.id(for: "a") != Clip.id(for: "a "))
    #expect(Clip.id(for: "a") != Clip.id(for: "A"))
  }

  @Test func idIsAValidRecordName() {
    let id = Clip.id(for: "ğüşİöç 🚀")
    #expect(id.hasPrefix("clip-"))
    #expect(id.count == 5 + 64)
    #expect(id.allSatisfy { $0.isASCII })
  }

  @Test func kindDetection() {
    #expect(Clip(text: "https://example.com/a?b=1", sourceDevice: .mac).kind == .url)
    #expect(Clip(text: "  http://example.com\n", sourceDevice: .mac).kind == .url)
    #expect(Clip(text: "see https://example.com", sourceDevice: .mac).kind == .text)
    #expect(Clip(text: "ftp://example.com", sourceDevice: .mac).kind == .text)
    #expect(Clip(text: "example.com", sourceDevice: .mac).kind == .text)
  }
}

@Suite struct ClipMergeTests {
  let early = Date(timeIntervalSince1970: 1_000)
  let middle = Date(timeIntervalSince1970: 2_000)
  let late = Date(timeIntervalSince1970: 3_000)

  @Test func datesWidenAndNewerModificationWins() {
    let mac = Clip(text: "x", sourceApp: "com.apple.Safari", sourceDevice: .mac,
                   firstCopiedAt: middle, lastCopiedAt: middle, modifiedAt: middle, pinned: true)
    let phone = Clip(text: "x", sourceApp: nil, sourceDevice: .iphone,
                     firstCopiedAt: early, lastCopiedAt: late, modifiedAt: late, pinned: false)

    let merged = mac.merged(with: phone)
    #expect(merged.firstCopiedAt == early)
    #expect(merged.lastCopiedAt == late)
    #expect(merged.modifiedAt == late)
    #expect(merged.sourceDevice == .iphone)
    #expect(merged.pinned == false)
  }

  @Test func mergeIsSymmetric() {
    let a = Clip(text: "x", sourceDevice: .mac, firstCopiedAt: early, lastCopiedAt: middle, modifiedAt: late, pinned: true)
    let b = Clip(text: "x", sourceDevice: .iphone, firstCopiedAt: middle, lastCopiedAt: late, modifiedAt: middle)
    #expect(a.merged(with: b) == b.merged(with: a))
  }

  @Test func mergingWithItselfIsANoOp() {
    let clip = Clip(text: "x", sourceDevice: .mac, firstCopiedAt: early, lastCopiedAt: late)
    #expect(clip.merged(with: clip) == clip)
  }
}

@Suite struct SyncPolicyTests {
  @Test func eligibility() {
    let policy = SyncPolicy(maxTextBytes: 10)
    #expect(policy.isEligible("hello"))
    #expect(!policy.isEligible(""))
    #expect(!policy.isEligible(" \n\t "))
    #expect(!policy.isEligible("12345678901"))
    #expect(!policy.isEligible("ğğğğğğ")) // 12 bytes in UTF-8
  }
}

@Suite struct ClipRecordTests {
  let date = Date(timeIntervalSince1970: 1_700_000_000)
  let key = SyncKey(data: Data(repeating: 7, count: 32))!

  @Test func roundTrip() throws {
    let clip = Clip(text: "merhaba\ndünya", sourceApp: "com.apple.Notes", sourceAppName: "Notlar", sourceDevice: .iphone,
                    firstCopiedAt: date, lastCopiedAt: date.addingTimeInterval(60),
                    modifiedAt: date.addingTimeInterval(90), pinned: true, collectionIDs: ["col-b", "col-a"])
    let record = ClipRecord.record(for: clip, key: key)

    #expect(record.recordType == ClipRecord.recordType)
    #expect(record.recordID.zoneID == ClipRecord.zoneID)
    #expect(record.recordID.recordName == key.recordName(forClipID: clip.id))
    #expect(ClipRecord.isNamed(record, for: clip, key: key))
    #expect(try #require(ClipRecord.clip(from: record)) == clip)
  }

  @Test func recordNamesRevealNothingWithoutTheKey() {
    let clip = Clip(text: "123456", sourceDevice: .iphone)
    let name = ClipRecord.record(for: clip, key: key).recordID.recordName
    #expect(!name.contains(clip.id.dropFirst("clip-".count)))
    #expect(name.hasPrefix("c-") && name.count == 66)
    #expect(name != SyncKey(data: Data(repeating: 8, count: 32))!.recordName(forClipID: clip.id))
    #expect(name == key.recordName(forClipID: Clip.id(for: "123456")))
  }

  @Test func textSourceAndCollectionsAreEncrypted() {
    let clip = Clip(text: "secret", sourceApp: "app", sourceAppName: "App", sourceDevice: .mac, collectionIDs: ["col-1"])
    let record = ClipRecord.record(for: clip, key: key)
    #expect(record["text"] == nil)
    #expect(record["sourceApp"] == nil)
    #expect(record["sourceAppName"] == nil)
    #expect(record["collections"] == nil)
    #expect(record.encryptedValues["sourceAppName"] as? String == "App")
    #expect(record.encryptedValues["text"] as? String == "secret")
    #expect(record.encryptedValues["collections"] as? [String] == ["col-1"])
  }

  @Test func noCollectionsStoresNoList() {
    let record = ClipRecord.record(for: Clip(text: "x", sourceDevice: .mac), key: key)
    #expect(record.encryptedValues["collections"] == nil)
  }

  @Test func recordsNamedWithAnotherKeyAreNoticed() throws {
    let other = SyncKey(data: Data(repeating: 9, count: 32))!
    let clip = Clip(text: "one", sourceDevice: .mac)
    let record = ClipRecord.record(for: clip, key: other)
    #expect(!ClipRecord.isNamed(record, for: clip, key: key))
    // Its content is still readable, so the clip can be moved to the right name.
    #expect(try #require(ClipRecord.clip(from: record)).text == "one")
  }

  @Test func legacyRecordsAreNamedAfterTheClipID() throws {
    let clip = Clip(text: "old", sourceDevice: .mac)
    let record = CKRecord(recordType: ClipRecord.recordType, recordID: CKRecord.ID(recordName: clip.id, zoneID: ClipRecord.legacyZoneID))
    record.encryptedValues["text"] = "old"
    let read = try #require(ClipRecord.clip(from: record))
    #expect(ClipRecord.isLegacyRecord(record, of: read))
    record.encryptedValues["text"] = "changed"
    #expect(!ClipRecord.isLegacyRecord(record, of: try #require(ClipRecord.clip(from: record))))
  }

  @Test func rejectsOtherRecordTypes() {
    let record = CKRecord(recordType: "Other", recordID: ClipRecord.recordID(forClipID: Clip.id(for: "x"), key: key))
    record.encryptedValues["text"] = "x"
    #expect(ClipRecord.clip(from: record) == nil)
  }

  @Test func systemFieldsRoundTripKeepTheRecordID() throws {
    let record = ClipRecord.record(for: Clip(text: "x", sourceDevice: .mac), key: key)
    let restored = try #require(ClipRecord.record(fromSystemFields: ClipRecord.systemFields(of: record)))
    #expect(restored.recordID == record.recordID)
    #expect(restored.recordType == record.recordType)
  }

  @Test func updatingAnExistingRecordKeepsItsIdentity() {
    let existing = ClipRecord.record(for: Clip(text: "x", sourceDevice: .mac), key: key)
    let updated = ClipRecord.record(for: Clip(text: "x", sourceDevice: .iphone, pinned: true), key: key, updating: existing)
    #expect(updated === existing)
    #expect(updated["sourceDevice"] as? String == "iphone")
    #expect(updated["pinned"] as? Int64 == 1)
  }

  @Test func collectionRoundTripWithEncryptedName() throws {
    let collection = ClipCollection(name: "Adresler", order: 2, createdAt: date, modifiedAt: date.addingTimeInterval(5))
    let record = CollectionRecord.record(for: collection)
    #expect(record.recordID.recordName == collection.id)
    #expect(record.recordID.zoneID == ClipRecord.zoneID)
    #expect(record["name"] == nil)
    #expect(record.encryptedValues["name"] as? String == "Adresler")
    #expect(try #require(CollectionRecord.collection(from: record)) == collection)
  }

  @Test func settingsRecordCarriesTheKeyEncrypted() throws {
    let record = SettingsRecord.record(with: key)
    #expect(record.recordID == SettingsRecord.recordID)
    #expect(record["idKey"] == nil)
    #expect(SettingsRecord.key(from: record) == key)
  }
}

@Suite struct CopiedAgainTests {
  @Test func keepsPinAndTakesNewerCopy() {
    let early = Date(timeIntervalSince1970: 1_000)
    let late = Date(timeIntervalSince1970: 2_000)
    let pinned = Clip(text: "same", sourceDevice: .mac, firstCopiedAt: early, pinned: true)
    let capture = Clip(text: "same", sourceDevice: .iphone, firstCopiedAt: late)
    let result = pinned.copiedAgain(capture)
    #expect(result.pinned)
    #expect(result.firstCopiedAt == early)
    #expect(result.lastCopiedAt == late)
    #expect(result.modifiedAt == late)
    #expect(result.sourceDevice == .iphone)
    // The plain merge would have unpinned it; that is why captures use copiedAgain.
    #expect(pinned.merged(with: capture).pinned == false)
  }

  @Test func olderCopyKeepsSource() {
    let early = Date(timeIntervalSince1970: 1_000)
    let late = Date(timeIntervalSince1970: 2_000)
    let clip = Clip(text: "same", sourceDevice: .mac, firstCopiedAt: late)
    let result = clip.copiedAgain(Clip(text: "same", sourceDevice: .iphone, firstCopiedAt: early))
    #expect(result.sourceDevice == .mac)
    #expect(result.firstCopiedAt == early)
    #expect(result.lastCopiedAt == late)
  }
}

@Suite struct KeyboardCacheTests {
  private let date = Date(timeIntervalSince1970: 5_000)

  @Test func fullFetchReplacesEverything() {
    var cache = KeyboardCache(clips: [Clip(text: "gone", sourceDevice: .mac)])
    cache.apply(fetched: [Clip(text: "kept", sourceDevice: .mac)], deletedIDs: [], isFullFetch: true, token: Data([1]), at: date)
    #expect(cache.clips.map(\.text) == ["kept"])
    #expect(cache.token == Data([1]))
    #expect(cache.fetchedAt == date)
  }

  @Test func incrementalFetchMergesAndDeletes() {
    let a = Clip(text: "a", sourceDevice: .mac)
    let b = Clip(text: "b", sourceDevice: .mac)
    var cache = KeyboardCache(clips: [a, b], token: Data([1]))
    var pinnedA = a
    pinnedA.pinned = true
    pinnedA.modifiedAt = a.modifiedAt.addingTimeInterval(10)
    let c = Clip(text: "c", sourceDevice: .iphone)
    cache.apply(fetched: [pinnedA, c], deletedIDs: [b.id], isFullFetch: false, token: Data([2]), at: date)
    #expect(Set(cache.clips.map(\.text)) == ["a", "c"])
    #expect(cache.clips.first { $0.text == "a" }?.pinned == true)
    #expect(cache.token == Data([2]))
  }

  @Test func insertMergesWithExisting() {
    var cache = KeyboardCache(clips: [Clip(text: "a", sourceDevice: .mac)])
    cache.insert(Clip(text: "a", sourceDevice: .iphone, firstCopiedAt: .now.addingTimeInterval(60)))
    #expect(cache.clips.count == 1)
    cache.insert(Clip(text: "b", sourceDevice: .iphone))
    #expect(cache.clips.count == 2)
  }
}
