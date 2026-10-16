import Defaults
import PastronautCore
import SwiftUI

// English-only for now; localized with the iOS app in Faz 2.
struct SyncSettingsPane: View {
  @Default(.iCloudSync) private var isEnabled
  @State private var status: SyncStatus?
  @State private var actionError: String?
  @State private var isWorking = false
  @State private var confirmsDeletion = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Defaults.Toggle(key: .iCloudSync) {
        Text("Sync history with iCloud")
      }
      Text("""
        Text clips up to 100 KB are synced to your private iCloud database and shown in the \
        Pastronaut keyboard on iPhone. Clip text is end-to-end encrypted. Images, files and copies \
        excluded by Ignore rules stay on this Mac.
        """)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)

      Divider()

      Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
        GridRow {
          Text("Status:")
          Text(statusText)
        }
        GridRow {
          Text("Synced clips:")
          Text(status.map { "\($0.syncedClips)" } ?? "–")
        }
        GridRow {
          Text("Last sync:")
          Text(status?.lastSyncAt?.formatted(date: .abbreviated, time: .standard) ?? "–")
        }
      }
      .controlSize(.small)

      if let error = actionError ?? status?.lastError {
        Text(error)
          .fixedSize(horizontal: false, vertical: true)
          .foregroundStyle(.red)
          .controlSize(.small)
      }

      HStack {
        Button("Sync Now") {
          run { try await SyncBridge.shared.syncNow() }
        }
        .disabled(!isEnabled || isWorking)

        Button("Delete iCloud Data…", role: .destructive) {
          confirmsDeletion = true
        }
        .disabled(!isEnabled || isWorking)
      }

      Text("""
        Copies made on a nearby iPhone reach this Mac through Universal Clipboard and are synced too, \
        unless "com.apple.is-remote-clipboard" is listed under Ignore › Pasteboard types.
        """)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
    }
    .frame(minWidth: 350, maxWidth: 450)
    .padding()
    .confirmationDialog("Delete synced clips from iCloud?", isPresented: $confirmsDeletion) {
      Button("Delete iCloud Data", role: .destructive) {
        run { try await SyncBridge.shared.deleteCloudData() }
      }
    } message: {
      Text("Clips are removed from iCloud and from your other devices' synced copy. History on this Mac is kept. Sync is turned off.")
    }
    .task {
      while !Task.isCancelled {
        status = await SyncBridge.shared.status()
        try? await Task.sleep(for: .seconds(2))
      }
    }
  }

  private var statusText: String {
    guard isEnabled else { return "Off" }
    guard let status else { return "…" }
    return status.isRunning ? "On" : "Starting…"
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
