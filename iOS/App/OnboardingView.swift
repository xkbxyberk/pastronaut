import PastronautCore
import SwiftUI
import UIKit

struct OnboardingView: View {
  enum Presentation {
    case firstLaunch
    case settings
  }

  enum Step: Int, CaseIterable, Identifiable {
    case welcome
    case keyboard
    case paste

    var id: Int { rawValue }
    var number: Int { rawValue + 1 }
    var next: Step? { Step(rawValue: rawValue + 1) }
  }

  let presentation: Presentation
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(AppPreferences.onboardingKey) private var hasCompletedOnboarding = false
  @AppStorage(AutoCapture.settingKey, store: UserDefaults(suiteName: PastronautIDs.appGroup))
  private var autoSave = true
  @State private var step: Step
  @State private var paste = PasteProgress()
  @FocusState private var isTryFieldFocused: Bool
  private let setup = KeyboardSetup.shared

  init(presentation: Presentation, initialStep: Step = .welcome) {
    self.presentation = presentation
    _step = State(initialValue: initialStep)
  }

  var body: some View {
    switch presentation {
    case .firstLaunch:
      NavigationStack {
        pages
          .toolbar {
            if step.next != nil {
              ToolbarItem(placement: .topBarTrailing) {
                Button("Skip", action: finish)
                  .accessibilityIdentifier("onboardingSkip")
              }
            }
          }
      }
    case .settings:
      pages
        .navigationTitle(AppPreferences.shared.string("Setup Guide"))
        .navigationBarTitleDisplayMode(.inline)
    }
  }

  private var pages: some View {
    VStack(spacing: 0) {
      TabView(selection: $step) {
        WelcomeStep()
          .tag(Step.welcome)
        KeyboardStep(setup: setup, isTryFieldFocused: $isTryFieldFocused, openSettings: openSettings)
          .tag(Step.keyboard)
        PasteStep(autoSave: $autoSave, progress: paste)
          .tag(Step.paste)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      // The buttons stay behind the keyboard: over it they covered what the try step says to do.
      footer
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    .onAppear { setup.update() }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      setup.update()
      // Back from Settings or from copying in another app: check without a tap.
      if step == .paste, autoSave { paste.cameBack() }
    }
  }

  // MARK: - Footer: one main action for where the person is

  private struct FooterAction {
    let title: LocalizedStringKey
    let identifier: String
    let action: () -> Void
  }

  private var footer: some View {
    let main = mainAction
    return VStack(spacing: 10) {
      PageIndicator(current: step)
        .padding(.bottom, 4)
      Button(action: main.action) {
        Text(main.title)
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 4)
      }
      .primaryActionStyle()
      .controlSize(.large)
      .accessibilityIdentifier(main.identifier)
      if let other = otherAction {
        Button(action: other.action) {
          Text(other.title)
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 32)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(other.identifier)
      } else {
        // Keeps the main button where it was when the second one comes and goes.
        Color.clear.frame(height: 32)
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .frame(maxWidth: 560)
    .animation(.snappy, value: step)
  }

  private var finishTitle: LocalizedStringKey {
    presentation == .firstLaunch ? "Start Using Pastronaut" : "Done"
  }

  private var mainAction: FooterAction {
    let next = FooterAction(
      title: step.next == nil ? finishTitle : "Continue", identifier: "onboardingNext", action: advance
    )
    switch step {
    case .welcome:
      return next
    case .keyboard:
      switch KeyboardStage(setup) {
      case .settings:
        return FooterAction(title: "Open Settings", identifier: "openKeyboardSettings", action: openSettings)
      case .tryKeyboard:
        return FooterAction(title: "Try the Pastronaut Keyboard", identifier: "tryKeyboard") {
          isTryFieldFocused = true
        }
      case .done:
        return next
      }
    case .paste:
      guard autoSave else { return next }
      switch paste.stage {
      case .allow:
        return FooterAction(title: "Open Settings", identifier: "openPasteSettings") {
          paste.openedSettings()
          openSettings()
        }
      case .check:
        return FooterAction(title: "Check Now", identifier: "tryClipboardSave") { paste.check() }
      case .done:
        return next
      }
    }
  }

  private var otherAction: FooterAction? {
    switch step {
    case .welcome:
      return nil
    case .keyboard:
      switch KeyboardStage(setup) {
      case .settings:
        return FooterAction(title: "Not Now", identifier: "keyboardNotNow", action: advance)
      case .tryKeyboard:
        return FooterAction(title: "Not Now", identifier: "keyboardNotNow", action: advance)
      case .done:
        return nil
      }
    case .paste:
      guard autoSave else { return nil }
      switch paste.stage {
      case .allow:
        return FooterAction(title: "Already Allowed? Check", identifier: "pasteAlreadyAllowed") { paste.stage = .check }
      case .check:
        return FooterAction(title: "Open Settings", identifier: "openPasteSettings", action: openSettings)
      case .done:
        return FooterAction(title: "Check Again", identifier: "tryClipboardSave") { paste.check() }
      }
    }
  }

  private func advance() {
    isTryFieldFocused = false
    if let next = step.next {
      withAnimation(.snappy) { step = next }
    } else {
      finish()
    }
  }

  private func finish() {
    hasCompletedOnboarding = true
    dismiss()
  }

  private func openSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      openURL(url)
    }
  }
}

