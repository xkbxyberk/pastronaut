import CloudKit
import PastronautCore
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
  private let model = KeyboardModel()

  override func viewDidLoad() {
    super.viewDidLoad()
    // A UIInputView that adopts UIInputViewAudioFeedback, so key taps click like the system keyboard.
    let clickView = ClickInputView(frame: .zero, inputViewStyle: .keyboard)
    clickView.allowsSelfSizing = true
    inputView = clickView

    model.insert = { [weak self] in self?.textDocumentProxy.insertText($0) }
    model.deleteBackward = { [weak self] in self?.textDocumentProxy.deleteBackward() }
    model.nextKeyboard = { [weak self] in self?.advanceToNextInputMode() }

    let host = UIHostingController(rootView: KeyboardView(model: model))
    host.view.translatesAutoresizingMaskIntoConstraints = false
    // The system draws the keyboard backdrop (glass on iOS 26 and later); keep it visible.
    host.view.backgroundColor = .clear
    addChild(host)
    clickView.addSubview(host.view)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: clickView.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: clickView.trailingAnchor),
      host.view.topAnchor.constraint(equalTo: clickView.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: clickView.bottomAnchor),
      host.view.heightAnchor.constraint(equalToConstant: KeyboardMetrics.height)
    ])
    host.didMove(toParent: self)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    model.appeared(hasFullAccess: hasFullAccess, showsNextKeyboard: needsInputModeSwitchKey)
  }
}

private final class ClickInputView: UIInputView, UIInputViewAudioFeedback {
  var enableInputClicksWhenVisible: Bool { true }
}

enum KeyboardMetrics {
  static let height: CGFloat = 300
  static let keyHeight: CGFloat = 42
  static let spacing: CGFloat = 6
  /// Close to the system keys on iOS 26 and later.
  static let keyRadius: CGFloat = 10
  /// Extra inset for the top row: the system backdrop has large rounded top corners on iOS 26 and later.
  static let topRowInset: CGFloat = 8
}

// MARK: - Model

@MainActor
@Observable
final class KeyboardModel {
  enum Tab: String, CaseIterable, Identifiable {
    case pinned, recent, mac, iphone
    var id: Self { self }
  }

  private(set) var clips: [Clip] = []
  private(set) var hasFullAccess = false
  private(set) var showsNextKeyboard = true
  /// The pasteboard changed since the last capture. Detected from metadata only, so iOS shows no prompt.
  private(set) var hasNewClip = false
  /// Last iCloud fetch or upload outcome; shown in Debug builds for the end-to-end test.
  private(set) var cloudStatus = "cloud: idle"

  var tab: Tab = .recent
  var isSearching = false
  var query = ""
  /// The clip whose action panel is open (long press).
  var focused: Clip?

  var insert: (String) -> Void = { _ in }
  var deleteBackward: () -> Void = {}
  var nextKeyboard: () -> Void = {}

  private let files: SharedClipFiles?
  /// Network needs Full Access; only used when the keyboard has it.
  private let cloud: KeyboardCloud?
  /// Writable only with Full Access, like the rest of the App Group.
  private let defaults = UserDefaults(suiteName: PastronautIDs.appGroup)
  private let lastCapturedChangeCountKey = AutoCapture.lastChangeCountKey
  @ObservationIgnored private var lastCloudRefresh = Date.distantPast

  init() {
    let files = SharedClipFiles()
    self.files = files
    cloud = files.map { KeyboardCloud(containerIdentifier: PastronautIDs.iCloudContainer, files: $0) }
  }

  // MARK: Derived lists

  /// The most recent clip copied on a Mac: the most common thing to paste on the iPhone.
  var latestFromMac: Clip? {
    clips.filter { $0.sourceDevice == .mac }.max { $0.lastCopiedAt < $1.lastCopiedAt }
  }

