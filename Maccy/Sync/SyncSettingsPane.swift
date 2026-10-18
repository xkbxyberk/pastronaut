import CoreImage.CIFilterBuiltins
import Defaults
import PastronautCore
import SwiftUI

// Pastronaut's own Mac strings live in the "Pastronaut" table (Maccy/Sync/Pastronaut.xcstrings), so Maccy's
// Localizable.strings files stay untouched for upstream merges: Text("…", tableName: "Pastronaut") and
// String(localized: "…", table: "Pastronaut").
struct SyncSettingsPane: View {
  @Default(.iCloudSync) private var isEnabled
  @State private var status: SyncStatus?
  @State private var actionError: String?
  @State private var isWorking = false
  @State private var confirmsDeletion = false

  /// The iPhone app's App Store page (same record as the Mac App Store app: universal purchase).
  private static let iPhoneAppURL = "https://apps.apple.com/app/id6824087843"

  var body: some View {
    Form {
      Section {
        Defaults.Toggle(key: .iCloudSync) {
          Text("Sync history with iCloud", tableName: "Pastronaut")
        }
        LabeledContent {
          HStack(spacing: 6) {
            Circle().fill(statusColor).frame(width: 7, height: 7)
            Text(verbatim: statusText)
          }
        } label: {
          Text("Status", tableName: "Pastronaut")
        }
        LabeledContent {
          Text(verbatim: status.map { "\($0.syncedClips)" } ?? "–")
        } label: {
          Text("Synced clips", tableName: "Pastronaut")
        }
        LabeledContent {
          if let date = status?.lastSyncAt {
            Text(date, format: .relative(presentation: .named))
          } else {
            Text(verbatim: "–")
          }
        } label: {
          Text("Last sync", tableName: "Pastronaut")
        }
        if let error = actionError ?? status?.lastError {
          Text(verbatim: error)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
        }
      } header: {
        Text(verbatim: "iCloud")
      } footer: {
        Text("Text clips up to 100 KB are synced to your private iCloud database and shown in the Pastronaut keyboard on iPhone. Images, files and copies excluded by Ignore rules stay on this Mac.", tableName: "Pastronaut")
          .foregroundStyle(.secondary)
      }

      Section {
        privacyToggle(.syncSkipOneTimeCodes,
                      title: Text("Don't sync one-time codes", tableName: "Pastronaut"),
                      detail: Text("Verification and SMS codes never reach iCloud and are removed from this Mac after 5 minutes.", tableName: "Pastronaut"))
        privacyToggle(.syncSkipCardNumbers,
                      title: Text("Don't sync card and IBAN numbers", tableName: "Pastronaut"),
                      detail: Text("Text that looks like a card number or IBAN stays on this Mac.", tableName: "Pastronaut"))
        privacyToggle(.syncPinnedOnly,
                      title: Text("Sync pinned items only", tableName: "Pastronaut"),
                      detail: Text("History stays on this Mac; your iPhone shows only what you pin.", tableName: "Pastronaut"))
      } header: {
        Text("Privacy", tableName: "Pastronaut")
      } footer: {
        Label {
          Text("Clip text and collection names are encrypted on this Mac before they reach iCloud (end-to-end with Advanced Data Protection), and iCloud can't tell which texts you saved. Copies from password managers are never synced.", tableName: "Pastronaut")
        } icon: {
          Image(systemName: "lock")
        }
        .foregroundStyle(.secondary)
        Link(destination: URL(string: "https://xkbxyberk.github.io/pastronaut/privacy.html")!) {
          Text("Privacy Policy", tableName: "Pastronaut")
        }
      }

      CollectionsSettingsSection()

      Section {
        HStack(spacing: 14) {
          if let qr = QRCode.image(for: Self.iPhoneAppURL, size: 84) {
            Image(nsImage: qr)
              .interpolation(.none)
              .resizable()
              .frame(width: 84, height: 84)
              .padding(6)
              .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
              .accessibilityLabel(Text("QR code", tableName: "Pastronaut"))
          }
          VStack(alignment: .leading, spacing: 4) {
            Text("Get the iPhone app", tableName: "Pastronaut")
              .font(.headline)
            Text("Scan with your iPhone's camera. The app walks you through setting up the keyboard.", tableName: "Pastronaut")
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(.vertical, 4)
      } header: {
        Text(verbatim: "iPhone")
      }

      Section {
        HStack {
          Button(role: .destructive) {
            confirmsDeletion = true
          } label: {
            Text("Delete iCloud Data…", tableName: "Pastronaut")
          }
          .disabled(!isEnabled || isWorking)
          Spacer()
          Button {
            run { try await SyncBridge.shared.syncNow() }
          } label: {
            Text("Sync Now", tableName: "Pastronaut")
          }
          .disabled(!isEnabled || isWorking)
        }
      } footer: {
        Text("Copies made on a nearby iPhone reach this Mac through Universal Clipboard and are synced too, unless \"com.apple.is-remote-clipboard\" is listed under Ignore › Pasteboard types.", tableName: "Pastronaut")
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 700)
    .confirmationDialog(Text("Delete synced clips from iCloud?", tableName: "Pastronaut"), isPresented: $confirmsDeletion) {
      Button(role: .destructive) {
        run { try await SyncBridge.shared.deleteCloudData() }
      } label: {
        Text("Delete iCloud Data", tableName: "Pastronaut")
      }
    } message: {
      Text("Clips are removed from iCloud and from your other devices' synced copy. History on this Mac is kept. Sync is turned off.", tableName: "Pastronaut")
    }
    .task {
      while !Task.isCancelled {
        status = await SyncBridge.shared.status()
        try? await Task.sleep(for: .seconds(2))
      }
    }
  }

  private func privacyToggle(_ key: Defaults.Key<Bool>, title: Text, detail: Text) -> some View {
    Defaults.Toggle(key: key) {
      VStack(alignment: .leading, spacing: 2) {
        title
        detail
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .disabled(!isEnabled)
  }

  private var statusColor: Color {
    guard isEnabled else { return .secondary }
    return status?.lastError == nil ? .green : .orange
  }

  private var statusText: String {
    guard isEnabled else { return String(localized: "Off", table: "Pastronaut") }
    guard let status else { return "…" }
    return status.isRunning ? String(localized: "On", table: "Pastronaut") : String(localized: "Starting…", table: "Pastronaut")
  }

  private func run(_ action: @escaping () async throws -> Void) {
    isWorking = true
    actionError = nil
    Task {
      do {
        try await action()
      } catch {
        actionError = error.localizedDescription
      }
      status = await SyncBridge.shared.status()
      isWorking = false
    }
  }
}

enum QRCode {
  /// A crisp QR code for `string`, `size` points wide.
  static func image(for string: String, size: CGFloat) -> NSImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let scale = (size * 2) / output.extent.width
    let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let representation = NSCIImageRep(ciImage: scaled)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(representation)
    return image
  }
}
