import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
  private let model = KeyboardModel()

  override func viewDidLoad() {
    super.viewDidLoad()
    model.insert = { [weak self] in self?.textDocumentProxy.insertText($0) }
    model.deleteBackward = { [weak self] in self?.textDocumentProxy.deleteBackward() }
    model.nextKeyboard = { [weak self] in self?.advanceToNextInputMode() }

    let host = UIHostingController(rootView: KeyboardView(model: model))
    host.view.translatesAutoresizingMaskIntoConstraints = false
    host.view.backgroundColor = .clear
    addChild(host)
    view.addSubview(host.view)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      host.view.topAnchor.constraint(equalTo: view.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      host.view.heightAnchor.constraint(equalToConstant: 300)
    ])
    host.didMove(toParent: self)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    model.hasFullAccess = hasFullAccess
    model.showsNextKeyboard = needsInputModeSwitchKey
    model.appeared()
  }
}

@Observable
final class KeyboardModel {
  var hasFullAccess = false
  var showsNextKeyboard = true
  var items: [ProtoItem] = []
  var status = ""
  /// Pasteboard changed since the last capture; detected from metadata only (never prompts).
  var hasNewClip = false

  var insert: (String) -> Void = { _ in }
  var deleteBackward: () -> Void = {}
  var nextKeyboard: () -> Void = {}

  func appeared() {
    let pasteboard = UIPasteboard.general
    let changeCount = pasteboard.changeCount
    let state = SharedStore.load()
    items = state.map { $0.items + $0.pendingCaptures } ?? []
    hasNewClip = hasFullAccess && pasteboard.hasStrings && changeCount != (state?.lastChangeCount ?? -1)

    // Tur 2: can the keyboard write to the App Group without Full Access?
    let wrote = SharedStore.update {
      $0.log.append("klavye: açıldı fullAccess=\(hasFullAccess) changeCount=\(changeCount) hasStrings=\(pasteboard.hasStrings)")
    }
    status = "\(items.count) öğe · Tam Erişim: \(hasFullAccess ? "açık" : "kapalı") · "
      + "okuma: \(state == nil ? "YOK" : "var") · yazma: \(wrote ? "var" : "YOK")"
  }

  /// T6a: plain read after a user tap. Expect the system paste prompt.
  func readOnTap() {
    let start = Date.now
    let text = UIPasteboard.general.string
    let ms = Int(Date.now.timeIntervalSince(start) * 1000)
    capture(text, via: "dokunma+okuma", ms: ms)
  }

  /// T6b: system PasteButton (UIPasteControl). Expected to skip the prompt; unknown inside a keyboard.
  func pasteButtonReceived(_ strings: [String]) {
    capture(strings.first, via: "PasteButton", ms: nil)
  }

  private func capture(_ text: String?, via: String, ms: Int?) {
    let changeCount = UIPasteboard.general.changeCount
    SharedStore.update { state in
      state.lastChangeCount = changeCount
      if let text, !text.isEmpty, !state.items.contains(where: { $0.text == text }),
         !state.pendingCaptures.contains(where: { $0.text == text }) {
        state.pendingCaptures.insert(
          ProtoItem(id: UUID().uuidString, text: text, date: .now, source: "iphone"), at: 0
        )
      }
      let timing = ms.map { ", \($0) ms" } ?? ""
      state.log.append("klavye: \(via) → \(text?.count ?? 0) karakter\(timing)")
    }
    hasNewClip = false
    if let state = SharedStore.load() { items = state.items + state.pendingCaptures }
  }
}

struct KeyboardView: View {
  let model: KeyboardModel

  var body: some View {
    VStack(spacing: 6) {
      Text(model.status).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
      if model.hasFullAccess {
        HStack(spacing: 6) {
          if model.hasNewClip {
            Text("Panoda yeni metin var").font(.caption).foregroundStyle(.tint)
          }
          Spacer()
          Button("Oku (A)") { model.readOnTap() }
            .buttonStyle(.bordered).font(.caption)
          PasteButton(payloadType: String.self) { strings in
            Task { @MainActor in model.pasteButtonReceived(strings) }
          }
          .labelStyle(.titleOnly)
          .font(.caption)
        }
      }
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 4) {
          ForEach(model.items) { item in
            Button { model.insert(item.text) } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(item.text).lineLimit(1)
                Text(item.source).font(.caption2).foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(8)
              .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
          }
        }
      }
      // Basic input row: App Review 4.4.1 expects real input and a next-keyboard control.
      HStack(spacing: 6) {
        if model.showsNextKeyboard {
          key(systemImage: "globe") { model.nextKeyboard() }
        }
        key(title: "boşluk") { model.insert(" ") }
        key(systemImage: "delete.left") { model.deleteBackward() }
        key(systemImage: "return") { model.insert("\n") }
      }
    }
    .padding(6)
  }

  private func key(title: String? = nil, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Group {
        if let systemImage { Image(systemName: systemImage) } else { Text(title ?? "") }
      }
      .frame(maxWidth: .infinity, minHeight: 40)
      .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
  }
}