  var visibleClips: [Clip] {
    let newestFirst = clips.sorted { $0.lastCopiedAt > $1.lastCopiedAt }
    switch tab {
    case .pinned: return newestFirst.filter(\.pinned)
    case .recent: return newestFirst
    case .mac: return newestFirst.filter { $0.sourceDevice == .mac }
    case .iphone: return newestFirst.filter { $0.sourceDevice != .mac }
    }
  }

  var searchResults: [Clip] {
    let query = query.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return [] }
    return clips
      .filter { $0.text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], locale: .current) != nil }
      .sorted { $0.lastCopiedAt > $1.lastCopiedAt }
  }

  // MARK: Lifecycle

  func appeared(hasFullAccess: Bool, showsNextKeyboard: Bool) {
    self.hasFullAccess = hasFullAccess
    self.showsNextKeyboard = showsNextKeyboard
    isSearching = false
    query = ""
    focused = nil
    if hasFullAccess {
      // Lets the app's setup guide tick "Full Access" (the App Group is read-only without it).
      defaults?.set(Date.now, forKey: "keyboardFullAccessSeenAt")
    }
    reload()

    let pasteboard = UIPasteboard.general
    let lastCaptured = defaults?.object(forKey: lastCapturedChangeCountKey) as? Int
    hasNewClip = hasFullAccess && pasteboard.hasStrings && pasteboard.changeCount != lastCaptured
    // "Save Clipboard on Opening" (app settings): save the new copy without waiting for the Paste button.
    // Texts already in the history (often a Mac copy brought by Universal Clipboard) are left alone.
    if hasNewClip, defaults?.bool(forKey: AutoCapture.settingKey) == true,
       let text = pasteboard.string, AutoCapture.allows(text),
       !clips.contains(where: { $0.id == Clip.id(for: text) }) {
      capture([text])
    }
    refreshFromCloud()
  }

  // MARK: Actions

  func type(_ clip: Clip) {
    click()
    insert(clip.text)
    if isSearching { endSearch() }
    focused = nil
  }

  func typeKey(_ text: String) {
    click()
    insert(text)
  }

  func deleteKey() {
    click()
    deleteBackward()
  }

  func beginSearch() {
    click()
    query = ""
    isSearching = true
  }

  func endSearch() {
    isSearching = false
    query = ""
  }

  func searchType(_ letter: String) {
    click()
    query.append(letter)
  }

  func searchDelete() {
    click()
    if !query.isEmpty { query.removeLast() }
  }

  /// Pins and deletions go straight to iCloud, like captures; the app and the Mac fetch them.
  var canEdit: Bool { hasFullAccess && cloud != nil }

  func togglePin(_ clip: Clip) {
    guard canEdit, let cloud else { return }
    focused = nil
    Task {
      do {
        try await cloud.setPinned(!clip.pinned, for: clip)
        cloudStatus = "cloud: pinned"
        _ = try? await cloud.refresh()
      } catch {
        cloudStatus = "cloud: pin failed \(Self.describe(error))"
      }
      reload()
    }
  }

  func delete(_ clip: Clip) {
    guard canEdit, let cloud else { return }
    focused = nil
    clips.removeAll { $0.id == clip.id }
    Task {
      do {
        try await cloud.delete(id: clip.id)
        cloudStatus = "cloud: deleted"
        _ = try? await cloud.refresh()
      } catch {
        cloudStatus = "cloud: delete failed \(Self.describe(error))"
      }
      reload()
    }
  }

  private func click() {
    UIDevice.current.playInputClick()
  }

  /// The app may not have run since the last change (iOS rations background pushes), so with Full
  /// Access the keyboard fetches the latest state itself.
  private func refreshFromCloud() {
    guard hasFullAccess, let cloud, Date.now.timeIntervalSince(lastCloudRefresh) > 5 else { return }
    lastCloudRefresh = .now
    cloudStatus = "cloud: fetching"
    Task {
      do {
        let cache = try await cloud.refresh()
        cloudStatus = "cloud: fetched \(cache.clips.count)"
      } catch {
        cloudStatus = "cloud: fetch failed \(Self.describe(error))"
      }
      reload()
    }
  }

  private static func describe(_ error: Error) -> String {
    if let error = error as? CKError { return "CKError \(error.code.rawValue) \(error.localizedDescription)" }
    return String(describing: error)
  }

  /// Receives text from the system Paste button and saves it to iCloud, so the Mac gets it without the
  /// app being opened. The inbox is written first and kept if the upload fails; the app sends it later.
  func capture(_ strings: [String]) {
    guard let files, let text = strings.first, !text.isEmpty else { return }
    let clip = Clip(text: text, sourceDevice: .iphone)
    try? files.appendToInbox(clip)
    defaults?.set(UIPasteboard.general.changeCount, forKey: lastCapturedChangeCountKey)
    hasNewClip = false
    reload()
    guard hasFullAccess, let cloud else { return }
    Task {
      do {
        try await cloud.save(clip)
        cloudStatus = "cloud: saved"
        try? files.removeFromInbox(id: clip.id)
        // Makes the cache newer than the app's snapshot, so the saved clip stays listed.
        _ = try? await cloud.refresh()
        reload()
      } catch {
        // Offline or not eligible: the inbox keeps it for the app.
        cloudStatus = "cloud: save failed \(Self.describe(error))"
      }
    }
  }

  #if DEBUG
  /// Why the list is empty, read by the end-to-end test.
  var diagnostics: String {
    guard let files else { return "diag: no app group container" }
    let url = files.directory.appending(path: "clips.json")
    guard let data = FileManager.default.contents(atPath: url.path) else {
      let exists = FileManager.default.fileExists(atPath: url.path)
      return "diag: cannot read snapshot (exists: \(exists), dir: \(files.directory.path))"
    }
    do {
      return "diag: \(try JSONDecoder().decode([Clip].self, from: data).count) clips in \(data.count) bytes"
    } catch {
      return "diag: decode failed \(error)"
    }
  }
  #endif

  private func reload() {
    guard let files else {
      clips = []
      return
    }
    // The app's snapshot, or the keyboard's own fetch when that is newer, plus captures not yet synced.
    var base = files.readSnapshot()
    if hasFullAccess, let cache = files.readKeyboardCache(), let fetchedAt = cache.fetchedAt,
       fetchedAt > files.snapshotDate ?? .distantPast {
      base = cache.clips
    }
    var byID: [String: Clip] = [:]
    for clip in base + files.readInbox() {
      byID[clip.id] = byID[clip.id].map { $0.merged(with: clip) } ?? clip
    }
    clips = Array(byID.values.inHistoryOrder.prefix(200))
    if let focused, !clips.contains(where: { $0.id == focused.id }) { self.focused = nil }
  }
}

