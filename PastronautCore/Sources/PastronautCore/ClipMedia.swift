import CryptoKit
import Foundation

/// What an image, PDF or file clip holds, apart from the bytes themselves (those are in a `MediaStore` and, as
/// encrypted assets, in iCloud). Since 1.3.
public struct ClipMedia: Codable, Equatable, Hashable, Sendable {
  public struct File: Codable, Equatable, Hashable, Sendable {
    /// Shown, and used when the clip is pasted or shared as a file ("Screenshot.heic", "Invoice.pdf").
    public var name: String
    /// Uniform type identifier of the bytes as stored ("public.heic", "com.adobe.pdf").
    public var type: String
    public var byteCount: Int
    /// SHA-256 of the bytes as stored, in hex; checks what arrives from iCloud.
    public var sha256: String

    public init(name: String, type: String, byteCount: Int, sha256: String) {
      self.name = name
      self.type = type
      self.byteCount = byteCount
      self.sha256 = sha256
    }

    public init(name: String, type: String, data: Data) {
      self.init(name: name, type: type, byteCount: data.count, sha256: ClipMedia.sha256(data))
    }
  }

  /// `.image`, `.pdf` or `.file`.
  public var kind: Clip.Kind
  /// One for an image or a PDF; a copy of several files in Finder keeps them together, as one clip.
  public var files: [File]
  public var pixelWidth: Int?
  public var pixelHeight: Int?
  /// Text read from the image (OCR) or the PDF: searched, and checked by the privacy filters. Never shown as the
  /// clip's own text.
  public var recognizedText: String?

  public init(
    kind: Clip.Kind,
    files: [File],
    pixelWidth: Int? = nil,
    pixelHeight: Int? = nil,
    recognizedText: String? = nil
  ) {
    self.kind = kind
    self.files = files
    self.pixelWidth = pixelWidth
    self.pixelHeight = pixelHeight
    self.recognizedText = Self.cleanRecognizedText(recognizedText)
  }

  /// Empty text is none; long text is cut where the iCloud record would cut it.
  static func cleanRecognizedText(_ text: String?) -> String? {
    guard let text, !text.isEmpty else { return nil }
    return text.count > MediaRecord.maxRecognizedTextLength ? String(text.prefix(MediaRecord.maxRecognizedTextLength)) : text
  }

  public var totalBytes: Int { files.reduce(0) { $0 + $1.byteCount } }

  /// The clip ID for copied content, from the SHA-256 of each part as it was copied (before conversion). Media
  /// IDs start with "media-", text IDs with "clip-".
  public static func clipID(for contentHashes: [String]) -> String {
    "media-" + sha256(Data(contentHashes.joined(separator: "\n").utf8))
  }

  public static func isMediaID(_ id: String) -> Bool {
    id.hasPrefix("media-")
  }

  public static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}

// MARK: - Settings

/// Settings › Images & Files that every device shares (one iCloud budget, one switch). Image quality is each
/// device's own (`MediaQuality`).
public struct MediaSettings: Codable, Equatable, Sendable {
  /// Off: no device sends new images or files. What is in iCloud stays.
  public var syncEnabled: Bool
  /// Larger clips (all files together) stay on the device that copied them.
  public var maxItemBytes: Int
  /// Every device downloads every image and file, so this is also the most each device stores for them.
  public var cloudBudgetBytes: Int

  public init(syncEnabled: Bool = true, maxItemBytes: Int = 10 * Self.megabyte, cloudBudgetBytes: Int = Self.gigabyte) {
    self.syncEnabled = syncEnabled
    self.maxItemBytes = maxItemBytes
    self.cloudBudgetBytes = cloudBudgetBytes
  }

  public static let megabyte = 1_000_000
  public static let gigabyte = 1_000_000_000
  public static let maxItemChoices = [5, 10, 25, 50].map { $0 * megabyte }
  /// No "unlimited": every device downloads all of it.
  public static let cloudBudgetChoices = [500 * megabyte, gigabyte, 2 * gigabyte, 5 * gigabyte]
}

