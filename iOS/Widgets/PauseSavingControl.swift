import AppIntents
import PastronautCore
import SwiftUI
import WidgetKit

/// Control Center, Lock Screen and Action button: pauses automatic saving for an hour, or resumes it.
@available(iOS 18.0, *)
struct PauseSavingControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: PauseSavingIntent.controlKind, provider: PausedValue()) { isPaused in
      ControlWidgetToggle("Pause Saving", isOn: isPaused, action: PauseSavingIntent()) { isOn in
        Label(isOn ? "Paused" : "Saving", systemImage: isOn ? "pause.fill" : "doc.on.clipboard")
      }
    }
    .displayName("Pause Saving")
    .description("Pastronaut stops saving the clipboard by itself for an hour.")
  }
}

@available(iOS 18.0, *)
private struct PausedValue: ControlValueProvider {
  var previewValue: Bool { false }

  func currentValue() async throws -> Bool {
    SavingPause.isPaused(in: SharedSettings.defaults)
  }
}
