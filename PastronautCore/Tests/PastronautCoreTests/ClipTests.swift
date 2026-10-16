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

  @Test func roundTrip() throws {
    let clip = Clip(text: "merhaba\ndünya", sourceApp: "com.apple.Notes", sourceDevice: .iphone,
                    firstCopiedAt: date, lastCopiedAt: date.addingTimeInterval(60),
                    modifiedAt: date.addingTimeInterval(90), pinned: true)
    let record = ClipRecord.record(for: clip)

    #expect(record.recordType == ClipRecord.recordType)
    #expect(record.recordID.zoneID == ClipRecord.zoneID)
    #expect(record.recordID.recordName == clip.id)
    #expect(try #require(ClipRecord.clip(from: record)) == clip)
  }

  @Test func textAndSourceAppAreEncrypted() {
    let record = ClipRecord.record(for: Clip(text: "secret", sourceApp: "app", sourceDevice: .mac))
    #expect(record["text"] == nil)
    #expect(record["sourceApp"] == nil)
    #expect(record.encryptedValues["text"] as? String == "secret")
  }

  @Test func rejectsRecordsWhoseIDDoesNotMatchTheText() {
    let record = ClipRecord.record(for: Clip(text: "one", sourceDevice: .mac))
    record.encryptedValues["text"] = "two"
    #expect(ClipRecord.clip(from: record) == nil)
  }

  @Test func rejectsOtherRecordTypes() {
    let record = CKRecord(recordType: "Other", recordID: ClipRecord.recordID(for: Clip.id(for: "x")))
    record.encryptedValues["text"] = "x"
    #expect(ClipRecord.clip(from: record) == nil)
  }

  @Test func systemFieldsRoundTripKeepTheRecordID() throws {
    let record = ClipRecord.record(for: Clip(text: "x", sourceDevice: .mac))
    let restored = try #require(ClipRecord.record(fromSystemFields: ClipRecord.systemFields(of: record)))
    #expect(restored.recordID == record.recordID)
    #expect(restored.recordType == record.recordType)
  }

  @Test func updatingAnExistingRecordKeepsItsIdentity() {
    let existing = ClipRecord.record(for: Clip(text: "x", sourceDevice: .mac))
    let updated = ClipRecord.record(for: Clip(text: "x", sourceDevice: .iphone, pinned: true), updating: existing)
    #expect(updated === existing)
    #expect(updated["sourceDevice"] as? String == "iphone")
    #expect(updated["pinned"] as? Int64 == 1)
  }
}
