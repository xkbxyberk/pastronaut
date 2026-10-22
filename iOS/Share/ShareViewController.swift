import PastronautCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WidgetKit

/// Share › Pastronaut: saves shared text or a link straight to iCloud (the Mac gets it without the app being
/// opened). Nothing is read from the clipboard, so several things in a row can be saved this way.
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
      try? await Task.sleep(for: .seconds(model.state == .saved ? 0.9 : 2.2))
      extensionContext?.completeRequest(returningItems: nil)
    }
  }
}

@MainActor
@Observable
final class ShareModel {
  enum State { case saving, saved, savedOffline, nothing, tooLarge, unavailable }

  /// How long the sheet waits for iCloud. The inbox already has the clips, so after this the app sends them.
  static let uploadWait: Duration = .seconds(8)
  /// More than this in one share is not what Pastronaut is for.
  static let maxItems = 20

  private(set) var state = State.saving
  private(set) var preview = ""

  func save(from items: [NSExtensionItem]) async {
    let texts = await Self.texts(in: items).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    guard !texts.isEmpty else {
      state = .nothing
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
    let clips = eligible.map { Clip(text: $0, sourceDevice: .iphone) }
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
    case .tooLarge, .unavailable: "exclamationmark.triangle.fill"
    }
  }

  private var tint: Color {
    switch model.state {
    case .saving: .secondary
    case .saved, .savedOffline: .green
    case .nothing, .tooLarge, .unavailable: .orange
    }
  }

  private var title: LocalizedStringKey {
    switch model.state {
    case .saving: "Saving…"
    case .saved, .savedOffline: "Saved to Pastronaut"
    case .nothing: "Nothing to save"
    case .tooLarge: "Too large to sync"
    case .unavailable: "Couldn't save"
    }
  }

  private var detail: LocalizedStringKey? {
    switch model.state {
    case .savedOffline: "It reaches your Mac the next time Pastronaut opens."
    case .nothing: "Pastronaut saves text and links."
    case .tooLarge: "Clips up to 100 KB are synced."
    case .unavailable: "Open Pastronaut once, then share again."
    case .saving, .saved: nil
    }
  }
}
