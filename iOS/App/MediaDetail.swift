import Photos
import PastronautCore
import QuickLook
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

// The detail of an image, a PDF or files (1.3): the picture with Live Text, the text read from it, and Copy, Share,
// Save and Markup. Opened from a card's menu ("Show Details"), like a text clip's detail.

struct MediaDetailSection: View {
  @Environment(ClipStore.self) private var store
  let clip: Clip
  let onCopy: () -> Void
  @State private var previewURL: URL?
  @State private var exporting: [URL] = []
  @State private var isExporting = false
  @State private var savedToPhotos: Bool?

  private var urls: [URL] { MediaFiles.fileURLs(for: clip) }
  private var hasFiles: Bool { MediaFiles.hasFiles(for: clip) }

  var body: some View {
    VStack(spacing: 16) {
      picture
      if let text = clip.media?.recognizedText {
        recognizedText(text)
      }
      actions
    }
    .sheet(item: Binding(get: { previewURL.map(PreviewItem.init) }, set: { previewURL = $0?.url })) { item in
      QuickLookSheet(url: item.url) { edited in
        Task { await store.saveEdited(edited, from: clip) }
      }
      .ignoresSafeArea()
    }
    .fileExporter(isPresented: $isExporting, items: exporting) { _ in }
    .alert(Text("Saved to Photos"), isPresented: Binding(get: { savedToPhotos == true }, set: { if !$0 { savedToPhotos = nil } })) {
      Button("OK", role: .cancel) {}
    }
    .alert(Text("Couldn't save to Photos"), isPresented: Binding(get: { savedToPhotos == false }, set: { if !$0 { savedToPhotos = nil } })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Allow Pastronaut to add photos in Settings › Privacy & Security › Photos.")
    }
  }

  // MARK: - Parts

  @ViewBuilder
  private var picture: some View {
    let content = clip.content
    ZStack(alignment: .bottomTrailing) {
      Group {
        if content == .image, hasFiles, let url = urls.first {
          LiveTextImage(url: url)
            .frame(maxWidth: .infinity)
            .frame(height: 330)
        } else {
          MediaTileContent(clip: clip, isDownloading: !hasFiles)
            .frame(maxWidth: .infinity)
            .frame(height: content == .file ? 180 : 330)
        }
      }
      .background(content.kind.strip)
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      if hasFiles {
        Button {
          previewURL = urls.first
        } label: {
          Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.footnote.weight(.bold))
            .frame(width: 40, height: 40)
            .glassBackground(in: Circle())
        }
        .buttonStyle(.plain)
        .padding(12)
        .accessibilityLabel(Text("Open"))
        .accessibilityIdentifier("openMedia")
      }
    }
  }

  private func recognizedText(_ text: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(clip.content == .pdf ? "Text in the PDF" : "Text in the Image")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        Spacer()
        Button("Copy Text") {
          store.copyText(text)
          onCopy()
        }
        .font(.subheadline.weight(.semibold))
        .accessibilityIdentifier("copyRecognizedText")
      }
      Text(verbatim: text)
        .font(.subheadline)
        .lineLimit(6)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private var actions: some View {
    VStack(spacing: 10) {
      Button(action: onCopy) {
        Label("Copy", systemImage: "doc.on.doc")
          .frame(maxWidth: .infinity)
      }
      .controlSize(.large)
      .primaryActionStyle()
      .disabled(!hasFiles)
      .accessibilityIdentifier("copyButton")
      HStack(spacing: 10) {
        ShareLink(items: urls) {
          MediaActionTile(title: "Share", systemImage: "square.and.arrow.up")
        }
        .secondaryActionStyle()
        .disabled(!hasFiles)
        Button(action: save) {
          MediaActionTile(
            title: clip.content == .image ? "Save to Photos" : "Save to Files",
            systemImage: clip.content == .image ? "square.and.arrow.down" : "folder"
          )
        }
        .secondaryActionStyle()
        .disabled(!hasFiles)
        if clip.content != .file {
          Button {
            previewURL = urls.first
          } label: {
            MediaActionTile(title: "Markup", systemImage: "pencil.tip.crop.circle")
          }
          .secondaryActionStyle()
          .disabled(!hasFiles)
        }
      }
    }
  }

  private func save() {
    if clip.content == .image, let url = urls.first {
      Task {
        savedToPhotos = await PhotoSaver.save(url)
      }
    } else {
      exporting = urls
      isExporting = true
    }
  }
}

private struct PreviewItem: Identifiable {
  let url: URL
  var id: URL { url }
}

private struct MediaActionTile: View {
  let title: LocalizedStringKey
  let systemImage: String

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.title3)
      Text(title)
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, minHeight: 52)
  }
}

/// Adds an image to Photos; asks for add-only access the first time.
enum PhotoSaver {
  static func save(_ url: URL) async -> Bool {
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else { return false }
    do {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url)
      }
      return true
    } catch {
      return false
    }
  }
}

// MARK: - Live Text

/// The image, fitted, with Live Text: text in it can be selected, copied and looked up, read on this iPhone.
struct LiveTextImage: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> UIImageView {
    let view = UIImageView(image: UIImage(contentsOfFile: url.path))
    view.contentMode = .scaleAspectFit
    view.isUserInteractionEnabled = true
    view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    view.accessibilityIgnoresInvertColors = true
    if ImageAnalyzer.isSupported {
      let interaction = ImageAnalysisInteraction()
      interaction.preferredInteractionTypes = .automatic
      view.addInteraction(interaction)
      context.coordinator.interaction = interaction
      if let image = view.image {
        context.coordinator.analyze(image)
      }
    }
    return view
  }

  func updateUIView(_ view: UIImageView, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator() }

  @MainActor
  final class Coordinator {
    var interaction: ImageAnalysisInteraction?
    private var task: Task<Void, Never>?

    func analyze(_ image: UIImage) {
      task = Task { [weak self] in
        let analyzer = ImageAnalyzer()
        let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])
        let analysis = try? await analyzer.analyze(image, configuration: configuration)
        self?.interaction?.analysis = analysis
      }
    }
  }
}

// MARK: - Quick Look with Markup

/// Full-screen preview with zoom and page swiping; Markup saves an edited copy, which becomes a new clip.
struct QuickLookSheet: UIViewControllerRepresentable {
  let url: URL
  let onEditedCopy: (URL) -> Void

  func makeUIViewController(context: Context) -> UINavigationController {
    let controller = QLPreviewController()
    controller.dataSource = context.coordinator
    controller.delegate = context.coordinator
    return UINavigationController(rootViewController: controller)
  }

  func updateUIViewController(_ controller: UINavigationController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(url: url, onEditedCopy: onEditedCopy) }

  @MainActor
  final class Coordinator: NSObject, @preconcurrency QLPreviewControllerDataSource, @preconcurrency QLPreviewControllerDelegate {
    let url: URL
    let onEditedCopy: (URL) -> Void

    init(url: URL, onEditedCopy: @escaping (URL) -> Void) {
      self.url = url
      self.onEditedCopy = onEditedCopy
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
      url as NSURL
    }

    /// The stored file never changes (its ID comes from its content); Markup makes a copy.
    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
      .createCopy
    }

    func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
      onEditedCopy(modifiedContentsURL)
    }
  }
}