// MARK: - Views

struct KeyboardView: View {
  let model: KeyboardModel

  var body: some View {
    VStack(spacing: KeyboardMetrics.spacing) {
      if model.isSearching {
        SearchPanel(model: model)
      } else if let clip = model.focused {
        ActionPanel(model: model, clip: clip)
      } else {
        BrowsePanel(model: model)
      }
      #if DEBUG
      Text(verbatim: model.cloudStatus)
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .accessibilityIdentifier("cloudStatus")
      #endif
    }
    .padding(.horizontal, 4)
    .padding(.top, 8)
    .padding(.bottom, 2)
  }
}

/// Default view: latest Mac copy, tabs, the list and the basic input row.
private struct BrowsePanel: View {
  let model: KeyboardModel

  var body: some View {
    VStack(spacing: KeyboardMetrics.spacing) {
      if let clip = model.latestFromMac {
        Button {
          model.type(clip)
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "laptopcomputer")
              .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 0) {
              Text("From Mac")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(clip.text.keyboardPreview)
                .font(.system(size: 15))
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "return.left")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 12)
          .frame(maxWidth: .infinity, minHeight: 40)
          .keyBackground(radius: 14)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, KeyboardMetrics.topRowInset)
        .accessibilityIdentifier("fromMacChip")
      }

      HStack(spacing: 4) {
        ForEach(KeyboardModel.Tab.allCases) { tab in
          Button {
            model.tab = tab
          } label: {
            Text(tab.title)
              .font(.system(size: 14, weight: model.tab == tab ? .semibold : .regular))
              .frame(maxWidth: .infinity, minHeight: 30)
              .background {
                if model.tab == tab {
                  Capsule().fill(KeyStyle.key)
                }
              }
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("tab.\(tab.rawValue)")
          .accessibilityAddTraits(model.tab == tab ? .isSelected : [])
        }
        Button {
          model.beginSearch()
        } label: {
          Image(systemName: "magnifyingglass")
            .frame(width: 44, height: 30)
            .background(KeyStyle.function, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Search"))
        .accessibilityIdentifier("searchKey")
        if model.hasNewClip {
          PasteButton(payloadType: String.self) { strings in
            Task { @MainActor in model.capture(strings) }
          }
          .labelStyle(.iconOnly)
          .buttonBorderShape(.capsule)
          .controlSize(.small)
        }
      }
      .padding(.horizontal, KeyboardMetrics.topRowInset)

      if !model.hasFullAccess {
        Text("Turn on Allow Full Access in Settings to save new copies from this keyboard.")
          .accessibilityIdentifier("fullAccessHint")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 4)
      }

      ClipList(model: model)

      HStack(spacing: KeyboardMetrics.spacing) {
        if model.showsNextKeyboard {
          FunctionKey(systemImage: "globe", label: "Next keyboard") { model.nextKeyboard() }
            .frame(width: 44)
        }
        CharacterKey(title: "space", fontSize: 16) { model.typeKey(" ") }
          .accessibilityIdentifier("spaceKey")
        FunctionKey(systemImage: "delete.left", label: "Delete") { model.deleteKey() }
          .frame(width: 52)
          .accessibilityIdentifier("deleteKey")
        FunctionKey(systemImage: "return", label: "Return") { model.typeKey("\n") }
          .frame(width: 72)
          .accessibilityIdentifier("returnKey")
      }
    }
  }
}

