import Foundation

/// Keeps a folder of per-clip cache files (`<clip ID>.<ext>`, e.g. the iPhone's link and map previews) in check:
/// files of clips no longer in the history go, then the least recently written ones until the folder fits.
public enum CachePruner {
  /// Returns how many bytes were removed. Files that don't start with a clip ID are left alone.
  @discardableResult
  public static func prune(_ directory: URL, keeping clipIDs: Set<String>, maxBytes: Int) -> Int {
    let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
    guard let urls = try? FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
    ) else { return 0 }

    struct File {
      var url: URL
      var id: String
      var size: Int
      var date: Date
    }
    let files: [File] = urls.compactMap { url in
      let id = url.deletingPathExtension().lastPathComponent
      guard id.hasPrefix("clip-"), let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
      return File(url: url, id: id, size: values.fileSize ?? 0, date: values.contentModificationDate ?? .distantPast)
    }

    var removed = 0
    func remove(_ file: File) {
      if (try? FileManager.default.removeItem(at: file.url)) != nil { removed += file.size }
    }
    let (kept, gone) = (files.filter { clipIDs.contains($0.id) }, files.filter { !clipIDs.contains($0.id) })
    gone.forEach(remove)

    // A clip's files go together (the JSON without its picture would claim an image), oldest clip first.
    var total = kept.reduce(0) { $0 + $1.size }
    let byClip = Dictionary(grouping: kept, by: \.id)
      .sorted { ($0.value.map(\.date).max() ?? .distantPast) < ($1.value.map(\.date).max() ?? .distantPast) }
    for (_, clipFiles) in byClip where total > maxBytes {
      clipFiles.forEach(remove)
      total -= clipFiles.reduce(0) { $0 + $1.size }
    }
    return removed
  }
}
