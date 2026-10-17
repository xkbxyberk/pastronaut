import AppKit
import Defaults
import SwiftUI

extension Defaults.Keys {
  static let onboardingShown = Key<Bool>("pastronautOnboardingShown", default: false)
}

/// Welcome window shown once on first launch: what Pastronaut adds to Maccy, the iCloud switch and the
/// iPhone app. Can be reopened from Sync settings.
@MainActor
enum OnboardingWindow {
  private static var window: NSWindow?

  static func showIfNeeded() {
    guard !Defaults[.onboardingShown] else { return }
    Defaults[.onboardingShown] = true
    show()
  }

  static func show() {
    if let window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 600),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: OnboardingView { window.close() })
    window.center()
    self.window = window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}

private struct OnboardingView: View {
  let close: () -> Void
  @Default(.iCloudSync) private var isSyncEnabled

  var body: some View {
    VStack(spacing: 20) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)
      VStack(spacing: 6) {
        Text("Welcome to Pastronaut", tableName: "Pastronaut")
          .font(.title.bold())
        Text("Your Mac clipboard history, on your iPhone too.", tableName: "Pastronaut")
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.center)

      VStack(alignment: .leading, spacing: 14) {
        feature("iphone.and.arrow.forward",
                Text("Copy on your Mac, then type it on your iPhone with one tap on the Pastronaut keyboard.", tableName: "Pastronaut"))
        feature("arrow.down.left.and.arrow.up.right",
                Text("Copies you save on your iPhone show up here, marked with an iPhone.", tableName: "Pastronaut"))
        feature("lock",
                Text("Everything stays in your own iCloud, and the text of your clips is encrypted on this Mac before it's uploaded.", tableName: "Pastronaut"))
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Toggle(isOn: $isSyncEnabled) {
        Text("Sync history with iCloud", tableName: "Pastronaut")
          .font(.headline)
      }
      .toggleStyle(.switch)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

      HStack(spacing: 14) {
        if let qr = QRCode.image(for: "https://github.com/xkbxyberk/pastronaut", size: 72) {
          Image(nsImage: qr)
            .interpolation(.none)
            .resizable()
            .frame(width: 72, height: 72)
            .padding(5)
            .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(Text("QR code", tableName: "Pastronaut"))
        }
        VStack(alignment: .leading, spacing: 3) {
          Text("Get the iPhone app", tableName: "Pastronaut").font(.headline)
          Text("Scan with your iPhone's camera. The app walks you through setting up the keyboard.", tableName: "Pastronaut")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Spacer(minLength: 0)

      HStack {
        Button {
          close()
          AppState.shared.openPreferences(pane: "sync")
        } label: {
          Text("Sync Settings…", tableName: "Pastronaut")
        }
        .modifier(GlassButton(prominent: false))
        Spacer()
        Button {
          close()
        } label: {
          Text("Done", tableName: "Pastronaut")
            .frame(minWidth: 70)
        }
        .keyboardShortcut(.defaultAction)
        .modifier(GlassButton(prominent: true))
      }
    }
    .padding(28)
    .padding(.top, 8)
    .frame(width: 460, height: 600)
  }

  private func feature(_ symbol: String, _ text: Text) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .font(.title3)
        .foregroundStyle(Color.brand)
        .frame(width: 28)
        .accessibilityHidden(true)
      text
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// Glass buttons on macOS 26 and later, standard bordered ones before.
private struct GlassButton: ViewModifier {
  let prominent: Bool

  func body(content: Content) -> some View {
    if #available(macOS 26.0, *) {
      if prominent {
        content.buttonStyle(.glassProminent)
      } else {
        content.buttonStyle(.glass)
      }
    } else if prominent {
      content.buttonStyle(.borderedProminent)
    } else {
      content.buttonStyle(.bordered)
    }
  }
}
