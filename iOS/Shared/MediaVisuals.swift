import PastronautCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// Images, PDFs and files (1.3), shared by the app, the keyboard and the widgets (all compile this file). The bytes
// live in the App Group (`MediaStore`, next to the sync state); the keyboard reads thumbnails only.

/// This device's copies of media and app icons.
enum MediaFiles {
  static let storageDirectory: URL? = SharedClipFiles()?.directory
  static let store: MediaStore? = storageDirectory.map { MediaStore(storageDirectory: $0) }

  // NSCache is thread-safe.
  nonisolated(unsafe) private static let thumbnails: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    // The keyboard has little memory; a screen of tiles is far fewer than this.
    cache.countLimit = 80
    return cache
  }()

  nonisolated(unsafe) private static let icons: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.countLimit = 60
    return cache
  }()

  /// The small picture iCloud carries for an image or a PDF (at most 60 KB).
  static func thumbnail(for clip: Clip) -> UIImage? {
    let key = clip.id as NSString
    if let hit = thumbnails.object(forKey: key) { return hit }
    guard let data = store?.thumbnail(for: clip.id), let image = UIImage(data: data) else { return nil }
    thumbnails.setObject(image, forKey: key)
    return image
  }

  /// A Mac app's icon, sent once by the Mac.
  static func appIcon(for bundleIdentifier: String) -> UIImage? {
    let key = bundleIdentifier as NSString
    if let hit = icons.object(forKey: key) { return hit }
    guard let directory = storageDirectory,
          let image = UIImage(contentsOfFile: ClipSync.appIconURL(for: bundleIdentifier, storageDirectory: directory).path)
    else { return nil }
    icons.setObject(image, forKey: key)
    return image
  }

  static func hasFiles(for clip: Clip) -> Bool {
    store?.hasFiles(for: clip) ?? false
  }

  static func fileURLs(for clip: Clip) -> [URL] {
    store?.fileURLs(for: clip) ?? []
  }

  /// "2.4 MB"
  static func size(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    // "0 KB", not "Zero KB".
    formatter.allowsNonnumericFormatting = false
    return formatter.string(fromByteCount: Int64(bytes))
  }
}

/// Puts an image, a PDF or files on the clipboard.
enum MediaPasteboard {
  /// False when the clip's files aren't on this device yet.
  @MainActor
  @discardableResult
  static func copy(_ clip: Clip) -> Bool {
    guard let media = clip.media, MediaFiles.hasFiles(for: clip) else { return false }
    let urls = MediaFiles.fileURLs(for: clip)
    let pasteboard = UIPasteboard.general
    switch media.kind {
    case .image:
      // As an image, which every app can paste; the system offers PNG and JPEG for it.
      guard let url = urls.first, let image = UIImage(contentsOfFile: url.path) else { return false }
      pasteboard.image = image
    case .pdf:
      guard let url = urls.first, let data = try? Data(contentsOf: url) else { return false }
      pasteboard.setData(data, forPasteboardType: UTType.pdf.identifier)
    default:
      pasteboard.itemProviders = urls.compactMap { url in
        let provider = NSItemProvider(contentsOf: url)
        provider?.suggestedName = url.lastPathComponent
        return provider
      }
    }
    return true
  }
}

extension Clip {
  /// What a media clip says without a title: the first line of the text read from it, or its file names.
  var mediaCaption: String? {
    guard let media else { return nil }
    if let line = media.recognizedText?.split(whereSeparator: \.isNewline).first {
      return String(line.prefix(Clip.maxTitleLength))
    }
    return media.files.map(\.name).joined(separator: ", ")
  }

  /// "PDF · 240 KB", "3 files · 8.1 MB", "1,240 × 2,688 · 640 KB"
  var mediaSummary: String? {
    guard let media else { return nil }
    let size = MediaFiles.size(media.totalBytes)
    if media.kind == .image, let width = media.pixelWidth, let height = media.pixelHeight {
      return "\(width.formatted()) × \(height.formatted()) · \(size)"
    }
    if media.files.count > 1 {
      return "\(media.files.count) · \(size)"
    }
    return size
  }
}

// MARK: - The kind strip

enum KindStripTone { case plain, onDark, onLight }

