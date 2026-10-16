import UIKit
import XCTest

/// One step of the two-device sync test. `scripts/e2e/sync_e2e.py` runs `testStep` once per step and
/// passes parameters as `TEST_RUNNER_PT_*` environment variables, which xcodebuild hands to this runner
/// without the prefix. Each step prints one `PTEST-RESULT {json}` line.
///
/// Waits never pull to refresh: a change that shows up while the app is open arrived by push.
final class SyncStepTests: XCTestCase {
  private let env = ProcessInfo.processInfo.environment
  private let app = XCUIApplication()

  private var text: String { env["PT_TEXT"] ?? "" }
  /// Rows are found by this substring; defaults to the whole text. Lets multi-line texts be matched.
  private var match: String { env["PT_MATCH"].flatMap { $0.isEmpty ? nil : $0 } ?? text }
  private var timeout: TimeInterval { TimeInterval(env["PT_TIMEOUT"] ?? "") ?? 30 }

  override func setUp() {
    continueAfterFailure = false
    // Keeps the first-launch setup guide from covering the list (Debug builds only).
    app.launchEnvironment["PT_E2E"] = "1"
  }

  func testStep() throws {
    let op = env["PT_OP"] ?? ""
    switch op {
    case "launch":
      app.launch()
      report(["ok": app.wait(for: .runningForeground, timeout: 10), "rows": rows.count])
    case "count":
      app.activate()
      report(["ok": true, "rows": rows.count, "texts": rows.allElementsBoundByIndex.prefix(200).map(\.label)])
    case "waitVisible":
      wait(until: { $0.exists })
    case "waitGone":
      wait(until: { !$0.exists })
    case "waitPinned":
      wait(until: { $0.exists && $0.identifier == "clip.pinned" })
    case "waitUnpinned":
      wait(until: { $0.exists && $0.identifier == "clip.unpinned" })
    case "save":
      // The system Paste button rejects synthetic taps, so the app saves this text at launch (Debug only).
      app.launchEnvironment["PT_E2E_SAVE"] = text
      app.launch()
      report(["ok": row(match).waitForExistence(timeout: 15)])
    case "keyboardSave":
      // Runs the keyboard's direct upload inside the app (Debug only): the keyboard's Paste button
      // cannot be tapped by a test.
      app.launchEnvironment["PT_E2E_KEYBOARD_SAVE"] = text
      app.launch()
      Thread.sleep(forTimeInterval: 6)
      report(["ok": true])
    case "waitCount":
      app.activate()
      let start = Date()
      let expected = Int(text) ?? 0
      while rows.count < expected, Date().timeIntervalSince(start) < timeout {
        Thread.sleep(forTimeInterval: 1)
      }
      report(["ok": rows.count >= expected, "rows": rows.count, "seconds": Date().timeIntervalSince(start).rounded()])
    case "pin", "unpin":
      let element = try existingRow()
      element.swipeRight()
      // Identifiers, not labels: the app follows the device language.
      let button = app.buttons["pinAction"].firstMatch
      XCTAssertTrue(button.waitForExistence(timeout: 5), "\(op) action missing")
      button.tap()
      let expected = op == "pin" ? "clip.pinned" : "clip.unpinned"
      report(["ok": waitIdentifier(of: row(match), equals: expected)])
    case "delete":
      let element = try existingRow()
      element.swipeLeft()
      let button = app.buttons["deleteAction"].firstMatch
      XCTAssertTrue(button.waitForExistence(timeout: 5), "delete action missing")
      button.tap()
      report(["ok": element.waitForNonExistence(timeout: 5)])
    case "copy":
      try existingRow().tap()
      report(["ok": UIPasteboard.general.string == text])
    case "background":
      app.activate()
      XCUIDevice.shared.press(.home)
      report(["ok": app.wait(for: .runningBackgroundSuspended, timeout: 15) || app.state == .runningBackground])
    case "status":
      app.activate()
      app.buttons["settingsButton"].firstMatch.tap()
      let error = app.staticTexts["syncError"]
      let synced = app.descendants(matching: .any)["syncedClips"].firstMatch
      // The sheet sits over the history screen, so both navigation bars exist; report every title.
      let titles = app.navigationBars.allElementsBoundByIndex.map(\.identifier)
      report([
        "ok": true,
        "error": error.waitForExistence(timeout: 2) ? error.label : "",
        "synced": synced.exists ? synced.label : "?",
        // Shows which language the app runs in ("Ayarlar" on a Turkish device).
        "titles": titles
      ])
      app.buttons["doneButton"].firstMatch.tap()
    case "screenshot":
      // Design review: the history screen, then the first clip's details. Attachments land in the result bundle.
      app.launch()
      Thread.sleep(forTimeInterval: 2)
      attachScreenshot(named: "history")
      let first = rows.firstMatch
      if first.waitForExistence(timeout: 5) {
        first.press(forDuration: 1.0)
        let details = app.buttons["showDetails"].firstMatch
        if details.waitForExistence(timeout: 3) {
          details.tap()
          Thread.sleep(forTimeInterval: 1)
          attachScreenshot(named: "detail")
        }
      }
      // Settings and the keyboard setup guide, from a fresh launch (the detail screen is still pushed).
      app.terminate()
      app.launch()
      Thread.sleep(forTimeInterval: 1)
      app.navigationBars.buttons.matching(identifier: "settingsButton").firstMatch.tap()
      Thread.sleep(forTimeInterval: 1)
      attachScreenshot(named: "settings")
      let setupRow = app.descendants(matching: .any)["setupKeyboard"].firstMatch
      if setupRow.waitForExistence(timeout: 3) {
        setupRow.tap()
        Thread.sleep(forTimeInterval: 1)
        attachScreenshot(named: "setup")
      }
      report(["ok": true])
    case "keyboardShots":
      // Design review of the keyboard, in this app's own search field (Safari could show the user's pages).
      // Ends in dark mode, this device's usual appearance ("unspecified" cannot be restored).
      defer { XCUIDevice.shared.appearance = .dark }
      for (name, appearance) in [("light", XCUIDevice.Appearance.light), ("dark", .dark)] {
        XCUIDevice.shared.appearance = appearance
        app.terminate()
        app.launch()
        let search = app.searchFields.firstMatch
        guard search.waitForExistence(timeout: 5) else { break }
        search.tap()
        guard showPastronautKeyboard(in: app) else {
          report(["ok": false, "reason": "keyboard not shown"])
          return
        }
        Thread.sleep(forTimeInterval: 2)
        attachScreenshot(named: "kb-\(name)")
        let searchKey = app.descendants(matching: .any)["searchKey"].firstMatch
        if searchKey.exists {
          searchKey.tap()
          for letter in ["k", "l"] {
            app.descendants(matching: .any)["letter.\(letter)"].firstMatch.tap()
          }
          Thread.sleep(forTimeInterval: 1)
          attachScreenshot(named: "kb-search-\(name)")
          app.descendants(matching: .any)["searchDone"].firstMatch.tap()
        }
        let row = app.descendants(matching: .any)["kbClip"].firstMatch
        if row.exists {
          row.press(forDuration: 0.8)
          Thread.sleep(forTimeInterval: 1)
          attachScreenshot(named: "kb-actions-\(name)")
        }
      }
      report(["ok": true])
    case "keyboardAction":
      // Long press a clip in the keyboard (Safari's address bar, app not opened) and pin/unpin or delete it.
      let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
      safari.launch()
      let address = safari.textFields.firstMatch
      if address.waitForExistence(timeout: 5) { address.tap() }
      guard showPastronautKeyboard(in: safari) else {
        report(["ok": false, "reason": "keyboard not shown"])
        return
      }
      let row = safari.descendants(matching: .any)
        .matching(NSPredicate(format: "identifier == 'kbClip' AND label CONTAINS %@", match)).firstMatch
      guard row.waitForExistence(timeout: 10) else {
        report(["ok": false, "reason": "clip not in keyboard"])
        return
      }
      row.press(forDuration: 0.8)
      let action = env["PT_ACTION"] ?? "pin"
      let button = safari.descendants(matching: .any)["clipAction.\(action)"].firstMatch
      guard button.waitForExistence(timeout: 3) else {
        report(["ok": false, "reason": "no \(action) action"])
        return
      }
      button.tap()
      if action == "delete" { button.tap() }  // Second tap confirms.
      let status = safari.descendants(matching: .any)["cloudStatus"].firstMatch
      let deadline = Date().addingTimeInterval(15)
      while Date() < deadline, !(status.exists && ["pinned", "deleted", "failed"].contains(where: status.label.contains)) {
        Thread.sleep(forTimeInterval: 0.5)
      }
      report(["ok": status.exists && !status.label.contains("failed"), "cloudStatus": status.exists ? status.label : ""])
    case "keyboard":
      try keyboardStep()
    default:
      XCTFail("Unknown step \(op)")
    }
  }

