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
      wait(until: { $0.exists && ($0.value as? String) == "pinned" })
    case "waitUnpinned":
      wait(until: { $0.exists && ($0.value as? String) == "unpinned" })
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
      let button = app.buttons[op == "pin" ? "Pin" : "Unpin"].firstMatch
      XCTAssertTrue(button.waitForExistence(timeout: 5), "\(op) action missing")
      button.tap()
      let expected = op == "pin" ? "pinned" : "unpinned"
      report(["ok": waitValue(of: row(match), equals: expected)])
    case "delete":
      let element = try existingRow()
      element.swipeLeft()
      let button = app.buttons["Delete"].firstMatch
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
      app.buttons["Settings"].firstMatch.tap()
      let error = app.staticTexts["syncError"]
      let synced = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Synced clips'")).firstMatch
      report([
        "ok": true,
        "error": error.waitForExistence(timeout: 2) ? error.label : "",
        "synced": synced.exists ? synced.label : "?"
      ])
      app.buttons["Done"].firstMatch.tap()
    case "keyboard":
      try keyboardStep()
    default:
      XCTFail("Unknown step \(op)")
    }
  }

  // MARK: - Rows

  private var rows: XCUIElementQuery {
    app.buttons.matching(identifier: "clip")
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

  private func waitValue(of element: XCUIElement, equals value: String) -> Bool {
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
      if (element.value as? String) == value { return true }
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
      let cloudStatus = safari.descendants(matching: .any)
        .matching(NSPredicate(format: "label BEGINSWITH 'cloud:'")).firstMatch
      let diagnostics = safari.descendants(matching: .any)
        .matching(NSPredicate(format: "label CONTAINS 'diag:'")).firstMatch
      report(["ok": false, "reason": "clip not in keyboard", "switches": switches,
              "globeValue": (globe.value as? String) ?? "",
              "spaceKey": count("label == %@", "space"),
              "noClipsText": count("label BEGINSWITH %@", "No clips yet"),
              "fullAccessHint": count("label BEGINSWITH %@", "Turn on Allow Full Access"),
              "diagnostics": diagnostics.exists ? diagnostics.label : "",
              "cloudStatus": cloudStatus.exists ? cloudStatus.label : "",
              "rowsWithDeviceIcon": count("label CONTAINS %@", "laptopcomputer") + count("label CONTAINS %@", "iphone")])
      return
    }
    let pinned = safari.images.matching(NSPredicate(format: "identifier == 'pin.fill' OR label == 'Pin'")).count
    clip.tap()
    let field = safari.textFields.firstMatch
    let typed = (field.value as? String)?.contains(match) ?? false
    let cloudStatus = safari.descendants(matching: .any)
      .matching(NSPredicate(format: "label BEGINSWITH 'cloud:'")).firstMatch
    report(["ok": typed, "pinIcons": pinned, "cloudStatus": cloudStatus.exists ? cloudStatus.label : ""])
  }

  // MARK: - Output

  private func report(_ result: [String: Any]) {
    var result = result
    result["op"] = env["PT_OP"] ?? ""
    let data = (try? JSONSerialization.data(withJSONObject: result)) ?? Data()
    print("PTEST-RESULT \(String(data: data, encoding: .utf8) ?? "{}")")
  }
}