/// Where the keyboard setup is: switches to turn on in Settings, the keyboard to open once (iOS tells the app
/// about Full Access only when the keyboard has been on screen), or done.
private enum KeyboardStage {
  case settings
  case tryKeyboard
  case done

  @MainActor
  init(_ setup: KeyboardSetup) {
    self = !setup.isKeyboardAdded ? .settings : (setup.hasFullAccess ? .done : .tryKeyboard)
  }

  var index: Int {
    switch self {
    case .settings: 0
    case .tryKeyboard: 1
    case .done: 2
    }
  }
}

/// The paste step: allow pasting in Settings, check it with a copy from another app, done. The check runs by
/// itself when the person comes back to the app with a new copy.
@MainActor
@Observable
final class PasteProgress {
  enum Stage { case allow, check, done }

  var stage: Stage = .allow
  private(set) var trial: ClipStore.ClipboardTrial?
  private(set) var isChecking = false
  private var lastCheckedChangeCount: Int?
  private var wentToSettings = false

  func openedSettings() {
    wentToSettings = true
  }

  /// The app is in front again: from Settings, the next thing is the check; with a new copy, the check itself.
  func cameBack() {
    if stage == .allow, wentToSettings {
      withAnimation(.snappy) { stage = .check }
    }
    let pasteboard = UIPasteboard.general
    guard stage != .allow, pasteboard.hasStrings, pasteboard.changeCount != lastCheckedChangeCount else { return }
    check()
  }

  func check() {
    guard !isChecking else { return }
    isChecking = true
    lastCheckedChangeCount = UIPasteboard.general.changeCount
    Task {
      let result = await ClipStore.shared.trySavingClipboard()
      withAnimation(.snappy) {
        trial = result
        if result == .saved { stage = .done } else if stage == .allow { stage = .check }
      }
      if result == .saved { Haptics.success() }
      isChecking = false
    }
  }
}

private struct WelcomeStep: View {
  @AppStorage(PreviewChoice.key) private var previewChoice = PreviewChoice.on.rawValue

