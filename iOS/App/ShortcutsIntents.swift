import AppIntents
import PastronautCore

/// Shortcuts: the newest clip, from all devices or one of them. Reading needs an unlocked iPhone.
struct GetLatestClipIntent: AppIntent {
  static let title: LocalizedStringResource = "Get Latest Clip"
  static let description = IntentDescription("Returns the text of your most recent clip.")
  static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

  @Parameter(title: "From", default: .all)
  var source: ClipSourceOption

  static var parameterSummary: some ParameterSummary {
    Summary("Get latest clip from \(\.$source)")
  }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let clip = source.source.latest(from: ClipClipboard.clips, count: 1).first else {
      return .result(value: "", dialog: "There are no clips yet.")
    }
    return .result(value: clip.text, dialog: IntentDialog(stringLiteral: clip.preview))
  }
}

/// Shortcuts: several recent clips as a list.
struct GetRecentClipsIntent: AppIntent {
  static let title: LocalizedStringResource = "Get Recent Clips"
  static let description = IntentDescription("Returns your most recent clips, newest first.")
  static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

  @Parameter(title: "Count", default: 5, inclusiveRange: (1, 50))
  var count: Int

  @Parameter(title: "From", default: .all)
  var source: ClipSourceOption

  static var parameterSummary: some ParameterSummary {
    Summary("Get \(\.$count) recent clips from \(\.$source)")
  }

  func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
    .result(value: source.source.latest(from: ClipClipboard.clips, count: count).map(\.text))
  }
}

/// Shortcuts, Siri and the Action button: put the newest clip on the clipboard without opening the app.
struct CopyLatestClipIntent: AppIntent {
  static let title: LocalizedStringResource = "Copy Latest Clip"
  static let description = IntentDescription("Copies your most recent clip, for example the last one from your Mac.")
  static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

  @Parameter(title: "From", default: .mac)
  var source: ClipSourceOption

  static var parameterSummary: some ParameterSummary {
    Summary("Copy latest clip from \(\.$source)")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let clip = source.source.latest(from: ClipClipboard.clips, count: 1).first else {
      return .result(dialog: "There are no clips yet.")
    }
    ClipClipboard.copy(clip.text)
    return .result(dialog: "Copied: \(clip.preview)")
  }
}

struct PastronautShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: CopyLatestClipIntent(),
      phrases: [
        "Copy my latest Mac clip with \(.applicationName)",
        "Copy the latest clip with \(.applicationName)"
      ],
      shortTitle: "Copy Latest Clip",
      systemImageName: "doc.on.doc"
    )
    AppShortcut(
      intent: SaveClipboardIntent(),
      phrases: [
        "Save my clipboard to \(.applicationName)",
        "Save clipboard in \(.applicationName)"
      ],
      shortTitle: "Save Clipboard",
      systemImageName: "square.and.arrow.down"
    )
    AppShortcut(
      intent: GetLatestClipIntent(),
      phrases: ["Get my latest clip from \(.applicationName)"],
      shortTitle: "Get Latest Clip",
      systemImageName: "text.alignleft"
    )
  }
}
