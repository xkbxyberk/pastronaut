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
  @State private var step: Step
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
        KeyboardStep(setup: setup, openSettings: openSettings)
          .tag(Step.keyboard)
        PasteStep(openSettings: openSettings)
          .tag(Step.paste)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      footer
    }
    .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    .onAppear { setup.update() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { setup.update() }
    }
  }

  private var footer: some View {
    VStack(spacing: 16) {
      PageIndicator(current: step)
      Button(action: advance) {
        Text(primaryTitle)
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 4)
      }
      .primaryActionStyle()
      .controlSize(.large)
      .accessibilityIdentifier("onboardingNext")
    }
    .padding(.horizontal, 24)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .frame(maxWidth: 560)
  }

  private var primaryTitle: LocalizedStringKey {
    guard step.next == nil else { return "Continue" }
    return presentation == .firstLaunch ? "Start Using Pastronaut" : "Done"
  }

  private func advance() {
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
  let openSettings: () -> Void

  var body: some View {
    StepPage(
      systemImage: "keyboard.fill",
      title: "Add the Pastronaut keyboard",
      subtitle: "Type what you copied on your Mac with a single tap, in any app."
    ) {
      OnboardingCard {
        StatusRow(title: "Keyboard", progress: setup.isKeyboardAdded ? .done : .notStarted)
          .accessibilityIdentifier("setupStep1")
        Divider()
        StatusRow(
          title: "Full Access",
          progress: setup.hasFullAccess ? .done : (setup.isKeyboardAdded ? .needsKeyboardCheck : .notStarted)
        )
        .accessibilityIdentifier("setupStep2")
      }

      VStack(spacing: 10) {
        SettingsMockup(title: Text(verbatim: "Pastronaut")) {
          MockRow(icon: SettingsIcon(systemImage: "keyboard", color: .gray), title: Text("Keyboards"), isHighlighted: true) {
            MockChevron()
          }
          MockDivider()
          MockRow(icon: SettingsIcon(systemImage: "doc.on.clipboard", color: .gray), title: Text("Paste from Other Apps")) {
            MockChevron(value: Text("Ask"))
          }
        }
        MockArrow()
        SettingsMockup(title: Text("Keyboards")) {
          MockRow(icon: nil, title: Text(verbatim: "Pastronaut")) {
            MockSwitch()
          }
          MockDivider()
          MockRow(icon: nil, title: Text("Allow Full Access"), isHighlighted: true) {
            MockSwitch()
          }
        }
      }
      .accessibilityHidden(true)

      InstructionList(items: [
        "Tap Open Settings below.",
        "Choose Keyboards.",
        "Turn on Pastronaut, then Allow Full Access.",
        "Come back and open the Pastronaut keyboard once in the field below.",
      ])

      OpenSettingsButton(action: openSettings)
        .accessibilityIdentifier("openKeyboardSettings")

      KeyboardTryCard(setup: setup)

      OnboardingCard {
        Label("Why Full Access?", systemImage: "checkmark.shield.fill")
          .font(.headline)
          .foregroundStyle(Color.accentColor)
        Text("With Full Access, the keyboard saves your new copies itself and fetches the latest history from iCloud, even when the app is closed.")
          .font(.subheadline)
          .fixedSize(horizontal: false, vertical: true)
        Text("Without it, the keyboard still works and types your history as of the last time you opened Pastronaut.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Label {
          Text("Even with Full Access, nothing you type is sent anywhere. The keyboard only reads your history in your own iCloud and writes the copies you capture there.")
        } icon: {
          Image(systemName: "lock")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct PasteStep: View {
  let openSettings: () -> Void
  @AppStorage(AutoCapture.settingKey, store: UserDefaults(suiteName: PastronautIDs.appGroup))
  private var autoSave = true
  @State private var trial: ClipStore.ClipboardTrial?
  @State private var isTrying = false

  var body: some View {
    StepPage(
      systemImage: "doc.on.clipboard.fill",
      title: "Paste without being asked",
      subtitle: "Pastronaut saves your new copy each time you open it. Allow pasting once, and iPhone stops asking for permission every time."
    ) {
      VStack(spacing: 10) {
        SettingsMockup(title: Text(verbatim: "Pastronaut")) {
          MockRow(icon: SettingsIcon(systemImage: "keyboard", color: .gray), title: Text("Keyboards")) {
            MockChevron()
          }
          MockDivider()
          MockRow(icon: SettingsIcon(systemImage: "doc.on.clipboard", color: .gray), title: Text("Paste from Other Apps"), isHighlighted: true) {
            MockChevron(value: Text("Ask"))
          }
        }
        MockArrow()
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
      }
      .accessibilityHidden(true)

      InstructionList(items: [
        "Tap Open Settings below.",
        "Choose Paste from Other Apps.",
        "Select Allow.",
      ])

      OpenSettingsButton(action: openSettings)
        .accessibilityIdentifier("openPasteSettings")

      OnboardingCard {
        Label("Try it", systemImage: "wand.and.sparkles")
          .font(.headline)
          .foregroundStyle(Color.accentColor)
        Text("Copy some text in another app, come back and tap Try Saving. If iPhone still asks, the setting isn't Allow yet.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Button {
          Task {
            isTrying = true
            trial = await ClipStore.shared.trySavingClipboard()
            isTrying = false
          }
        } label: {
          Label("Try Saving", systemImage: "doc.on.clipboard")
            .frame(maxWidth: .infinity)
        }
        .primaryActionStyle()
        .controlSize(.large)
        .disabled(isTrying)
        .accessibilityIdentifier("tryClipboardSave")
        if let trial {
          TrialResult(trial: trial)
            .transition(.opacity)
        }
      }
      .animation(.snappy, value: trial)

      OnboardingCard {
        Toggle(isOn: $autoSave) {
          Label {
            Text("Save Clipboard on Opening")
          } icon: {
            SettingsIcon(systemImage: "doc.on.clipboard", color: .orange)
          }
        }
        .accessibilityIdentifier("onboardingAutoSaveToggle")
        Text("iPhone keeps only your latest copy. When you copy several things in a row, open Pastronaut or its keyboard in between, or share them to Pastronaut. One-time codes, card numbers and IBANs are never saved this way.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
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
    }
  }

  private var systemImage: String {
    switch trial {
    case .saved: "checkmark.circle.fill"
    case .empty, .sensitive: "info.circle.fill"
    case .denied, .tooLarge: "exclamationmark.triangle.fill"
    }
  }

  private var color: Color {
    switch trial {
    case .saved: .green
    case .empty, .sensitive: .secondary
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
  @State private var text = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    OnboardingCard {
      Label("Try the keyboard", systemImage: "character.cursor.ibeam")
        .font(.headline)
        .foregroundStyle(Color.accentColor)
      Text("Tap the field, then switch to Pastronaut with the globe key. Opening it once here also confirms Full Access.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      TextField("Tap here to open the keyboard", text: $text)
        .focused($isFocused)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("keyboardTryField")
      if setup.hasFullAccess {
        Label("Full Access is on.", systemImage: "checkmark.circle.fill")
          .font(.subheadline)
          .foregroundStyle(.green)
          .transition(.opacity)
          .accessibilityIdentifier("fullAccessConfirmed")
      }
    }
    .animation(.snappy, value: setup.hasFullAccess)
    .task(id: isFocused) {
      guard isFocused else { return }
      while !Task.isCancelled, !setup.hasFullAccess {
        setup.update()
        try? await Task.sleep(for: .seconds(1))
      }
    }
    .onChange(of: setup.hasFullAccess) { _, hasFullAccess in
      if hasFullAccess { Haptics.success() }
    }
  }
}

private struct StatusRow: View {
  enum Progress {
    case done
    case needsKeyboardCheck
    case notStarted
  }

  let title: LocalizedStringKey
  let progress: Progress

  var body: some View {
    HStack {
      Text(title)
        .fontWeight(.semibold)
      Spacer()
      switch progress {
      case .done:
        Label("Ready", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
      case .needsKeyboardCheck:
        Label("Open the keyboard once", systemImage: "hand.point.up.left.fill")
          .foregroundStyle(.orange)
      case .notStarted:
        Text("Not finished")
          .foregroundStyle(.secondary)
      }
    }
    .font(.subheadline)
    .accessibilityElement(children: .combine)
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

private struct OpenSettingsButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label("Open Settings", systemImage: "gear")
        .font(.headline)
        .frame(maxWidth: .infinity)
    }
    .secondaryActionStyle()
    .controlSize(.large)
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
