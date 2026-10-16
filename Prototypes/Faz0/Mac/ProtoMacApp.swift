import SwiftUI

@main
struct ProtoMacApp: App {
  var body: some Scene {
    WindowGroup("Pastronaut Faz 0") {
      MacContentView()
        .frame(minWidth: 480, minHeight: 420)
    }
  }
}

struct MacContentView: View {
  private let cloud = ProtoCloud()
  @State private var text = ""
  @State private var status = "…"
  @State private var message = ""
  @State private var items: [ProtoItem] = []

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("iCloud hesabı: \(status)").font(.headline)
      Text("Kapsayıcı: \(ProtoIDs.container)").font(.caption).foregroundStyle(.secondary)
      HStack {
        TextField("iPhone'a gidecek metin", text: $text)
        Button("iCloud'a yaz") { Task { await write() } }
          .disabled(text.isEmpty)
      }
      HStack {
        Button("Yenile") { Task { await refresh() } }
        Text(message).font(.caption).foregroundStyle(.secondary)
      }
      List(items) { item in
        VStack(alignment: .leading) {
          Text(item.text).lineLimit(2)
          Text("\(item.source) · \(item.date.formatted())").font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .padding()
    .task {
      status = await cloud.accountStatus()
      await refresh()
    }
  }

  private func write() async {
    do {
      try await cloud.save(text: text, source: "mac")
      message = "Yazıldı."
      text = ""
      await refresh()
    } catch {
      message = "Yazma hatası: \(error.localizedDescription)"
    }
  }

  private func refresh() async {
    do {
      items = try await cloud.fetchAll()
      message = "\(items.count) kayıt."
    } catch {
      message = "Okuma hatası: \(error.localizedDescription)"
    }
  }
}
