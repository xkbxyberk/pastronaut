import PastronautCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WidgetKit

/// Share › Pastronaut, and the "Save to Pastronaut" action (the same code in the action extension): saves shared
/// text or links straight to iCloud (the Mac gets them without the app being opened). Nothing is read from the
/// clipboard, so several things in a row can be saved this way.
final class ShareViewController: UIViewController {
  private let model = ShareModel()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    let host = UIHostingController(rootView: ShareView(model: model))
    host.view.backgroundColor = .clear
    host.sizingOptions = .preferredContentSize
    addChild(host)
    view.addSubview(host.view)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      host.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      host.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      host.view.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -48)
    ])
    host.didMove(toParent: self)

    Task {
      await model.save(from: extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      if model.offersCollections {
        // Saved already; a few seconds to put it in a collection, or it closes by itself.
        for _ in 0..<40 where !model.isFinished {
          try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .seconds(model.isFinished ? 0.9 : 0))
      } else {
        try? await Task.sleep(for: .seconds(model.state == .saved ? 0.9 : 2.2))
      }
      extensionContext?.completeRequest(returningItems: nil)
    }
  }
}

@MainActor
@Observable
final class ShareModel {
  enum State { case saving, saved, savedOffline, nothing, tooLarge, tooLargeFile, unavailable }

  /// A shared photo, PDF or file larger than this is not saved: an extension has little memory to read it in.
  static let maxFileBytes = 50 * MediaSettings.megabyte

  /// How long the sheet waits for iCloud. The inbox already has the clips, so after this the app sends them.
  static let uploadWait: Duration = .seconds(8)
  /// More than this in one share is not what Pastronaut is for.
  static let maxItems = 20

  private(set) var state = State.saving
  private(set) var preview = ""
  /// Collections to offer once saved (from the app's list in the App Group).
  private(set) var collections: [ClipCollection] = []
  /// Where the clips went, once one was chosen.
  private(set) var chosenCollection: String?
  private(set) var isFinished = false
  @ObservationIgnored private var saved: [Clip] = []
  /// Saved images and files wait in the inbox for the app, which sends them (they are too large to send from here
  /// in the time a share sheet stays open).
  @ObservationIgnored private var savedMedia: [Clip] = []
  @ObservationIgnored private var files: SharedClipFiles?
  @ObservationIgnored private var cloud: KeyboardCloud?

  var offersCollections: Bool {
    (state == .saved || state == .savedOffline) && !collections.isEmpty
  }

  func add(to collection: ClipCollection) {
    guard !isFinished else { return }
    if !savedMedia.isEmpty {
      withAnimation(.snappy) { chosenCollection = collection.name }
      // The app adds inbox clips to the collections they carry.
      for var clip in savedMedia {
        clip.collectionIDs.append(collection.id)
        try? files?.appendToInbox(clip)
      }
      isFinished = true
      return
    }
    guard let cloud else { return }
    withAnimation(.snappy) { chosenCollection = collection.name }
    let clips = saved
    Task {
      for clip in clips {
        try? await cloud.addToCollection(clip, collectionID: collection.id)
      }
      isFinished = true
    }
  }

  func save(from items: [NSExtensionItem]) async {
    let texts = await Self.texts(in: items).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    guard !texts.isEmpty else {
      await saveMedia(from: Attachments(providers: items.flatMap { $0.attachments ?? [] }))
      return
    }
    preview = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "\n")
    let eligible = texts.filter { SyncPolicy.default.isEligible($0) }
    guard !eligible.isEmpty else {
      state = .tooLarge
      return
    }
    guard let files = SharedClipFiles() else {
      state = .unavailable
      return
    }
    let cloud = KeyboardCloud(containerIdentifier: PastronautIDs.iCloudContainer, files: files)
    self.cloud = cloud
    let clips = eligible.map { Clip(text: $0, sourceDevice: .iphone) }
    saved = clips
    collections = Array(files.currentCollections().prefix(6))
    let wait = Self.uploadWait
    let uploaded = await withTaskGroup(of: Bool?.self) { group in
      group.addTask {
        var allUploaded = true
        for clip in clips {
          let uploaded = await cloud.capture(clip, keepsInInbox: true)
          allUploaded = allUploaded && uploaded
        }
        return allUploaded
      }
      group.addTask {
        try? await Task.sleep(for: wait)
        return nil
      }
      // nil: still uploading when the wait ran out.
      let first = await group.next() ?? nil
      group.cancelAll()
      return first ?? false
    }
    WidgetCenter.shared.reloadAllTimelines()
    withAnimation(.snappy) { state = uploaded ? .saved : .savedOffline }
  }

  /// Photos, PDFs and other files (1.3): one clip each, kept in the App Group for the app to send.
  private func saveMedia(from attachments: Attachments) async {
    guard let files = SharedClipFiles() else {
      state = .unavailable
      return
    }
    self.files = files
    let store = MediaStore(storageDirectory: files.directory)
    let quality = MediaQuality(rawValue: SharedSettings.defaults?.string(forKey: "mediaQuality") ?? "") ?? .optimized
    let prepared = await attachments.prepare(quality: quality, maxBytes: Self.maxFileBytes, limit: Self.maxItems)
    for item in prepared.clips {
      guard (try? MediaIntake.store(item, in: store)) != nil else { continue }
      try? files.appendToInbox(item.clip)
      savedMedia.append(item.clip)
    }
    guard !savedMedia.isEmpty else {
      state = prepared.tooLarge > 0 ? .tooLargeFile : .nothing
      return
    }
    preview = savedMedia.compactMap { $0.title ?? $0.media?.files.first?.name }.prefix(3).joined(separator: ", ")
    collections = Array(files.currentCollections().prefix(6))
    withAnimation(.snappy) { state = .savedOffline }
  }

  /// Every shared link (Safari shares the page's text too, so links win), otherwise every plain text, otherwise the
  /// item's own text. File links are not text to save.
  private static func texts(in items: [NSExtensionItem]) async -> [String] {
    let providers = items.flatMap { $0.attachments ?? [] }
    var links: [String] = []
    for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
      if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL, !url.isFileURL {
        links.append(url.absoluteString)
      }
    }
    if !links.isEmpty { return Array(links.prefix(maxItems)) }
    var texts: [String] = []
    for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
      if let text = item as? String {
        texts.append(text)
      } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
        texts.append(text)
      } else if let url = item as? URL, let text = try? String(contentsOf: url, encoding: .utf8) {
        texts.append(text)
      }
    }
    if !texts.isEmpty { return Array(texts.prefix(maxItems)) }
    return items.compactMap { $0.attributedContentText?.string }.prefix(1).map { $0 }
  }
}

