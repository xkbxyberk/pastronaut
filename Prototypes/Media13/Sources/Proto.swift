import AppKit
import CloudKit
import CryptoKit
import OSLog

// Throwaway prototype for Adım 0 of docs/pastronaut/PLAN-1.3.md. Run through `open` so the app is its own
// responsible process (sandbox and privacy prompts apply to it, not to the shell); read the results with
// /usr/bin/log show --predicate 'subsystem == "com.xkbxyberk.pastronaut.mediaproto"'.

let log = Logger(subsystem: "com.xkbxyberk.pastronaut.mediaproto", category: Bundle.main.bundleIdentifier ?? "-")

func say(_ line: String) {
  log.notice("\(line, privacy: .public)")
  print(line)
}

func hex(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func seconds(since start: Date) -> String {
  String(format: "%.1f s", Date().timeIntervalSince(start))
}

@main
enum Main {
  static func main() async {
    let arguments = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
    say("start \(Array(arguments))")
    do {
      switch arguments.first {
      case "transfer":
        try await Transfer.run(megabytes: arguments.dropFirst().compactMap(Int.init))
      case "send":
        try await Transfer.run(megabytes: arguments.dropFirst().compactMap(Int.init), fetchHere: false)
      case "fetch":
        try await Transfer.fetch()
      case "cleanup":
        try await Transfer.cleanup()
      case "keys":
        try await Transfer.desiredKeys()
      case "purge":
        // macOS keeps the shell out of app containers, so each app empties its own.
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        for path in ["Caches/CloudKit", "Application Support/Received"] {
          try? FileManager.default.removeItem(at: library.appending(path: path))
        }
        say("purged")
      case "read":
        PasteTest.read()
      case "write":
        try PasteTest.write(to: arguments.dropFirst().first ?? "container")
      default:
        say("usage: transfer|send <MB>… | fetch | cleanup | read | write container|downloads")
      }
    } catch {
      say("ERROR \(error)")
    }
    say("done")
  }
}

// MARK: - CKSyncEngine with large encrypted assets

/// A zone of its own in the Development environment, deleted by `cleanup`. Nothing touches the Library zone.
let zoneID = CKRecordZone.ID(zoneName: "ProtoMedia13")
let container = CKContainer(identifier: "iCloud.com.xkbxyberk.pastronaut")
/// Test key; real files would use the account's own key.
let testKey = SymmetricKey(data: SHA256.hash(data: Data("pastronaut media prototype".utf8)))

final class EngineDelegate: CKSyncEngineDelegate, @unchecked Sendable {
  let name: String
  let copies: URL
  var recordsToSend: [CKRecord.ID: CKRecord] = [:]
  /// Fetched records of the test zone, with the asset's file as the engine handed it and our copy of it.
  var fetched: [(record: CKRecord, assetURL: URL?, copy: URL?)] = []
  var otherZoneRecords = 0
  var failedSaves = 0

  init(name: String, copies: URL) {
    self.name = name
    self.copies = copies
  }

  func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
    switch event {
    case .fetchedRecordZoneChanges(let changes):
      for modification in changes.modifications {
        let record = modification.record
        guard record.recordID.zoneID == zoneID else {
          otherZoneRecords += 1
          continue
        }
        let url = (record["payload"] as? CKAsset)?.fileURL
        let size = url.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? Int }
        say("[\(name)] fetched \(record.recordID.recordName): asset file \(url?.path ?? "nil"), \(size ?? -1) bytes")
        var copy: URL?
        if let url, size != nil {
          let target = copies.appending(path: record.recordID.recordName)
          try? FileManager.default.removeItem(at: target)
          do {
            try FileManager.default.copyItem(at: url, to: target)
            copy = target
          } catch {
            say("[\(name)] cannot copy the asset: \(error.localizedDescription)")
          }
        }
        fetched.append((record, url, copy))
      }
    case .sentRecordZoneChanges(let sent):
      for record in sent.savedRecords {
        say("[\(name)] saved \(record.recordID.recordName)")
      }
      for failure in sent.failedRecordSaves {
        failedSaves += 1
        say("[\(name)] FAILED \(failure.record.recordID.recordName): \(failure.error.code.rawValue) \(failure.error.localizedDescription)")
      }
    case .willSendChanges, .didSendChanges, .willFetchChanges, .didFetchChanges, .stateUpdate,
         .willFetchRecordZoneChanges, .didFetchRecordZoneChanges, .fetchedDatabaseChanges, .sentDatabaseChanges,
         .accountChange:
      break
    @unknown default:
      break
    }
  }

  func nextRecordZoneChangeBatch(
    _ context: CKSyncEngine.SendChangesContext,
    syncEngine: CKSyncEngine
  ) async -> CKSyncEngine.RecordZoneChangeBatch? {
    let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
    guard !pending.isEmpty else { return nil }
    let records = recordsToSend
    let batch = await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { records[$0] }
    say("[\(name)] batch: \(batch?.recordsToSave.count ?? 0) records")
    return batch
  }
}