  // MARK: - Rows

  private var rows: XCUIElementQuery {
    // "clip.pinned" or "clip.unpinned" (HistoryView).
    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'clip.'"))
  }

  private func row(_ text: String) -> XCUIElement {
    rows.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
  }

  private func existingRow() throws -> XCUIElement {
    app.activate()
    let row = row(match)
    guard row.waitForExistence(timeout: timeout) else {
      report(["ok": false, "reason": "row missing"])
      throw XCTSkip("row missing")
    }
    return row
  }

  /// Waits for a row condition with the app in the foreground and reports how long it took.
  private func wait(until condition: @escaping (XCUIElement) -> Bool) {
    app.activate()
    let start = Date()
    print("PTEST-READY")
    let target = row(match)
    var met = condition(target)
    while !met, Date().timeIntervalSince(start) < timeout {
      Thread.sleep(forTimeInterval: 0.5)
      met = condition(target)
    }
    report(["ok": met, "seconds": Date().timeIntervalSince(start).rounded()])
  }

  private func waitIdentifier(of element: XCUIElement, equals value: String) -> Bool {
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
      if element.identifier == value { return true }
      Thread.sleep(forTimeInterval: 0.25)
    }
    return false
  }

  // MARK: - Keyboard

  /// Opens Safari's address bar, switches to the Pastronaut keyboard and taps the clip, without
  /// launching the Pastronaut app. Proves the keyboard sees what the app saved in the background.
  private func keyboardStep() throws {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    safari.launch()
    let address = safari.textFields.firstMatch
    if !address.waitForExistence(timeout: 5) {
      safari.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Address'")).firstMatch.tap()
    } else {
      address.tap()
    }
    // Labelled in the device language. Its value names the keyboard a tap switches to.
    let globe = safari.buttons.matching(
      NSPredicate(format: "label IN %@", ["Next keyboard", "Sonraki klavye"])
    ).firstMatch
    let clip = safari.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", match)).firstMatch
    var switches = 0
    while !clip.waitForExistence(timeout: 3), switches < 6, globe.waitForExistence(timeout: 3) {
      let next = globe.value as? String
      globe.tap()
      switches += 1
      if next == "Pastronaut" { break }
    }
    // Custom keyboards run in their own process; their elements are queried from the host app.
    guard clip.waitForExistence(timeout: 5) else {
      // Report only texts this keyboard itself shows; the rest of Safari may show the user's pages.
      func count(_ format: String, _ value: String) -> Int {
        safari.descendants(matching: .any).matching(NSPredicate(format: format, value)).count
      }
      let cloudStatus = safari.descendants(matching: .any)["cloudStatus"].firstMatch
      let diagnostics = safari.descendants(matching: .any)["diagnostics"].firstMatch
      report(["ok": false, "reason": "clip not in keyboard", "switches": switches,
              "globeValue": (globe.value as? String) ?? "",
              "spaceKey": count("identifier == %@", "spaceKey"),
              "noClipsText": count("identifier == %@", "emptyState"),
              "fullAccessHint": count("identifier == %@", "fullAccessHint"),
              "diagnostics": diagnostics.exists ? diagnostics.label : "",
              "cloudStatus": cloudStatus.exists ? cloudStatus.label : ""])
      return
    }
    let pinned = safari.images.matching(identifier: "pinIcon").count
    clip.tap()
    let field = safari.textFields.firstMatch
    let typed = (field.value as? String)?.contains(match) ?? false
    let cloudStatus = safari.descendants(matching: .any)["cloudStatus"].firstMatch
    report(["ok": typed, "pinIcons": pinned, "cloudStatus": cloudStatus.exists ? cloudStatus.label : ""])
  }

  /// Switches the current text field's keyboard to Pastronaut with the system's next-keyboard button.
  private func showPastronautKeyboard(in host: XCUIApplication) -> Bool {
    let ours = host.descendants(matching: .any)["spaceKey"].firstMatch
    let globe = host.buttons.matching(NSPredicate(format: "label IN %@", ["Next keyboard", "Sonraki klavye"])).firstMatch
    var switches = 0
    while !ours.waitForExistence(timeout: 2), switches < 6, globe.waitForExistence(timeout: 2) {
      globe.tap()
      switches += 1
    }
    return ours.exists
  }

  private func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  // MARK: - Output

  private func report(_ result: [String: Any]) {
    var result = result
    result["op"] = env["PT_OP"] ?? ""
    let data = (try? JSONSerialization.data(withJSONObject: result)) ?? Data()
    print("PTEST-RESULT \(String(data: data, encoding: .utf8) ?? "{}")")
  }
}