private struct ClipList: View {
  let model: KeyboardModel

  var body: some View {
    let clips = model.visibleClips
    Group {
      if model.clips.isEmpty {
        VStack(spacing: 4) {
          Text("No clips yet. Open Pastronaut once to sync your history.")
            .accessibilityIdentifier("emptyState")
          #if DEBUG
          Text(verbatim: model.diagnostics).font(.caption2).accessibilityIdentifier("diagnostics")
          #endif
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if clips.isEmpty {
        Text(model.tab == .pinned ? "No pinned clips" : "Nothing here yet")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 5) {
            ForEach(clips, id: \.id) { clip in
              ClipKey(clip: clip) { model.type(clip) } onLongPress: { model.focused = clip }
            }
          }
          .padding(.horizontal, 1)
          .padding(.bottom, 1)
        }
        .scrollIndicators(.hidden)
        .noTopScrollEdgeEffect()
      }
    }
    .frame(maxHeight: .infinity)
  }
}

/// One clip, drawn like a key: tap types it, long press opens its actions.
private struct ClipKey: View {
  let clip: Clip
  let onTap: () -> Void
  let onLongPress: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      // Same content icon as the app: a swatch for colors, a symbol for links, code, text…
      ClipIcon(content: clip.content, size: 26)
      Text(clip.text.keyboardPreview)
        .font(.system(size: 15))
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      if clip.pinned {
        Image(systemName: "pin.fill")
          .font(.caption2)
          .foregroundStyle(Color.pin)
          .accessibilityIdentifier("pinIcon")
      }
      HStack(spacing: 3) {
        // Only Mac copies know their app; iOS does not tell which app wrote to the pasteboard.
        if let app = clip.sourceAppName {
          Text(verbatim: app)
            .lineLimit(1)
            .frame(maxWidth: 80, alignment: .trailing)
        }
        Image(systemName: clip.sourceDevice == .mac ? "laptopcomputer" : "iphone")
          .accessibilityHidden(true)
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
    }
    .padding(.leading, 6)
    .padding(.trailing, 10)
    .frame(minHeight: 38)
    .keyBackground()
    .contentShape(Rectangle())
    .onTapGesture(perform: onTap)
    .onLongPressGesture(minimumDuration: 0.4, perform: onLongPress)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .accessibilityIdentifier("kbClip")
    .accessibilityAction(named: Text("Actions"), onLongPress)
  }
}

