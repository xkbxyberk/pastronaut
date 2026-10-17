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
  enum State { case saving, saved, savedOffline, nothing, tooLarge }

  private(set) var state = State.saving
  private(set) var preview = ""

  func save(from items: [NSExtensionItem]) async {
    guard let text = await Self.text(in: items), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      state = .nothing
      return
    }
    preview = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard SyncPolicy.default.isEligible(text) else {
      state = .tooLarge
      return
    }
    guard let files = SharedClipFiles() else {
      state = .nothing
      return
    }
    let cloud = KeyboardCloud(containerIdentifier: PastronautIDs.iCloudContainer, files: files)
    let uploaded = await cloud.capture(Clip(text: text, sourceDevice: .iphone))
    WidgetCenter.shared.reloadAllTimelines()
    withAnimation(.snappy) { state = uploaded ? .saved : .savedOffline }
  }

  /// A link wins over the page's text (Safari shares both); otherwise the first plain text.
  private static func text(in items: [NSExtensionItem]) async -> String? {
    let providers = items.flatMap { $0.attachments ?? [] }
    if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }),
       let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
      return url.absoluteString
    }
    if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
      let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
      if let text = item as? String { return text }
      if let data = item as? Data { return String(data: data, encoding: .utf8) }
      if let url = item as? URL, let text = try? String(contentsOf: url, encoding: .utf8) { return text }
    }
    return items.compactMap { $0.attributedContentText?.string }.first
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
    case .tooLarge: "exclamationmark.triangle.fill"
    }
  }

  private var tint: Color {
    switch model.state {
    case .saving: .secondary
    case .saved, .savedOffline: .green
    case .nothing, .tooLarge: .orange
    }
  }

  private var title: LocalizedStringKey {
    switch model.state {
    case .saving: "Saving…"
    case .saved, .savedOffline: "Saved to Pastronaut"
    case .nothing: "Nothing to save"
    case .tooLarge: "Too large to sync"
    }
  }

  private var detail: LocalizedStringKey? {
    switch model.state {
    case .savedOffline: "It reaches your Mac the next time Pastronaut opens."
    case .nothing: "Pastronaut saves text and links."
    case .tooLarge: "Clips up to 100 KB are synced."
    case .saving, .saved: nil
    }
  }
}
