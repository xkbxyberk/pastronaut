import AppIntents

/// Shortcuts action. Typical use: "Get Clipboard" → "Save to Pastronaut", bound to Back Tap or the
/// Action button. Taking the text as a parameter lets Shortcuts read the clipboard, so this app shows
/// no paste prompt of its own.
struct SaveTextIntent: AppIntent {
  static let title: LocalizedStringResource = "Save to Pastronaut"
  static let description = IntentDescription(
    "Adds text to your Pastronaut history and syncs it to your Mac. Use it after Get Clipboard."
  )

  @Parameter(title: "Text", inputOptions: String.IntentInputOptions(multiline: true))
  var text: String

  static var parameterSummary: some ParameterSummary {
    Summary("Save \(\.$text) to Pastronaut")
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    switch await ClipStore.shared.saveNow(text) {
    case .saved:
      return .result(dialog: "Saved to Pastronaut.")
    case .empty:
      return .result(dialog: "There was no text to save.")
    case .tooLarge:
      return .result(dialog: "This text is too large to sync, so it was not saved.")
    }
  }
}