/// Long press on a clip: the whole text and what can be done with it.
private struct ActionPanel: View {
  let model: KeyboardModel
  let clip: Clip
  @State private var confirmsDelete = false

  var body: some View {
    VStack(spacing: KeyboardMetrics.spacing) {
      ScrollView {
        Text(clip.text)
          .font(.system(size: 15))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
      }
      .frame(maxHeight: .infinity)
      .keyBackground(radius: 18)
      .noTopScrollEdgeEffect()
      .padding(.horizontal, KeyboardMetrics.topRowInset)

      HStack(spacing: KeyboardMetrics.spacing) {
        FunctionKey(systemImage: "xmark", label: "Close") { model.focused = nil }
          .frame(width: 52)
          .accessibilityIdentifier("clipAction.close")
        if model.canEdit {
          FunctionKey(systemImage: clip.pinned ? "pin.slash" : "pin",
                      label: clip.pinned ? "Unpin" : "Pin") { model.togglePin(clip) }
            .frame(width: 52)
            .accessibilityIdentifier("clipAction.pin")
          Button {
            if confirmsDelete { model.delete(clip) } else { confirmsDelete = true }
          } label: {
            Group {
              if confirmsDelete {
                Text("Delete?").font(.system(size: 15, weight: .semibold))
              } else {
                Image(systemName: "trash").font(.system(size: 18))
              }
            }
            .foregroundStyle(.red)
            .frame(maxWidth: confirmsDelete ? 90 : 52, minHeight: KeyboardMetrics.keyHeight)
            .background(KeyStyle.function, in: RoundedRectangle(cornerRadius: KeyboardMetrics.keyRadius, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(confirmsDelete ? Text("Confirm delete") : Text("Delete"))
          .accessibilityIdentifier("clipAction.delete")
        }
        Button {
          model.type(clip)
        } label: {
          Label("Type", systemImage: "return.left")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.onAccent)
            .frame(maxWidth: .infinity, minHeight: KeyboardMetrics.keyHeight)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: KeyboardMetrics.keyRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("clipAction.insert")
      }
    }
  }
}

/// Search: a small letter keyboard filters the history; tapping a result types it.
private struct SearchPanel: View {
  let model: KeyboardModel

  var body: some View {
    VStack(spacing: KeyboardMetrics.spacing) {
      HStack(spacing: KeyboardMetrics.spacing) {
        HStack(spacing: 6) {
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
          if model.query.isEmpty {
            Text("Search history").foregroundStyle(.secondary)
          } else {
            Text(verbatim: model.query)
          }
          Spacer(minLength: 0)
        }
        .font(.system(size: 16))
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(Capsule().fill(KeyStyle.key))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("searchField")
        Button {
          model.endSearch()
        } label: {
          Text("Done")
            .font(.system(size: 16, weight: .semibold))
            .frame(minWidth: 64, minHeight: 36)
            .background(KeyStyle.function, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("searchDone")
      }
      .padding(.horizontal, KeyboardMetrics.topRowInset)

      ScrollView(.horizontal) {
        HStack(spacing: 5) {
          if model.searchResults.isEmpty {
            Text(model.query.isEmpty ? "Type to search" : "No matches")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 6)
          }
          ForEach(model.searchResults.prefix(20), id: \.id) { clip in
            Button {
              model.type(clip)
            } label: {
              HStack(spacing: 6) {
                ClipIcon(content: clip.content, size: 22)
                Text(clip.text.keyboardPreview)
                  .font(.system(size: 15))
                  .lineLimit(1)
              }
              .frame(maxWidth: 220)
              .padding(.leading, 6)
              .padding(.trailing, 10)
                .frame(minHeight: 34)
                .keyBackground()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("searchResult")
          }
        }
        .padding(.horizontal, 1)
      }
      .scrollIndicators(.hidden)
      .frame(height: 36)

      LetterKeys(model: model)
    }
  }
}

private struct LetterKeys: View {
  let model: KeyboardModel

  /// Turkish Q layout on Turkish devices, QWERTY elsewhere.
  private var rows: [[String]] {
    if Locale.current.language.languageCode?.identifier == "tr" {
      return [
        ["q", "w", "e", "r", "t", "y", "u", "ı", "o", "p", "ğ", "ü"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ş", "i"],
        ["z", "x", "c", "v", "b", "n", "m", "ö", "ç"]
      ]
    }
    return [
      ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
      ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
      ["z", "x", "c", "v", "b", "n", "m"]
    ]
  }

  var body: some View {
    VStack(spacing: 8) {
      ForEach(rows.indices, id: \.self) { index in
        HStack(spacing: 5) {
          ForEach(rows[index], id: \.self) { letter in
            CharacterKey(title: LocalizedStringKey(letter), fontSize: 20, verbatim: letter) {
              model.searchType(letter)
            }
            .accessibilityIdentifier("letter.\(letter)")
          }
          if index == rows.count - 1 {
            FunctionKey(systemImage: "delete.left", label: "Delete") { model.searchDelete() }
              .frame(width: 44)
          }
        }
      }
      CharacterKey(title: "space", fontSize: 16) { model.searchType(" ") }
    }
  }
}

// MARK: - Keys

/// Colors close to the system keyboard: white keys in light mode, translucent light keys in dark mode,
/// and slightly darker function keys. Both sit on the system's own keyboard backdrop.
enum KeyStyle {
  static let key = Color(UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.24) : .white
  })
  static let function = Color(UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.12) : UIColor(white: 0, alpha: 0.12)
  })
  static let shadow = Color(UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(white: 0, alpha: 0.4) : UIColor(white: 0, alpha: 0.28)
  })
}

private struct CharacterKey: View {
  let title: LocalizedStringKey
  var fontSize: CGFloat = 20
  /// Single letters are shown as typed, never looked up in the string catalog.
  var verbatim: String?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if let verbatim { Text(verbatim: verbatim) } else { Text(title) }
      }
      .font(.system(size: fontSize))
      .frame(maxWidth: .infinity, minHeight: KeyboardMetrics.keyHeight)
      .keyBackground()
    }
    .buttonStyle(.plain)
  }
}

