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

/// Shortcuts: several recent clips as a list, from all clips or one collection.
struct GetRecentClipsIntent: AppIntent {
  static let title: LocalizedStringResource = "Get Recent Clips"
  static let description = IntentDescription("Returns your most recent clips, newest first.")
  static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

  @Parameter(title: "Count", default: 5, inclusiveRange: (1, 50))
  var count: Int

  @Parameter(title: "From", default: .all)
  var source: ClipSourceOption

  @Parameter(title: "Collection")
  var collection: CollectionEntity?

  static var parameterSummary: some ParameterSummary {
    Summary("Get \(\.$count) recent clips from \(\.$source)") {
      \.$collection
    }
  }

  func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
    .result(value: source.latest(in: collection, count: count).map(\.text))
  }
}

/// Shortcuts: one clip by its place in the list, 1 being the newest ("the third clip from my Mac").
struct GetClipIntent: AppIntent {
  static let title: LocalizedStringResource = "Get Clip"
  static let description = IntentDescription("Returns the clip at a position in your history: 1 is the newest, 2 the one before it.")
  static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

  @Parameter(title: "Position", default: 1, inclusiveRange: (1, 50))
  var position: Int

  @Parameter(title: "From", default: .all)
  var source: ClipSourceOption

  @Parameter(title: "Collection")
  var collection: CollectionEntity?

  static var parameterSummary: some ParameterSummary {
    Summary("Get clip \(\.$position) from \(\.$source)") {
      \.$collection
    }
  }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let clips = source.latest(in: collection, count: position)
    guard clips.count == position, let clip = clips.last else {
      return .result(value: "", dialog: "There is no clip at that position.")
    }
    return .result(value: clip.text, dialog: IntentDialog(stringLiteral: clip.preview))
  }
}

/// Shortcuts: save text into a collection ("Get Clipboard" → "Add to Collection"). New text is also saved to
/// the history, like "Save to Pastronaut"; text already there keeps its pin and joins the collection.
struct AddToCollectionIntent: AppIntent {
  static let title: LocalizedStringResource = "Add to Collection"
  static let description = IntentDescription("Saves text to your Pastronaut history and adds it to a collection.")

  @Parameter(title: "Text", inputOptions: String.IntentInputOptions(multiline: true))
  var text: String

  @Parameter(title: "Collection")
  var collection: CollectionEntity

  static var parameterSummary: some ParameterSummary {
    Summary("Add \(\.$text) to \(\.$collection)")
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    switch await ClipStore.shared.saveNow(text, to: collection.id) {
    case .saved:
      return .result(dialog: "Added to \(collection.name).")
    case .empty:
      return .result(dialog: "There was no text to save.")
    case .tooLarge:
      return .result(dialog: "This text is too large to sync, so it was not saved.")
    }
  }
}

/// Shortcuts, Siri and the Action button: put the newest clip on the clipboard without opening the app.
struct CopyLatestClipIntent: AppIntent {
  static let title: LocalizedStringResource = "Copy Latest Clip"
  static let description = IntentDescription("Copies your most recent clip, for example the last one from your computer.")
  static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

  @Parameter(title: "From", default: .computer)
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
        "Copy the latest clip from my computer with \(.applicationName)",
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
