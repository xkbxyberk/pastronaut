import PastronautCore
import SwiftUI
import UIKit

/// Live state of the keyboard setup, re-read whenever the app comes back from Settings.
@MainActor
@Observable
final class KeyboardSetup {
  static let shared = KeyboardSetup()
  static let keyboardBundleID = "com.xkbxyberk.pastronaut.keyboard"
  /// Written by the keyboard each time it appears with Full Access (it cannot write the App Group without it).
  static let fullAccessSeenKey = "keyboardFullAccessSeenAt"

  private(set) var isKeyboardAdded = false
  private(set) var hasFullAccess = false

  var isComplete: Bool { isKeyboardAdded && hasFullAccess }

  func update() {
    // The system's list of enabled keyboards, readable by any app.
    let keyboards = UserDefaults.standard.stringArray(forKey: "AppleKeyboards") ?? []
    isKeyboardAdded = keyboards.contains(Self.keyboardBundleID)
    hasFullAccess = UserDefaults(suiteName: PastronautIDs.appGroup)?.object(forKey: Self.fullAccessSeenKey) != nil
  }
}

struct KeyboardSetupView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase
  private let setup = KeyboardSetup.shared
  /// Shown as a sheet on first launch (with a "Later" button), or pushed from Settings.
  var isSheet = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Step \(currentStep) of 3")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
          Text("Set up the Pastronaut keyboard")
            .font(.largeTitle.bold())
          Text("Type what you copied on your Mac with a single tap on iPhone.")
            .foregroundStyle(.secondary)
        }

        StepCard(number: 1, state: setup.isKeyboardAdded ? .done : .current,
                 title: "Add the keyboard",
                 detail: setup.isKeyboardAdded ? "Added" : "Settings › General › Keyboard › Keyboards › Add New Keyboard › Pastronaut") {
          if !setup.isKeyboardAdded { openSettingsButton }
        }
        .accessibilityIdentifier("setupStep1")

        StepCard(number: 2, state: setup.hasFullAccess ? .done : (setup.isKeyboardAdded ? .current : .upcoming),
                 title: "Turn on Full Access",
                 detail: setup.hasFullAccess
                   ? "On"
                   : "Lets the keyboard save new copies and fetch the latest history from iCloud itself. Tap Pastronaut under Keyboards and turn on Allow Full Access, then open the keyboard once.") {
          if setup.isKeyboardAdded && !setup.hasFullAccess { openSettingsButton }
        }
        .accessibilityIdentifier("setupStep2")

        StepCard(number: 3, state: setup.isComplete ? .current : .upcoming,
                 title: "Add the shortcut (optional)",
                 detail: "In Shortcuts, make a shortcut with “Get Clipboard” and “Save to Pastronaut”. Add it to Back Tap or the Action button to save with one gesture.") {
          if setup.isComplete {
            Button {
              if let url = URL(string: "shortcuts://") { openURL(url) }
            } label: {
              Label("Open Shortcuts", systemImage: "square.2.layers.3d")
            }
            .secondaryActionStyle()
          }
        }

        IPhoneLimitsCard()

        Label {
          Text("Even with Full Access, nothing you type is sent anywhere. The keyboard only reads your history in your own iCloud and writes the copies you capture there.")
        } icon: {
          Image(systemName: "lock")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
      .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .toolbar {
      if isSheet {
        ToolbarItem(placement: .confirmationAction) {
          Button(setup.isComplete ? "Done" : "Later") { dismiss() }
            .accessibilityIdentifier("setupDone")
        }
      }
    }
    .onAppear { setup.update() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { setup.update() }
    }
  }

  private var currentStep: Int {
    setup.isComplete ? 3 : (setup.isKeyboardAdded ? 2 : 1)
  }

  private var openSettingsButton: some View {
    Button {
      if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    } label: {
      Label("Open Settings", systemImage: "gear")
    }
    .primaryActionStyle()
  }
}

private struct StepCard<Actions: View>: View {
  enum State { case done, current, upcoming }

  let number: Int
  let state: State
  let title: LocalizedStringKey
  let detail: LocalizedStringKey
  @ViewBuilder let actions: () -> Actions

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      badge
      VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.headline)
        Text(detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        actions()
      }
      Spacer(minLength: 0)
    }
    .padding(16)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      if state == .current {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .strokeBorder(Color.accentColor, lineWidth: 2)
      }
    }
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var badge: some View {
    switch state {
    case .done:
      Image(systemName: "checkmark.circle.fill")
        .font(.title2)
        .foregroundStyle(.green)
        .accessibilityLabel(Text("Done"))
    case .current:
      Text(number, format: .number)
        .font(.subheadline.bold())
        .foregroundStyle(Color.onAccent)
        .frame(width: 28, height: 28)
        .background(Color.accentColor, in: Circle())
    case .upcoming:
      Text(number, format: .number)
        .font(.subheadline.bold())
        .foregroundStyle(.secondary)
        .frame(width: 28, height: 28)
        .overlay(Circle().strokeBorder(.secondary, lineWidth: 1.5))
    }
  }
}

/// What syncs by itself and what needs a tap: iPhone lets only the app in front read the clipboard, so copies
/// made on the iPhone are saved through one of these doors. Said plainly so nobody waits for an automatic sync
/// that iOS doesn't allow.
private struct IPhoneLimitsCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("What to expect on iPhone")
        .font(.headline)
      row("laptopcomputer.and.arrow.down", "From your Mac: automatic",
          "Everything you copy on your Mac appears here and in the keyboard, without opening anything.")
      row("hand.tap", "From your iPhone: one tap",
          "iPhone doesn't let apps read the clipboard in the background, so save a copy in one of these ways:")
      VStack(alignment: .leading, spacing: 6) {
        bullet("Open Pastronaut: with “Save Clipboard on Opening” on, it saves what you copied.")
        bullet("In the keyboard, tap Paste when it offers the new copy.")
        bullet("Use the Save Clipboard button in Control Center, Back Tap or the Action button.")
        bullet("Share text to Pastronaut from any app.")
      }
      .padding(.leading, 34)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("iphoneLimits")
  }

  private func row(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .font(.body.weight(.semibold))
        .foregroundStyle(Color.accentColor)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.subheadline.weight(.semibold))
        Text(detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func bullet(_ text: LocalizedStringKey) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(verbatim: "•")
      Text(text)
        .fixedSize(horizontal: false, vertical: true)
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
  }
}