enum Transfer {
  static func engine(_ delegate: EngineDelegate) -> CKSyncEngine {
    var configuration = CKSyncEngine.Configuration(
      database: container.privateCloudDatabase,
      stateSerialization: nil,
      delegate: delegate
    )
    configuration.automaticallySync = false
    return CKSyncEngine(configuration)
  }

  /// Sends payloads of the given sizes from engine A; with `fetchHere`, a fresh engine B in this same app fetches
  /// them. That B shares this app's CloudKit asset cache, so `fetch` from another app measures a real download.
  static func run(megabytes: [Int], fetchHere: Bool = true) async throws {
    say("account status \(try await container.accountStatus().rawValue) (1 = available)")
    _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])

    let work = FileManager.default.temporaryDirectory.appending(path: "mediaproto")
    let outgoing = work.appending(path: "out")
    let incoming = work.appending(path: "in")
    for directory in [outgoing, incoming] {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // Device A: encrypt random payloads and send them as assets.
    let sender = EngineDelegate(name: "A", copies: incoming)
    let engineA = engine(sender)
    var expected: [String: String] = [:]
    for size in megabytes {
      var bytes = Data(count: size * 1_000_000)
      bytes.withUnsafeMutableBytes { _ = SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!) }
      let sealed = try AES.GCM.seal(bytes, using: testKey).combined!
      let name = "proto-\(size)mb-\(UUID().uuidString.prefix(8))"
      let file = outgoing.appending(path: name)
      try sealed.write(to: file)
      let record = CKRecord(recordType: "ProtoMedia", recordID: CKRecord.ID(recordName: name, zoneID: zoneID))
      record["payload"] = CKAsset(fileURL: file)
      record["megabytes"] = size
      record.encryptedValues["sha"] = hex(bytes)
      sender.recordsToSend[record.recordID] = record
      expected[name] = hex(bytes)
      engineA.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
    }
    var start = Date()
    try await engineA.sendChanges()
    say("SEND \(megabytes) MB took \(seconds(since: start)), failed saves: \(sender.failedSaves)")
    guard fetchHere else { return }

    // Device B: a fresh engine (no state), fetching the whole database as the automatic sync would.
    let receiver = EngineDelegate(name: "B", copies: incoming)
    let engineB = engine(receiver)
    start = Date()
    try await engineB.fetchChanges()
    say("FETCH took \(seconds(since: start)); \(receiver.fetched.count) test records, \(receiver.otherZoneRecords) records of other zones")

    // How long does the engine's own file live once the event was handled?
    for item in receiver.fetched {
      let alive = item.assetURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
      say("asset file of \(item.record.recordID.recordName) still there after the fetch: \(alive)")
    }
    try await Task.sleep(for: .seconds(10))
    for item in receiver.fetched {
      let alive = item.assetURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
      say("… and 10 s later: \(alive)")
    }

    // Our copies decrypt to the original bytes.
    for item in receiver.fetched {
      let name = item.record.recordID.recordName
      guard let copy = item.copy else {
        say("VERIFY \(name): no copy")
        continue
      }
      let opened = try AES.GCM.open(AES.GCM.SealedBox(combined: Data(contentsOf: copy)), using: testKey)
      say("VERIFY \(name): \(hex(opened) == expected[name] ? "OK" : "MISMATCH") (\(opened.count) bytes)")
    }
    let missing = Set(expected.keys).subtracting(receiver.fetched.map(\.record.recordID.recordName))
    say("missing on B: \(missing.sorted())")
    try? FileManager.default.removeItem(at: work)
  }

  /// Device B in another app: fetches the whole database with a fresh engine and checks the payloads.
  static func fetch() async throws {
    let incoming = FileManager.default.temporaryDirectory.appending(path: "mediaproto-in")
    try FileManager.default.createDirectory(at: incoming, withIntermediateDirectories: true)
    let receiver = EngineDelegate(name: "B", copies: incoming)
    let start = Date()
    try await engine(receiver).fetchChanges()
    say("FETCH took \(seconds(since: start)); \(receiver.fetched.count) test records, \(receiver.otherZoneRecords) records of other zones")
    for item in receiver.fetched {
      let name = item.record.recordID.recordName
      guard let copy = item.copy else {
        say("VERIFY \(name): no file")
        continue
      }
      let opened = try AES.GCM.open(AES.GCM.SealedBox(combined: Data(contentsOf: copy)), using: testKey)
      let ok = hex(opened) == item.record.encryptedValues["sha"] as? String
      say("VERIFY \(name): \(ok ? "OK" : "MISMATCH") (\(opened.count) bytes)")
    }
    try? FileManager.default.removeItem(at: incoming)
  }

  /// Does a zone fetch with `desiredKeys` return encrypted fields by name, and skip the asset it doesn't name?
  static func desiredKeys() async throws {
    let database = container.privateCloudDatabase
    _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
    let file = FileManager.default.temporaryDirectory.appending(path: "keys-asset")
    try Data(repeating: 1, count: 200_000).write(to: file)
    let record = CKRecord(recordType: "ProtoMedia", recordID: CKRecord.ID(recordName: "keys-test", zoneID: zoneID))
    record.encryptedValues["secret"] = "hidden text"
    record["plain"] = 7
    record["payload"] = CKAsset(fileURL: file)
    _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: nil, desiredKeys: ["secret", "plain"])
    for (_, result) in changes.modificationResultsByID {
      let fetched = try result.get().record
      say("""
        KEYS \(fetched.recordID.recordName): secret=\(fetched.encryptedValues["secret"] as? String ?? "nil") \
        plain=\(fetched["plain"] as? Int ?? -1) payload=\((fetched["payload"] as? CKAsset)?.fileURL?.path ?? "nil") \
        allKeys=\(fetched.allKeys())
        """)
    }
    let full = try await database.record(for: record.recordID)
    say("FULL payload=\((full["payload"] as? CKAsset)?.fileURL != nil)")
    let onlyAsset = try await database.records(for: [record.recordID], desiredKeys: ["payload"])
    if let fetched = try onlyAsset[record.recordID]?.get() {
      say("ASSET-ONLY payload=\((fetched["payload"] as? CKAsset)?.fileURL != nil) secret=\(fetched.encryptedValues["secret"] as? String ?? "nil")")
    }
    _ = try await database.modifyRecordZones(saving: [], deleting: [zoneID])
    say("deleted zone \(zoneID.zoneName)")
  }

  static func cleanup() async throws {
    _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
    say("deleted zone \(zoneID.zoneName)")
  }
}

