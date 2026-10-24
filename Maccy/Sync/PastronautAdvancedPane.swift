import AppKit
import Defaults
import SwiftUI

/// Settings › Advanced in plain words: pause copying, skip the next copy, and Maccy's clear-on-quit switches. The
/// shell commands Maccy shows stay, folded away, for scripts. Replaces Maccy's AdvancedSettingsPane (kept as it
/// is for upstream merges) in the settings window.
struct PastronautAdvancedPane: View {
  @Default(.ignoreEvents) private var isPaused
  @Default(.ignoreOnlyNextEvent) private var skipsNext
  @State private var showsCommands = false

  private static let bundleID = Bundle.main.bundleIdentifier ?? "com.xkbxyberk.pastronaut"

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 8) {
        Toggle(isOn: Binding(get: { isPaused && !skipsNext }, set: { pause in
          skipsNext = false
          isPaused = pause
        })) {
          Text("Pause Copying", tableName: "Pastronaut")
            .font(.headline)
        }
        .toggleStyle(.switch)
        .accessibilityIdentifier("pauseCopying")
        Text("While paused, Pastronaut doesn't save new copies or sync them. Use it while you copy something sensitive, such as a password, then turn it back off.", tableName: "Pastronaut")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if isPaused && !skipsNext {
          Label {
            Text("Paused. The menu bar icon is dimmed until you turn this off.", tableName: "Pastronaut")
          } icon: {
            Image(systemName: "pause.circle.fill")
          }
          .font(.callout)
          .foregroundStyle(.orange)
        }
        HStack(spacing: 10) {
          Button {
            isPaused = true
            skipsNext = true
          } label: {
            Text("Ignore Only the Next Copy", tableName: "Pastronaut")
          }
          .disabled(isPaused)
          .accessibilityIdentifier("ignoreNextCopy")
          if skipsNext {
            Text("The next copy won't be saved.", tableName: "Pastronaut")
              .font(.callout)
              .foregroundStyle(.green)
          }
        }
        Text("Shortcut: Option-click the menu bar icon to pause; Option-Shift-click to skip only the next copy.", tableName: "Pastronaut")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      DisclosureGroup(isExpanded: $showsCommands) {
        VStack(alignment: .leading, spacing: 8) {
          Text("For scripts. The first time, macOS may ask to let Terminal reach Pastronaut's data.", tableName: "Pastronaut")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          CommandRow(command: "defaults write \(Self.bundleID) ignoreEvents true")
          CommandRow(command: "defaults write \(Self.bundleID) ignoreEvents false")
          CommandRow(command: "defaults write \(Self.bundleID) ignoreOnlyNextEvent true")
        }
        .padding(.top, 6)
      } label: {
        // The title opens it too, not only the small triangle.
        Button {
          withAnimation(.snappy) { showsCommands.toggle() }
        } label: {
          Text("Command Line and Automation", tableName: "Pastronaut")
            .font(.callout.weight(.semibold))
        }
        .buttonStyle(.plain)
      }
      .accessibilityIdentifier("commandLineSection")

      Divider()

      VStack(alignment: .leading, spacing: 10) {
        Defaults.Toggle(key: .clearOnQuit) {
          VStack(alignment: .leading, spacing: 2) {
            Text("ClearHistoryOnQuit", tableName: "AdvancedSettings")
            Text("Pinned items and items in collections stay.", tableName: "Pastronaut")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
        Defaults.Toggle(key: .clearSystemClipboard) {
          VStack(alignment: .leading, spacing: 2) {
            Text("ClearSystemClipboard", tableName: "AdvancedSettings")
            Text("Clearing the history also empties the clipboard.", tableName: "Pastronaut")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .frame(minWidth: 350, maxWidth: 450, alignment: .leading)
    .padding()
  }
}

/// A shell command with a button that copies it.
private struct CommandRow: View {
  let command: String
  @State private var copied = false

  var body: some View {
    HStack(spacing: 8) {
      Text(verbatim: command)
        .font(.system(size: 11, design: .monospaced))
        .textSelection(.enabled)
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copied = true
        Task {
          try? await Task.sleep(for: .seconds(1.5))
          copied = false
        }
      } label: {
        if copied {
          Text("Copied", tableName: "Pastronaut")
        } else {
          Text("Copy", tableName: "Pastronaut")
        }
      }
      .controlSize(.small)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
  }
}

#Preview {
  PastronautAdvancedPane()
    .environment(\.locale, .init(identifier: "en"))
}
