import Foundation

/// The bytes of media clips on this device, decrypted, one folder per clip:
///
///     <directory>/<clip ID>/thumbnail.jpg
///     <directory>/<clip ID>/files/<index>/<file name>
///
/// Each file keeps its own name, so pasting or sharing it gives the name it was copied with. The iPhone keeps the
/// directory in the App Group, where the keyboard reads thumbnails (never the files). `outgoing` holds encrypted
/// copies waiting to be uploaded.
public struct MediaStore: Sendable {
  public let directory: URL

  public init(directory: URL) {
    self.directory = directory
  }

  /// Next to the sync state (`ClipSync`'s storage directory).
  public init(storageDirectory: URL) {
    self.init(directory: storageDirectory.appending(path: "media"))
  }

  var outgoing: URL { directory.appending(path: "outgoing") }

  private func folder(for clipID: String) -> URL {
    directory.appending(path: clipID)
  }

  public func thumbnailURL(for clipID: String) -> URL {
    folder(for: clipID).appending(path: "thumbnail.jpg")
  }

  public func thumbnail(for clipID: String) -> Data? {
    try? Data(contentsOf: thumbnailURL(for: clipID))
  }

  /// Where each file of `clip` is (or would be) on this device, in order.
  public func fileURLs(for clip: Clip) -> [URL] {
    guard let media = clip.media else { return [] }
    return media.files.enumerated().map { index, file in
      folder(for: clip.id).appending(path: "files/\(index)").appending(path: Self.safeName(file.name, index: index))
    }
  }

  /// Every file is here with the expected size. Checking the hash on each launch would cost too much; it is
  /// checked when a file arrives.
  public func hasFiles(for clip: Clip) -> Bool {
    guard let media = clip.media else { return false }
    return zip(fileURLs(for: clip), media.files).allSatisfy { url, file in
      (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) == file.byteCount
    }
  }

  /// Stores the files of a clip copied here. `files` follow `clip.media.files`.
  public func store(_ files: [Data], for clip: Clip) throws {
    guard let media = clip.media, files.count == media.files.count else { throw CocoaError(.fileWriteUnknown) }
    for (url, data) in zip(fileURLs(for: clip), files) {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
  }

  public func storeThumbnail(_ data: Data, for clipID: String) throws {
    let url = thumbnailURL(for: clipID)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }

  /// Decrypts files downloaded from iCloud and keeps them if each matches its hash. False when one doesn't open
  /// or doesn't match; nothing is kept then.
  public func storeDownloaded(_ encrypted: [URL], for clip: Clip, cipher: MediaCipher) -> Bool {
    guard let media = clip.media, encrypted.count == media.files.count else { return false }
    var files: [Data] = []
    for (url, file) in zip(encrypted, media.files) {
      guard let sealed = try? Data(contentsOf: url),
            let data = try? cipher.open(sealed, clipID: clip.id),
            ClipMedia.sha256(data) == file.sha256 else {
        return false
      }
      files.append(data)
    }
    return (try? store(files, for: clip)) != nil
  }

  /// Encrypted copies of a clip's files for upload, in `outgoing`; nil when a file is missing here.
  func encryptedCopies(of clip: Clip, recordName: String, cipher: MediaCipher) -> [URL]? {
    guard hasFiles(for: clip) else { return nil }
    do {
      try FileManager.default.createDirectory(at: outgoing, withIntermediateDirectories: true)
      return try fileURLs(for: clip).enumerated().map { index, url in
        let target = outgoing.appending(path: "\(recordName)-\(index)")
        try cipher.seal(Data(contentsOf: url), clipID: clip.id).write(to: target, options: .atomic)
        return target
      }
    } catch {
      return nil
    }
  }

  /// Drops the encrypted copies of a record once it was saved (or will never be).
  func removeEncryptedCopies(recordName: String) {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: outgoing.path)) ?? []
    for name in names where name.hasPrefix(recordName + "-") {
      try? FileManager.default.removeItem(at: outgoing.appending(path: name))
    }
  }

  public func remove(clipID: String) {
    try? FileManager.default.removeItem(at: folder(for: clipID))
  }

  /// Removes the folders of clips not in `clipIDs`, and encrypted copies older than a day. Returns how many clip
  /// folders went. A folder written in the last hour stays: an extension may have just saved it for the app.
  @discardableResult
  public func prune(keeping clipIDs: Set<String>, now: Date = .now) -> Int {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    let recent = now.addingTimeInterval(-3_600)
    var removed = 0
    for name in names where ClipMedia.isMediaID(name) && !clipIDs.contains(name) {
      let url = directory.appending(path: name)
      let date = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
      guard date < recent else { continue }
      remove(clipID: name)
      removed += 1
    }
    let stale = now.addingTimeInterval(-86_400)
    for name in (try? FileManager.default.contentsOfDirectory(atPath: outgoing.path)) ?? [] {
      let url = outgoing.appending(path: name)
      let date = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? now
      if date < stale { try? FileManager.default.removeItem(at: url) }
    }
    return removed
  }

  /// Bytes of every clip's files and thumbnail here.
  public var totalBytes: Int {
    guard let enumerator = FileManager.default.enumerator(
      at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
    ) else { return 0 }
    var total = 0
    for case let url as URL in enumerator {
      let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
      if values?.isRegularFile == true { total += values?.fileSize ?? 0 }
    }
    return total
  }

  /// A file name that stays in its folder: no path separators, not empty, not "." or "..".
  static func safeName(_ name: String, index: Int) -> String {
    let cleaned = name
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: ":", with: "-")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.isEmpty || cleaned == "." || cleaned == ".." || cleaned.hasPrefix("..") {
      return "file-\(index + 1)"
    }
    return String(cleaned.prefix(200))
  }
}
