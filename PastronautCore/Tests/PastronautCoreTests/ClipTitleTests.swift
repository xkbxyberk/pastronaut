import CloudKit
import Foundation
import Testing
@testable import PastronautCore

/// Titles (1.2): a name for a clip that merges on its own clock, so devices that don't know titles can't erase one.
@Suite struct ClipTitleTests {
  let key = SyncKey(data: Data(repeating: 7, count: 32))!
  let early = Date(timeIntervalSince1970: 1_000)
  let late = Date(timeIntervalSince1970: 2_000)
  let later = Date(timeIntervalSince1970: 3_000)

  func clip(modifiedAt: Date) -> Clip {
    Clip(text: "TR12 0006 1005 1978 6457 8413 26", sourceDevice: .iphone, firstCopiedAt: early, modifiedAt: modifiedAt)
  }

  @Test func titlesAreTrimmedCutAndClearedWhenBlank() {
    var titled = clip(modifiedAt: early)
    titled.setTitle("  Work IBAN \n", at: late)
    #expect(titled.title == "Work IBAN")
    #expect(titled.titleModifiedAt == late)
    titled.setTitle(String(repeating: "a", count: 300), at: late)
    #expect(titled.title?.count == Clip.maxTitleLength)
    titled.setTitle("   ", at: later)
    #expect(titled.title == nil)
    #expect(titled.titleModifiedAt == later)
    #expect(titled.id == clip(modifiedAt: early).id)
  }

  /// The Mac copying the text again sends a newer version without a title; the title stays.
  @Test func aNewerVersionWithoutATitleKeepsTheTitle() {
    var titled = clip(modifiedAt: early)
    titled.setTitle("Work IBAN", at: late)
    var pinnedElsewhere = clip(modifiedAt: later)
    pinnedElsewhere.pinned = true

    for merged in [titled.merged(with: pinnedElsewhere), pinnedElsewhere.merged(with: titled)] {
      #expect(merged.title == "Work IBAN")
      #expect(merged.pinned)
      #expect(merged.modifiedAt == later)
    }
  }

  @Test func theLaterTitleChangeWinsIncludingClearing() {
    var named = clip(modifiedAt: later)
    named.setTitle("Old", at: early)
    var cleared = clip(modifiedAt: early)
    cleared.setTitle(nil, at: late)

    for merged in [named.merged(with: cleared), cleared.merged(with: named)] {
      #expect(merged.title == nil)
      #expect(merged.titleModifiedAt == late)
    }
  }

  @Test func copyingAgainKeepsTheTitle() {
    var titled = clip(modifiedAt: early)
    titled.setTitle("Work IBAN", at: late)
    let copy = Clip(text: titled.text, sourceDevice: .mac, firstCopiedAt: later)
    #expect(titled.copiedAgain(copy).title == "Work IBAN")
  }

  // MARK: - CloudKit

  @Test func titleIsEncryptedAndRoundTrips() throws {
    var titled = clip(modifiedAt: early)
    titled.setTitle("Work IBAN", at: late)
    let record = ClipRecord.record(for: titled, key: key)
    #expect(record["title"] == nil)
    #expect(record.encryptedValues["title"] as? String == "Work IBAN")
    #expect(record["titleModifiedAt"] as? Date == late)
    #expect(try #require(ClipRecord.clip(from: record)) == titled)
  }

  /// Saving a clip that never had a title leaves the fields alone, so a title set elsewhere survives, the same
  /// way clients from before 1.2 behave.
  @Test func untitledClipsDoNotTouchTheTitleFields() {
    let record = ClipRecord.record(for: clip(modifiedAt: early), key: key)
    #expect(!record.allKeys().contains("titleModifiedAt"))
    #expect(!record.encryptedValues.allKeys().contains("title"))
  }

  @Test func clearedTitleIsWrittenAsCleared() throws {
    var cleared = clip(modifiedAt: early)
    cleared.setTitle(nil, at: late)
    let record = ClipRecord.record(for: cleared, key: key)
    #expect(record["titleModifiedAt"] as? Date == late)
    let decoded = try #require(ClipRecord.clip(from: record))
    #expect(decoded.title == nil)
    #expect(decoded.titleModifiedAt == late)
  }

  // MARK: - Files, search and archives

  @Test func clipsFromBeforeTitlesDecode() throws {
    let json = #"""
    {"id":"clip-x","text":"x","kind":"text","sourceDevice":"mac","firstCopiedAt":0,"lastCopiedAt":0,
     "modifiedAt":0,"pinned":false}
    """#
    let decoded = try JSONDecoder().decode(Clip.self, from: Data(json.utf8))
    #expect(decoded.title == nil)
    #expect(decoded.titleModifiedAt == nil)
  }

  @Test func titleRoundTripsThroughJSON() throws {
    var titled = clip(modifiedAt: early)
    titled.setTitle("Work IBAN", at: late)
    #expect(try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(titled)) == titled)
  }

  @Test func searchFindsTitles() {
    var titled = clip(modifiedAt: early)
    titled.setTitle("İş IBAN'ı", at: late)
    let other = Clip(text: "something else", sourceDevice: .mac)
    #expect([titled, other].matching("is iban").map(\.id) == [titled.id])
  }

  @Test func archivesCarryTitlesAndImportOnlyAddsThem() throws {
    var titled = clip(modifiedAt: early)
    titled.setTitle("Work IBAN", at: late)
    let archive = try ClipArchive.decode(ClipArchive(clips: [titled], collections: []).encoded())
    #expect(archive.clips.first?.title == "Work IBAN")

    let fresh = archive.importPlan(existingClips: [], existingCollections: [], device: .iphone, now: later)
    #expect(fresh.clips.first?.title == "Work IBAN")

    var renamedHere = clip(modifiedAt: early)
    renamedHere.setTitle("Mine", at: later)
    let existing = archive.importPlan(existingClips: [renamedHere], existingCollections: [], device: .iphone, now: later)
    #expect(existing.clips.isEmpty)
  }

  @Test func archivesFromBeforeTitlesImport() throws {
    let json = #"""
    {"format":"pastronaut-archive","version":1,"exportedAt":"2026-10-17T10:00:00Z","collections":[],
     "clips":[{"text":"x","pinned":false,"collections":[],"firstCopiedAt":"2026-10-17T09:00:00Z",
               "lastCopiedAt":"2026-10-17T09:00:00Z"}]}
    """#
    let archive = try ClipArchive.decode(Data(json.utf8))
    #expect(archive.clips.first?.title == nil)
  }
}