  var body: some View {
    StepPage(
      systemImage: "laptopcomputer.and.iphone",
      title: "Welcome to Pastronaut",
      subtitle: "Everything you copy, on your Mac and on your iPhone, in one history you can reach from any app."
    ) {
      OnboardingCard {
        FeatureRow(
          systemImage: "laptopcomputer.and.arrow.down",
          title: "From your Mac: automatic",
          detail: "Everything you copy on your Mac appears here and in the keyboard, without opening anything."
        )
        FeatureRow(
          systemImage: "bolt.fill",
          title: "From your iPhone: saved as you open it",
          detail: "iPhone lets only the app on screen read the clipboard. Pastronaut saves your latest copy the moment you open the app or its keyboard."
        )
        FeatureRow(
          systemImage: "keyboard",
          title: "Paste with one tap",
          detail: "The Pastronaut keyboard puts your whole history next to any text field."
        )
        FeatureRow(
          systemImage: "lock.icloud",
          title: "Private by design",
          detail: "Clips travel through your own iCloud and are encrypted on this device before upload."
        )
      }
      OnboardingCard {
        Toggle(isOn: Binding(
          get: { previewChoice == PreviewChoice.on.rawValue },
          set: { isOn in
            previewChoice = isOn ? PreviewChoice.on.rawValue : PreviewChoice.off.rawValue
            if !isOn { PreviewStore.shared.clear() }
          }
        )) {
          Label {
            Text("Link and Map Previews")
          } icon: {
            SettingsIcon(systemImage: "rectangle.and.text.magnifyingglass", color: .teal)
          }
        }
        .accessibilityIdentifier("onboardingPreviewsToggle")
        Text("Links and addresses can show their page and a map inside their cards. For that, this iPhone opens the link and asks Apple Maps where the address is. Links that look like sign-in or reset links are never opened.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Text("The next two steps take about a minute and let Pastronaut work without interruptions.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct KeyboardStep: View {
  let setup: KeyboardSetup
  var isTryFieldFocused: FocusState<Bool>.Binding
  let openSettings: () -> Void
  @State private var showsWhy = false

  var body: some View {
    let stage = KeyboardStage(setup)
    StepPage(
      systemImage: "keyboard.fill",
      title: "Add the Pastronaut keyboard",
      subtitle: "Type what you copied on your Mac with a single tap, in any app."
    ) {
      ProgressStrip(
        titles: ["Settings", "Try", "Ready"], current: stage.index, identifiers: ["setupStep1", "setupStep2", "setupStep3"]
      )
      switch stage {
      case .settings:
        OnboardingCard {
          Text("Turn on two switches in Settings")
            .font(.headline)
          SettingsMockup(title: Text("Keyboards")) {
            MockRow(icon: nil, title: Text(verbatim: "Pastronaut")) {
              MockSwitch()
            }
            MockDivider()
            MockRow(icon: nil, title: Text("Allow Full Access"), isHighlighted: true) {
              MockSwitch()
            }
          }
          .accessibilityHidden(true)
          Text("Open Settings takes you to Pastronaut's page: tap Keyboards, turn on both switches, then come back.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          whyButton
        }
      case .tryKeyboard:
        KeyboardTryCard(setup: setup, isFocused: isTryFieldFocused, openSettings: openSettings)
      case .done:
        OnboardingCard {
          VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 48))
              .foregroundStyle(.green)
              .accessibilityHidden(true)
            Text("The keyboard is ready")
              .font(.title3.bold())
            Text("Full Access is on. The keyboard saves your new copies itself and stays up to date even when the app is closed.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity)
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("fullAccessConfirmed")
        }
      }
    }
    .animation(.snappy, value: stage.index)
    .onChange(of: setup.hasFullAccess) { _, hasFullAccess in
      if hasFullAccess { Haptics.success() }
    }
    .sheet(isPresented: $showsWhy) { WhyFullAccess() }
  }

  private var whyButton: some View {
    Button {
      showsWhy = true
    } label: {
      Label("Why Full Access? Nothing you type is sent anywhere", systemImage: "checkmark.shield")
        .font(.subheadline.weight(.semibold))
    }
    .buttonStyle(.borderless)
    .accessibilityIdentifier("whyFullAccess")
  }
}

/// What Full Access is for, in a sheet so the setup stays short.
private struct WhyFullAccess: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("With Full Access, the keyboard saves your new copies itself and fetches the latest history from iCloud, even when the app is closed.")
          Text("Without it, the keyboard still works and types your history as of the last time you opened Pastronaut.")
            .foregroundStyle(.secondary)
          Label {
            Text("Even with Full Access, nothing you type is sent anywhere. The keyboard only reads your history in your own iCloud and writes the copies you capture there.")
          } icon: {
            Image(systemName: "lock")
          }
          .foregroundStyle(.secondary)
          Text("In password fields iPhone always switches to its own keyboard.")
            .foregroundStyle(.secondary)
        }
        .font(.body)
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
      }
      .navigationTitle(Text("Why Full Access?"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}

private struct PasteStep: View {
  @Binding var autoSave: Bool
  let progress: PasteProgress

  var body: some View {
    StepPage(
      systemImage: "doc.on.clipboard.fill",
      title: "Paste without being asked",
      subtitle: "Pastronaut saves your latest copy when you open it. Allow pasting once, and iPhone stops asking every time."
    ) {
      OnboardingCard {
        Toggle(isOn: $autoSave) {
          Label {
            Text("Save Clipboard on Opening")
          } icon: {
            SettingsIcon(systemImage: "doc.on.clipboard", color: .orange)
          }
        }
        .accessibilityIdentifier("onboardingAutoSaveToggle")
        Text("One-time codes, card numbers and IBANs are never saved this way.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      if !autoSave {
        Text("While it's off, this permission isn't needed. Save copies with the Paste button or by sharing them to Pastronaut.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 4)
      } else {
        ProgressStrip(
          titles: ["Allow", "Check", "Ready"], current: progress.stage.index,
          identifiers: ["pasteStep1", "pasteStep2", "pasteStep3"]
        )
        switch progress.stage {
        case .allow:
          OnboardingCard {
            Text("Choose Allow in Settings")
              .font(.headline)
            SettingsMockup(title: Text("Paste from Other Apps")) {
              MockRow(icon: nil, title: Text("Ask")) { EmptyView() }
              MockDivider()
              MockRow(icon: nil, title: Text("Deny")) { EmptyView() }
              MockDivider()
              MockRow(icon: nil, title: Text("Allow"), isHighlighted: true) {
                Image(systemName: "checkmark")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(Color.blue)
              }
            }
            .accessibilityHidden(true)
            Text("Open Settings takes you to Pastronaut's page: tap Paste from Other Apps, choose Allow, then come back.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        case .check:
          OnboardingCard {
            Text("Check that it works")
              .font(.headline)
            InstructionList(items: [
              "Copy a word in another app, such as Notes or Safari.",
              "Come back here. Pastronaut checks by itself, or tap Check Now.",
              "If iPhone asks whether to allow pasting, the setting isn't Allow yet.",
            ])
            if let trial = progress.trial, trial != .saved {
              TrialResult(trial: trial)
                .transition(.opacity)
            }
          }
        case .done:
          OnboardingCard {
            VStack(spacing: 10) {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
              Text("Saved your copy")
                .font(.title3.bold())
              Text("If iPhone didn't ask, everything is set: Pastronaut now saves your latest copy whenever you open it. If it asked, choose Allow in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("tryClipboardResult")
          }
        }
      }
    }
    .animation(.snappy, value: progress.stage)
    .animation(.snappy, value: autoSave)
  }
}

private extension PasteProgress.Stage {
  var index: Int {
    switch self {
    case .allow: 0
    case .check: 1
    case .done: 2
    }
  }
}

/// Three numbered steps in a row; the current one is lit and the finished ones are checked.
private struct ProgressStrip: View {
  let titles: [LocalizedStringKey]
  let current: Int
  let identifiers: [String]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
        let isDone = index < current, isCurrent = index == current
        HStack(spacing: 7) {
          ZStack {
            Circle()
              .fill(isDone ? Color.green : (isCurrent ? Color.accentColor : Color.secondary.opacity(0.25)))
            if isDone {
              Image(systemName: "checkmark")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white)
            } else {
              Text(index + 1, format: .number)
                .font(.caption.weight(.bold))
                .foregroundStyle(isCurrent ? Color.onAccent : Color.secondary)
            }
          }
          .frame(width: 22, height: 22)
          Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          isCurrent ? Color.accentColor.opacity(0.16) : Color(uiColor: .secondarySystemGroupedBackground),
          in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(isDone ? Text("Ready") : (isCurrent ? Text("Now") : Text("Not finished")))
        .accessibilityIdentifier(identifiers[index])
      }
    }
  }
}

private struct TrialResult: View {
  let trial: ClipStore.ClipboardTrial

  var body: some View {
    Label {
      Text(message)
        .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: systemImage)
        .foregroundStyle(color)
    }
    .font(.subheadline)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("tryClipboardResult")
  }

  private var message: LocalizedStringKey {
    switch trial {
    case .saved: "Saved. Pastronaut can read your copies."
    case .empty: "The clipboard has no text. Copy something first."
    case .denied: "iPhone blocked the paste. Set Paste from Other Apps to Allow, then try again."
    case .sensitive: "That copy looks like a code or a card number, so it wasn't saved. Copy something else to try."
    case .tooLarge: "Too large to sync"
    case .ownCopy: "Pastronaut copied that itself, so it doesn't test anything. Copy a word in Notes or Safari, then come back."
    }
  }

  private var systemImage: String {
    switch trial {
    case .saved: "checkmark.circle.fill"
    case .empty, .sensitive, .ownCopy: "info.circle.fill"
    case .denied, .tooLarge: "exclamationmark.triangle.fill"
    }
  }

  private var color: Color {
    switch trial {
    case .saved: .green
    case .empty, .sensitive, .ownCopy: .secondary
    case .denied, .tooLarge: .orange
    }
  }
}

private struct StepPage<Content: View>: View {
  let systemImage: String
  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey
  @ViewBuilder let content: () -> Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 14) {
          Image(systemName: systemImage)
            .font(.system(size: 34, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.accentColor)
            .frame(width: 72, height: 72)
            .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityHidden(true)
          Text(title)
            .font(.largeTitle.bold())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
          Text(subtitle)
            .font(.title3)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        content()
      }
      .padding(.horizontal, 24)
      .padding(.top, 16)
      .padding(.bottom, 24)
      .frame(maxWidth: 560, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
  }
}

private struct OnboardingCard<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14, content: content)
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

private struct FeatureRow: View {
  let systemImage: String
  let title: LocalizedStringKey
  let detail: LocalizedStringKey

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: systemImage)
        .font(.body.weight(.semibold))
        .foregroundStyle(Color.accentColor)
        .frame(width: 28)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        Text(detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

private struct KeyboardTryCard: View {
  let setup: KeyboardSetup
  var isFocused: FocusState<Bool>.Binding
  let openSettings: () -> Void
  @State private var text = ""
  @State private var waitedLong = false

  var body: some View {
    OnboardingCard {
      Text("Open the Pastronaut keyboard once")
        .font(.headline)
      Text("iPhone tells Pastronaut about Full Access only when its keyboard has been on screen.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 10) {
        Image(systemName: "globe")
          .font(.title3)
          .frame(width: 40, height: 40)
          .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          .accessibilityHidden(true)
        Text("Touch and hold the globe key, then choose Pastronaut.")
          .font(.subheadline)
          .fixedSize(horizontal: false, vertical: true)
      }
      if waitedLong {
        Label("No sign of the Pastronaut keyboard yet. If it's open, Full Access is still off: turn it on in Settings.", systemImage: "info.circle.fill")
          .font(.subheadline)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
          .transition(.opacity)
          .accessibilityIdentifier("fullAccessHint")
        Button("Back to Settings", systemImage: "gear", action: openSettings)
          .font(.subheadline.weight(.semibold))
          .buttonStyle(.borderless)
          .accessibilityIdentifier("openKeyboardSettingsAgain")
      } else {
        Label("Waiting for the Pastronaut keyboard…", systemImage: "clock")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      TextField("Tap here to open the keyboard", text: $text)
        .focused(isFocused)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.accentColor, lineWidth: isFocused.wrappedValue ? 0 : 2)
        }
        .accessibilityIdentifier("keyboardTryField")
    }
    .animation(.snappy, value: waitedLong)
    .task(id: isFocused.wrappedValue) {
      guard isFocused.wrappedValue else { return }
      let start = Date()
      while !Task.isCancelled, !setup.hasFullAccess {
        setup.update()
        if !waitedLong, Date().timeIntervalSince(start) > 8 { waitedLong = true }
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }
}

private struct InstructionList: View {
  let items: [LocalizedStringKey]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        HStack(alignment: .top, spacing: 12) {
          Text(index + 1, format: .number)
            .font(.footnote.bold())
            .foregroundStyle(Color.onAccent)
            .frame(width: 24, height: 24)
            .background(Color.accentColor, in: Circle())
            .accessibilityHidden(true)
          Text(item)
            .font(.subheadline)
            .padding(.top, 2)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct PageIndicator: View {
  let current: OnboardingView.Step

  var body: some View {
    HStack(spacing: 8) {
      ForEach(OnboardingView.Step.allCases) { step in
        Capsule()
          .fill(step == current ? Color.accentColor : Color.secondary.opacity(0.3))
          .frame(width: step == current ? 22 : 8, height: 8)
      }
    }
    .animation(.snappy, value: current)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Step \(current.number) of 3"))
  }
}

private struct SettingsMockup<Rows: View>: View {
  let title: Text
  @ViewBuilder let rows: () -> Rows

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        Image(systemName: "chevron.left")
          .foregroundStyle(Color.blue)
        Spacer()
        title
          .fontWeight(.semibold)
          .lineLimit(1)
        Spacer()
        Image(systemName: "chevron.left")
          .hidden()
      }
      .font(.subheadline)
      .padding(.horizontal, 4)
      VStack(spacing: 0, content: rows)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .padding(12)
    .background(Color(uiColor: .systemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
    }
  }
}

private struct MockRow<Accessory: View>: View {
  let icon: SettingsIcon?
  let title: Text
  var isHighlighted = false
  @ViewBuilder let accessory: () -> Accessory

  var body: some View {
    HStack(spacing: 12) {
      if let icon {
        icon
      }
      title
        .font(.subheadline)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      Spacer(minLength: 8)
      accessory()
    }
    .padding(.horizontal, 12)
    .frame(minHeight: 44)
    .background {
      if isHighlighted {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color.accentColor.opacity(0.12))
      }
    }
    .overlay {
      if isHighlighted {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(Color.accentColor, lineWidth: 2)
      }
    }
  }
}

private struct MockChevron: View {
  var value: Text?

  var body: some View {
    HStack(spacing: 6) {
      if let value {
        value
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
  }
}

private struct MockSwitch: View {
  var body: some View {
    Capsule()
      .fill(Color.green)
      .frame(width: 46, height: 28)
      .overlay(alignment: .trailing) {
        Circle()
          .fill(.white)
          .padding(2)
          .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
      }
  }
}

private struct MockDivider: View {
  var body: some View {
    Divider()
      .padding(.leading, 12)
  }
}

private struct MockArrow: View {
  var body: some View {
    Image(systemName: "arrow.down")
      .font(.subheadline.weight(.bold))
      .foregroundStyle(Color.accentColor)
      .frame(maxWidth: .infinity)
  }
}
