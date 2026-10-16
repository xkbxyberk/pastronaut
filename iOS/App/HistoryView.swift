import PastronautCore
import SwiftUI

struct HistoryView: View {
  @Environment(ClipStore.self) private var store
  @State private var copiedID: String?
  @State private var showsSettings = false

  var body: some View {
    @Bindable var store = store
    NavigationStack {
      List {
        ForEach(store.filteredClips, id: \.id) { clip in
          Button {
            store.copy(clip)
            withAnimation { copiedID = clip.id }
          } label: {
            ClipRow(clip: clip, isCopied: copiedID == clip.id)
          }
          .foregroundStyle(.primary)
          .swipeActions(edge: .leading) {
            Button {
              store.togglePin(clip)
            } label: {
              Label(clip.pinned ? "Unpin" : "Pin", systemImage: clip.pinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
          }
          .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
              store.delete(clip)
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
        }
      }
      .overlay {
        if store.clips.isEmpty {
          ContentUnavailableView(
            "No clips yet",
            systemImage: "doc.on.clipboard",
            description: Text("Turn on Sync in Pastronaut on your Mac, or save your clipboard with the paste button.")
          )
        } else if store.filteredClips.isEmpty {
          ContentUnavailableView.search(text: store.searchText)
        }
      }
      .searchable(text: $store.searchText)
      .refreshable { await store.refresh() }
      .navigationTitle("Pastronaut")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          PasteButton(payloadType: String.self) { strings in
            Task { @MainActor in store.save(strings.first) }
          }
          .labelStyle(.iconOnly)
          .buttonBorderShape(.circle)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showsSettings = true
          } label: {
            Label("Settings", systemImage: "gearshape")
          }
        }
      }
      .sheet(isPresented: $showsSettings) {
        SettingsView()
      }
    }
  }
}

struct ClipRow: View {
  let clip: Clip
  let isCopied: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(clip.text)
        .lineLimit(3)
        .font(clip.kind == .url ? .body.monospaced() : .body)
      HStack(spacing: 6) {
        Image(systemName: clip.sourceDevice == .mac ? "laptopcomputer" : "iphone")
        Text(clip.lastCopiedAt, style: .relative)
        if clip.pinned {
          Image(systemName: "pin.fill").foregroundStyle(.orange)
        }
        Spacer()
        if isCopied {
          Label("Copied", systemImage: "checkmark").foregroundStyle(.green)
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }
}