private struct FunctionKey: View {
  let systemImage: String
  let label: LocalizedStringKey
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 18))
        .frame(maxWidth: .infinity, minHeight: KeyboardMetrics.keyHeight)
        .background(KeyStyle.function, in: RoundedRectangle(cornerRadius: KeyboardMetrics.keyRadius, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(label))
  }
}

private extension View {
  func keyBackground(radius: CGFloat = KeyboardMetrics.keyRadius) -> some View {
    background(
      RoundedRectangle(cornerRadius: radius, style: .continuous)
        .fill(KeyStyle.key)
        .shadow(color: KeyStyle.shadow, radius: 0, x: 0, y: 1)
    )
  }

  /// iOS 26 blurs the top edge of scroll views; in a short keyboard list that hides the first row.
  @ViewBuilder
  func noTopScrollEdgeEffect() -> some View {
    if #available(iOS 26.0, *) {
      scrollEdgeEffectHidden(true, for: .top)
    } else {
      self
    }
  }
}

private extension String {
  /// One-line preview: line breaks shown as ⏎, surrounding blank space dropped.
  var keyboardPreview: String {
    trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ⏎ ")
  }
}

private extension KeyboardModel.Tab {
  var title: LocalizedStringKey {
    switch self {
    case .pinned: "Pinned"
    case .recent: "Recent"
    case .mac: "Mac"
    case .iphone: "iPhone"
    }
  }
}
