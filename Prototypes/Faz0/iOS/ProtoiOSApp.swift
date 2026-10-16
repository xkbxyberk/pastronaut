import SwiftUI
import UIKit

@main
struct ProtoiOSApp: App {
  var body: some Scene {
    WindowGroup {
      IOSContentView()
    }
  }
}

struct IOSContentView: View {
  private let cloud = ProtoCloud()
  @Environment(\.scenePhase) private var scenePhase
  @State private var status = "…"
  @State private var message = ""
  @State private var state = ProtoState()
  @State private var groupAvailable = false

  var body: some View {
    NavigationStack {
      List {
        Section("Durum") {
          LabeledContent("iCloud", value: status)
          LabeledContent("App Group", value: groupAvailable ? "erişilebilir" : "YOK")
          if !message.isEmpty { Text(message).font(.caption) }
        }
        Section("Testler") {
          Button("Buluttan çek → klavyeye aktar") { Task { await pull() } }
          Button("Uygulamada oku (B)") { readPasteboardInApp() }
          PasteButton(payloadType: String.self) { strings in
            Task { @MainActor in
              message = "PasteButton: \(strings.first?.prefix(40) ?? "boş")"
              SharedStore.log("app: PasteButton → \(strings.first?.count ?? 0) karakter")
              reloadLocal()
            }
          }
          Button("Klavyenin yakaladıklarını buluta gönder (\(state.pendingCaptures.count))") {
            Task { await pushCaptures() }
          }
          .disabled(state.pendingCaptures.isEmpty)
        }
        Section("Klavyedeki öğeler (\(state.items.count))") {
          ForEach(state.items) { item in
            VStack(alignment: .leading) {
              Text(item.text).lineLimit(2)
              Text("\(item.source) · \(item.date.formatted())").font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        Section("Günlük (klavye + uygulama)") {
          ForEach(state.log.reversed(), id: \.self) { Text($0).font(.caption.monospaced()) }
        }
        Section("Klavyeyi etkinleştirme") {
          Text("Ayarlar → Genel → Klavye → Klavyeler → Yeni Klavye Ekle → PastronautProto. Ardından klavyeye dokunup \"Tam Erişime İzin Ver\"i aç.")
            .font(.caption)
        }
      }
      .navigationTitle("Pastronaut Faz 0")
      .refreshable { reloadLocal() }
    }
    .task {
      status = await cloud.accountStatus()
      reloadLocal()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { reloadLocal() }
    }
  }

  private func reloadLocal() {
    groupAvailable = SharedStore.fileURL != nil
    state = SharedStore.load() ?? ProtoState()
  }

  private func pull() async {
    do {
      let items = try await cloud.fetchAll()
      SharedStore.update { $0.items = items }
      SharedStore.log("app: buluttan \(items.count) kayıt çekildi")
      message = "\(items.count) kayıt klavyeye aktarıldı."
    } catch {
      message = "Çekme hatası: \(error.localizedDescription)"
    }
    reloadLocal()
  }

  private func readPasteboardInApp() {
    let start = Date.now
    let text = UIPasteboard.general.string
    let ms = Int(Date.now.timeIntervalSince(start) * 1000)
    SharedStore.log("app: dokunma+okuma → \(text?.count ?? 0) karakter, \(ms) ms")
    message = "Uygulamada okundu: \(text.map { "\"\($0.prefix(40))\"" } ?? "boş (izin verilmedi ya da pano boş)")"
    reloadLocal()
  }

  private func pushCaptures() async {
    let captures = state.pendingCaptures
    var sent = 0
    for capture in captures {
      do {
        try await cloud.save(text: capture.text, source: "iphone")
        sent += 1
      } catch {
        message = "Gönderme hatası: \(error.localizedDescription)"
        break
      }
    }
    let sentIDs = Set(captures.prefix(sent).map(\.id))
    SharedStore.update { $0.pendingCaptures.removeAll { sentIDs.contains($0.id) } }
    SharedStore.log("app: \(sent) yakalama buluta gönderildi")
    reloadLocal()
  }
}
