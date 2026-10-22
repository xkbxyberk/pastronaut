import PastronautCore
import SwiftUI
import UIKit
import VisionKit

// "Scan Text" and "Scan Document": text from the camera, read on this iPhone. Nothing is recorded or sent; the
// camera runs only while one of these screens is open.

/// Live text from the camera: tap a highlighted line or block and it is saved as a clip, then scan the next one.
struct TextScannerSheet: View {
  let onPick: (String) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var savedCount = 0

  static var isAvailable: Bool {
    DataScannerViewController.isSupported && DataScannerViewController.isAvailable
  }

  var body: some View {
    NavigationStack {
      TextScanner { text in
        onPick(text)
        Haptics.success()
        withAnimation(.snappy) { savedCount += 1 }
      }
      .ignoresSafeArea()
      .overlay(alignment: .bottom) {
        Label(
          savedCount == 0 ? "Tap highlighted text to save it." : "Saved \(savedCount) clips",
          systemImage: savedCount == 0 ? "hand.tap" : "checkmark"
        )
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassBackground(in: Capsule())
        .padding(.bottom, 32)
        .accessibilityIdentifier("scanHint")
      }
      .navigationTitle(AppPreferences.shared.string("Scan Text"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}

private struct TextScanner: UIViewControllerRepresentable {
  let onTap: (String) -> Void

  func makeUIViewController(context: Context) -> DataScannerViewController {
    let scanner = DataScannerViewController(
      recognizedDataTypes: [.text()],
      qualityLevel: .accurate,
      recognizesMultipleItems: true,
      isHighlightingEnabled: true
    )
    scanner.delegate = context.coordinator
    // Scanning can only start once the view is on screen.
    DispatchQueue.main.async { try? scanner.startScanning() }
    return scanner
  }

  func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

  static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
    scanner.stopScanning()
  }

  func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

  final class Coordinator: NSObject, DataScannerViewControllerDelegate {
    let onTap: (String) -> Void

    init(onTap: @escaping (String) -> Void) {
      self.onTap = onTap
    }

    func dataScanner(_ scanner: DataScannerViewController, didTapOn item: RecognizedItem) {
      if case .text(let text) = item {
        let transcript = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !transcript.isEmpty { onTap(transcript) }
      }
    }
  }
}

/// The system's document camera: the pages come back as pictures, whose text `TextRecognition` reads.
struct DocumentScanner: UIViewControllerRepresentable {
  let onFinish: ([CGImage]) -> Void
  let onCancel: () -> Void

  static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

  func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
    let camera = VNDocumentCameraViewController()
    camera.delegate = context.coordinator
    return camera
  }

  func updateUIViewController(_ camera: VNDocumentCameraViewController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish, onCancel: onCancel) }

  final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
    let onFinish: ([CGImage]) -> Void
    let onCancel: () -> Void

    init(onFinish: @escaping ([CGImage]) -> Void, onCancel: @escaping () -> Void) {
      self.onFinish = onFinish
      self.onCancel = onCancel
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
      onFinish((0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).cgImage })
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
      onCancel()
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
      onCancel()
    }
  }
}

/// Text read from a scanned document, shown in the editor before it is saved.
struct ScannedText: Identifiable {
  let id = UUID()
  let text: String
}