/// The band along the bottom of a card or keyboard tile: the kind's symbol and name in its color, on a faint band of
/// that color, then how long ago it was copied and whatever `trailing` adds (pin, source).
struct KindStrip<Trailing: View>: View {
  let content: ClipContent
  let date: Date
  var height: CGFloat = 30
  /// On a dark card (code) or a colored one (a color clip): the band and its text follow the card.
  var tone: KindStripTone = .plain
  @ViewBuilder var trailing: () -> Trailing

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: content.symbolName)
        .foregroundStyle(labelColor)
      Text(content.kindName)
        .fontWeight(.bold)
        .foregroundStyle(labelColor)
      Text(verbatim: "·")
      AgeText(date: date)
      Spacer(minLength: 0)
      trailing()
    }
    .font(.caption)
    .lineLimit(1)
    .foregroundStyle(timeColor)
    .padding(.horizontal, 11)
    .frame(height: height)
    .frame(maxWidth: .infinity)
    .background(band)
  }

  private var labelColor: Color {
    switch tone {
    case .plain: content.kind.tint
    case .onDark: content.kind == .code ? Color(red: 0.79, green: 0.71, blue: 1) : .white
    case .onLight: .black
    }
  }

  private var timeColor: AnyShapeStyle {
    switch tone {
    case .plain: AnyShapeStyle(.secondary)
    case .onDark: AnyShapeStyle(.white.opacity(0.8))
    case .onLight: AnyShapeStyle(.black.opacity(0.7))
    }
  }

  private var band: AnyShapeStyle {
    switch tone {
    case .plain: AnyShapeStyle(content.kind.strip)
    case .onDark: AnyShapeStyle(.white.opacity(0.1))
    case .onLight: AnyShapeStyle(.black.opacity(0.08))
    }
  }
}

// MARK: - Media in a tile

/// The top of a card or keyboard tile for an image, a PDF or files: the picture edge to edge, the first page, or
/// the files' icons and names.
struct MediaTileContent: View {
  let clip: Clip
  /// Keyboard tiles are small: a PDF shows only its page, files only their icon.
  var isCompact = false
  /// The files are on their way (see `ClipSync.pendingFileIDs`).
  var isDownloading = false

  var body: some View {
    let content = clip.content
    ZStack {
      switch content {
      case .image:
        if let image = MediaFiles.thumbnail(for: clip) {
          // The picture fills the space it is given and never asks for more (a tall photo would push the strip out).
          Color.clear
            .overlay {
              Image(uiImage: image)
                .resizable()
                .scaledToFill()
            }
            .clipped()
        } else {
          placeholder(content)
        }
      case .pdf:
        ZStack {
          content.kind.strip
          if let page = MediaFiles.thumbnail(for: clip) {
            Image(uiImage: page)
              .resizable()
              .scaledToFit()
              .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
              .padding(.top, isCompact ? 6 : 12)
              .padding(.horizontal, isCompact ? 8 : 24)
              .frame(maxHeight: .infinity, alignment: .top)
          } else {
            placeholder(content)
          }
        }
      default:
        files
      }
      if isDownloading {
        ProgressView()
          .padding(8)
          .background(.ultraThinMaterial, in: Circle())
          .accessibilityLabel(Text("Downloading"))
      }
    }
    .accessibilityHidden(true)
  }

  private func placeholder(_ content: ClipContent) -> some View {
    ZStack {
      content.kind.strip
      Image(systemName: content.symbolName)
        .font(isCompact ? .title3 : .largeTitle)
        .foregroundStyle(content.kind.tint)
    }
  }

  @ViewBuilder
  private var files: some View {
    let names = clip.media?.files.map(\.name) ?? []
    if isCompact || names.count == 1 {
      VStack(spacing: 5) {
        FileIcon(name: names.first ?? "", size: isCompact ? 30 : 44)
        if !isCompact {
          Text(verbatim: names.first ?? "")
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
          if let summary = clip.mediaSummary {
            Text(verbatim: summary)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      VStack(alignment: .leading, spacing: 6) {
        ForEach(Array(names.prefix(3).enumerated()), id: \.offset) { index, name in
          HStack(spacing: 8) {
            if index == 2 && names.count > 3 {
              FileIcon(name: "", size: 24, label: "+\(names.count - 2)")
              Text("\(names.count - 2) more files")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            } else {
              FileIcon(name: name, size: 24)
              Text(verbatim: name)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
            }
          }
        }
      }
      .padding(.horizontal, 12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}

/// A document shape with the file's extension on it, in a color of its kind.
struct FileIcon: View {
  let name: String
  var size: CGFloat = 44
  /// Shown instead of the extension ("+2").
  var label: String?

  var body: some View {
    let ext = label ?? String((name as NSString).pathExtension.uppercased().prefix(4))
    RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
      .fill(color)
      .frame(width: size * 0.8, height: size)
      .overlay(alignment: .bottom) {
        Text(verbatim: ext)
          .font(.system(size: size * 0.2, weight: .heavy))
          .foregroundStyle(.white)
          .padding(.bottom, size * 0.12)
          .minimumScaleFactor(0.6)
      }
      .accessibilityHidden(true)
  }

  private var color: Color {
    let type = UTType(filenameExtension: (name as NSString).pathExtension)
    if type?.conforms(to: .pdf) == true { return ClipKind.pdf.tint }
    if type?.conforms(to: .image) == true { return ClipKind.image.tint }
    if type?.conforms(to: .spreadsheet) == true { return ClipKind.phone.tint }
    if type?.conforms(to: .presentation) == true { return ClipKind.link.tint }
    if label != nil { return Color.secondary }
    return ClipKind.file.tint
  }
}