/// How a device sends the images it copies. Each device's own choice.
public enum MediaQuality: String, Codable, Sendable, CaseIterable {
  /// HEIC, at most 4096 pixels on the long edge; the original when that is smaller.
  case optimized
  case original

  public static let maxLongEdge = 4096
}

/// Settings every device shares, kept in the account's settings record next to the record-name key. Merged as a
/// whole by `modifiedAt`: the newest change wins.
public struct SharedSyncSettings: Codable, Equatable, Sendable {
  public var skipOneTimeCodes: Bool
  public var skipCardNumbers: Bool
  public var pinnedOnly: Bool
  public var media: MediaSettings
  /// Nil until someone changed a setting; then a device's defaults never replace it.
  public var modifiedAt: Date?

  public init(privacy: PrivacyOptions = PrivacyOptions(), media: MediaSettings = MediaSettings(), modifiedAt: Date? = nil) {
    self.skipOneTimeCodes = privacy.skipOneTimeCodes
    self.skipCardNumbers = privacy.skipCardNumbers
    self.pinnedOnly = privacy.pinnedOnly
    self.media = media
    self.modifiedAt = modifiedAt
  }

  public var privacy: PrivacyOptions {
    get { PrivacyOptions(skipOneTimeCodes: skipOneTimeCodes, skipCardNumbers: skipCardNumbers, pinnedOnly: pinnedOnly) }
    set {
      skipOneTimeCodes = newValue.skipOneTimeCodes
      skipCardNumbers = newValue.skipCardNumbers
      pinnedOnly = newValue.pinnedOnly
    }
  }

  /// The newer of two versions; a version nobody changed loses to one somebody did.
  public func merged(with other: SharedSyncSettings) -> SharedSyncSettings {
    (other.modifiedAt ?? .distantPast) > (modifiedAt ?? .distantPast) ? other : self
  }
}

/// A Mac app's icon, sent once per app so other devices can show where a clip came from. Since 1.3.
public struct AppIcon: Codable, Equatable, Sendable {
  public var bundleIdentifier: String
  public var name: String?
  /// A small PNG.
  public var png: Data
  public var modifiedAt: Date

  public init(bundleIdentifier: String, name: String?, png: Data, modifiedAt: Date = .now) {
    self.bundleIdentifier = bundleIdentifier
    self.name = name
    self.png = png
    self.modifiedAt = modifiedAt
  }

  /// Pixels on each side of the PNG.
  public static let side = 96
  /// Larger icons are not sent.
  public static let maxBytes = 40_000
}

// MARK: - Decoding what later versions write

// These travel as JSON in encrypted fields, so a later version can add fields without a schema change. Missing
// fields take their defaults, so a version that knows a field reads what an older one wrote.

extension ClipMedia {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    kind = (try? container.decode(Clip.Kind.self, forKey: .kind)) ?? .file
    files = try container.decode([File].self, forKey: .files)
    pixelWidth = try container.decodeIfPresent(Int.self, forKey: .pixelWidth)
    pixelHeight = try container.decodeIfPresent(Int.self, forKey: .pixelHeight)
    recognizedText = try container.decodeIfPresent(String.self, forKey: .recognizedText)
  }
}

extension MediaSettings {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = MediaSettings()
    syncEnabled = try container.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? defaults.syncEnabled
    maxItemBytes = try container.decodeIfPresent(Int.self, forKey: .maxItemBytes) ?? defaults.maxItemBytes
    cloudBudgetBytes = try container.decodeIfPresent(Int.self, forKey: .cloudBudgetBytes) ?? defaults.cloudBudgetBytes
  }
}

extension SharedSyncSettings {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    skipOneTimeCodes = try container.decodeIfPresent(Bool.self, forKey: .skipOneTimeCodes) ?? false
    skipCardNumbers = try container.decodeIfPresent(Bool.self, forKey: .skipCardNumbers) ?? false
    pinnedOnly = try container.decodeIfPresent(Bool.self, forKey: .pinnedOnly) ?? false
    media = try container.decodeIfPresent(MediaSettings.self, forKey: .media) ?? MediaSettings()
    modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt)
  }
}
