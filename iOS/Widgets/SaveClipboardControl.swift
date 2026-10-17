import AppIntents
import SwiftUI
import WidgetKit

/// Control Center, Lock Screen and Action button: opens Pastronaut, which saves the clipboard.
@available(iOS 18.0, *)
struct SaveClipboardControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "com.xkbxyberk.pastronaut.save-clipboard") {
      ControlWidgetButton(action: SaveClipboardIntent()) {
        Label("Save Clipboard", systemImage: "square.and.arrow.down.on.square")
      }
    }
    .displayName("Save Clipboard")
    .description("Saves what you copied to Pastronaut.")
  }
}