// MARK: - Files on the pasteboard

enum PasteTest {
  /// What a clipboard manager sees after another app copied a file: first the raw pasteboard data (as Maccy reads
  /// it), then through NSURL (which may carry a sandbox extension), each followed by an attempt to read the file.
  static func read() {
    let pasteboard = NSPasteboard.general
    say("types: \(pasteboard.types?.map(\.rawValue) ?? [])")

    if let data = pasteboard.data(forType: .fileURL), let url = URL(dataRepresentation: data, relativeTo: nil) {
      attempt(url, via: "raw data")
    } else {
      say("no public.file-url data")
    }
    let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    for url in urls {
      attempt(url, via: "NSURL")
    }
  }

  static func attempt(_ url: URL, via route: String) {
    do {
      let data = try Data(contentsOf: url)
      say("READ \(route) OK: \(url.path), \(data.count) bytes, sha \(hex(data).prefix(12))")
    } catch {
      say("READ \(route) FAILED: \(url.path): \((error as NSError).domain) \((error as NSError).code) \(error.localizedDescription)")
    }
  }

  /// Saves a small PDF as a received file would be saved, and copies it the way Pastronaut would paste it.
  static func write(to location: String) throws {
    let directory: URL
    if location == "downloads" {
      // With com.apple.security.files.downloads.read-write the container's Downloads is the real one.
      directory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        .appending(path: "Pastronaut Prototype")
    } else {
      directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "Received")
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appending(path: "pastronaut-received-test.pdf")
    try samplePDF().write(to: file)

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([file as NSURL])
    say("WROTE \(file.path) (\(hex(try Data(contentsOf: file)).prefix(12))) and copied it")
  }

  static func samplePDF() -> Data {
    let data = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 595, height: 842)
    let consumer = CGDataConsumer(data: data)!
    let context = CGContext(consumer: consumer, mediaBox: &box, nil)!
    context.beginPDFPage(nil)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    ("Pastronaut prototype: received file" as NSString)
      .draw(at: CGPoint(x: 72, y: 760), withAttributes: [.font: NSFont.systemFont(ofSize: 18)])
    NSGraphicsContext.current = nil
    context.endPDFPage()
    context.closePDF()
    return data as Data
  }
}