struct ShareView: View {
  let model: ShareModel

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: symbol)
        .font(.system(size: 34, weight: .semibold))
        .foregroundStyle(tint)
        .contentTransition(.symbolEffect(.replace))
      Text(title)
        .font(.headline)
      if !model.preview.isEmpty {
        Text(verbatim: model.preview)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(3)
          .multilineTextAlignment(.center)
      }
      if let detail {
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      if model.offersCollections {
        if let name = model.chosenCollection {
          Label {
            Text("Added to \(name)")
          } icon: {
            Image(systemName: "folder.fill")
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        } else {
          VStack(spacing: 8) {
            Text("Add to a collection")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
              HStack(spacing: 6) {
                ForEach(model.collections) { collection in
                  Button {
                    model.add(to: collection)
                  } label: {
                    Text(verbatim: collection.name)
                      .font(.subheadline.weight(.semibold))
                      .lineLimit(1)
                      .padding(.horizontal, 12)
                      .padding(.vertical, 7)
                      .foregroundStyle(collection.deepTint)
                      .background(collection.tint.opacity(0.18), in: Capsule())
                  }
                  .buttonStyle(.plain)
                  .accessibilityIdentifier("shareCollection.\(collection.name)")
                }
              }
            }
            .scrollIndicators(.hidden)
          }
          .transition(.opacity)
        }
      }
    }
    .padding(24)
    .frame(minWidth: 240)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
  }

  private var symbol: String {
    switch model.state {
    case .saving: "arrow.up.circle"
    case .saved, .savedOffline: "checkmark.circle.fill"
    case .nothing: "questionmark.circle"
    case .tooLarge, .tooLargeFile, .unavailable: "exclamationmark.triangle.fill"
    }
  }

  private var tint: Color {
    switch model.state {
    case .saving: .secondary
    case .saved, .savedOffline: .green
    case .nothing, .tooLarge, .tooLargeFile, .unavailable: .orange
    }
  }

  private var title: LocalizedStringKey {
    switch model.state {
    case .saving: "Saving…"
    case .saved, .savedOffline: "Saved to Pastronaut"
    case .nothing: "Nothing to save"
    case .tooLarge, .tooLargeFile: "Too large to sync"
    case .unavailable: "Couldn't save"
    }
  }

  private var detail: LocalizedStringKey? {
    switch model.state {
    case .savedOffline: "It reaches your Mac the next time Pastronaut opens."
    case .nothing: "Pastronaut saves text, links, images, PDFs and files."
    case .tooLarge: "Clips up to 100 KB are synced."
    case .tooLargeFile: "Images and files up to 50 MB can be saved."
    case .unavailable: "Open Pastronaut once, then share again."
    case .saving, .saved: nil
    }
  }
}

/// The share's attachments, read off the main thread (item providers aren't sendable; each is read once).
struct Attachments: @unchecked Sendable {
  let providers: [NSItemProvider]

  struct Result: Sendable {
    var clips: [MediaIntake.Prepared] = []
    var tooLarge = 0
  }

  func prepare(quality: MediaQuality, maxBytes: Int, limit: Int) async -> Result {
    var result = Result()
    for provider in providers.prefix(limit) {
      guard let part = await MediaIntake.parts(from: [provider], quality: quality, maxBytes: maxBytes).first else {
        result.tooLarge += 1
        continue
      }
      if let prepared = await MediaIntake.prepare([part], device: .iphone) {
        result.clips.append(prepared)
      }
    }
    return result
  }
}
