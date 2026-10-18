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
    // Off unless a step turns it on: with it on, Mac copies arriving by Universal Clipboard would be saved again.
    app.launchEnvironment["PT_AUTO_SAVE"] = "0"
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
      if !button.waitForExistence(timeout: 3) {
        // A row found by scrolling can sit under the filter bar or at the edge: bring it nearer the middle.
        let middle = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let shift: CGFloat = element.frame.midY < app.frame.height / 2 ? 250 : -250
        middle.press(forDuration: 0.1, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: shift)))
        element.swipeRight()
      }
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
    case "newClip":
      // "+" in the toolbar: type a clip without copying anything.
      app.activate()
      let new = app.buttons["newClipButton"].firstMatch
      XCTAssertTrue(new.waitForExistence(timeout: 10), "new clip button missing")
      new.tap()
      let editor = app.textViews["clipEditor"].firstMatch
      XCTAssertTrue(editor.waitForExistence(timeout: 5), "editor missing")
      editor.typeText(text)
      app.buttons["saveClipButton"].firstMatch.tap()
      report(["ok": row(match).waitForExistence(timeout: 10)])
    case "bulkDelete":
      // Select mode: every clip containing one of the "|"-separated parts, then Delete and confirm.
      app.activate()
      let parts = text.split(separator: "|").map(String.init)
      guard parts.allSatisfy({ row($0).waitForExistence(timeout: timeout) }) else {
        report(["ok": false, "reason": "rows missing"])
        return
      }
      app.buttons["selectButton"].firstMatch.tap()
      for part in parts {
        anyRow(part).tap()
      }
      app.buttons["bulkDelete"].firstMatch.tap()
      let confirm = app.buttons["confirmBulkDelete"].firstMatch
      XCTAssertTrue(confirm.waitForExistence(timeout: 5), "confirmation missing")
      confirm.tap()
      Thread.sleep(forTimeInterval: 1)
      report(["ok": parts.allSatisfy { !anyRow($0).exists }])
    case "autoSave":
      // "Save Clipboard on Opening" with the setting on (Debug only). The runner runs in the background and
      // iOS won't let it write the clipboard, so the app puts the text there itself at launch, standing in
      // for another app's copy. The permission prompt for real copies is checked by hand.
      app.launchEnvironment["PT_AUTO_SAVE"] = "1"
      app.launchEnvironment["PT_E2E_PASTEBOARD"] = text
      app.launch()
      allowPasteIfAsked()
      let saved = row(match).waitForExistence(timeout: timeout)
      report(["ok": saved, "visible": saved])
    case "collect":
      // Touch and hold the row, Add to Collection, then the collection named PT_ACTION, or New Collection… with
      // that name when it doesn't exist yet.
      let name = env["PT_ACTION"] ?? "PTEST"
      try existingRow().press(forDuration: 1.2)
      let menu = menuButton("collectionMenu", labels: ["Add to Collection", "Koleksiyona Ekle"])
      XCTAssertTrue(menu.waitForExistence(timeout: 5), "Add to Collection missing")
      menu.tap()
      let existing = app.buttons[name].firstMatch
      if existing.waitForExistence(timeout: 2) {
        existing.tap()
      } else {
        menuButton("newCollectionMenuItem", labels: ["New Collection…", "Yeni Koleksiyon…"]).tap()
        // Alert fields and buttons don't keep their identifiers.
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "name prompt missing")
        let field = alert.textFields.firstMatch
        field.tap()
        field.typeText(name)
        alert.buttons.matching(NSPredicate(format: "label IN %@", ["Create", "Oluştur"])).firstMatch.tap()
      }
      // The new collection is listed in the collections menu.
      Thread.sleep(forTimeInterval: 1)
      let listed = collectionItem(name, timeout: 10)
      dismissMenu()
      report(["ok": listed])
    case "openCollection":
      // Taps the collection's chip and waits for the row inside it.
      app.activate()
      guard chooseCollection(env["PT_ACTION"] ?? "", timeout: timeout) else {
        report(["ok": false, "reason": "no collection in the menu"])
        return
      }
      report(["ok": row(match).waitForExistence(timeout: timeout)])
    case "cardsShots":
      // Design review: the previews question, then the history as cards (previews on) in light and dark.
      defer { XCUIDevice.shared.appearance = .dark }
      XCUIDevice.shared.appearance = .light
      for (name, mode) in [("prompt", "ask"), ("cards", "1")] {
        app.terminate()
        app.launchEnvironment["PT_E2E_PREVIEWS"] = mode
        app.launch()
        // Previews come from the network the first time.
        Thread.sleep(forTimeInterval: mode == "1" ? 10 : 2)
        attachScreenshot(named: "\(name)-light")
      }
      app.swipeUp()
      Thread.sleep(forTimeInterval: 3)
      attachScreenshot(named: "cards-scrolled-light")
      XCUIDevice.shared.appearance = .dark
      app.terminate()
      app.launch()
      Thread.sleep(forTimeInterval: 4)
      attachScreenshot(named: "cards-dark")
      report(["ok": true])
    case "privacyLink":
      // Settings › About has the Privacy Policy link (App Review 5.1.1).
      app.launch()
      app.navigationBars.buttons.matching(identifier: "settingsButton").firstMatch.tap()
      let link = app.descendants(matching: .any)["privacyPolicy"].firstMatch
      for _ in 0..<6 where !link.isHittable {
        app.swipeUp()
      }
      Thread.sleep(forTimeInterval: 1)
      attachScreenshot(named: "settings-privacy-link")
      report(["ok": link.exists])
    case "keyboardCheck":
      // The keyboard with whatever Full Access the device has now (App Review 4.4.1: it must work without it),
      // on made-up clips: it should list them and type one into the app's search field.
      defer {
        app.terminate()
        app.launchEnvironment["PT_DEMO"] = nil
        app.launch()
        Thread.sleep(forTimeInterval: 3)
      }
      app.launchEnvironment["PT_DEMO"] = "1"
      app.launch()
      let search = app.searchFields.firstMatch
      guard search.waitForExistence(timeout: 5) else {
        report(["ok": false, "reason": "no search field"])
        return
      }
      search.tap()
      guard showPastronautKeyboard(in: app) else {
        report(["ok": false, "reason": "keyboard not shown"])
        return
      }
      Thread.sleep(forTimeInterval: 2)
      attachScreenshot(named: "kb-check")
      let tiles = app.descendants(matching: .any).matching(identifier: "kbClip")
      let count = tiles.count
      var typed = ""
      if count > 0 {
        tiles.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 1)
        typed = (search.value as? String) ?? ""
        attachScreenshot(named: "kb-check-typed")
      }
      let fromMac = app.descendants(matching: .any)["fromMacChip"].firstMatch.exists
      report(["ok": count > 0 && !typed.isEmpty, "tiles": count, "fromMacChip": fromMac, "typed": String(typed.prefix(40))])
    case "storeShots":
      // App Store screenshots in one language (PT_SHOTS_LANG = en or tr), made-up clips (PT_DEMO, no sync):
      // cards light, keyboard, cards dark, a collection, list light. Ends with a normal launch.
      let lang = env["PT_SHOTS_LANG"] ?? "en"
      defer {
        XCUIDevice.shared.appearance = .dark
        app.terminate()
        app.launchEnvironment["PT_DEMO"] = nil
        app.launchEnvironment["PT_E2E_PREVIEWS"] = nil
        app.launchArguments = []
        app.launch()
        Thread.sleep(forTimeInterval: 3)
      }
      app.launchEnvironment["PT_DEMO"] = "1"
      app.launchArguments = ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "tr" ? "tr_TR" : "en_US"]
      func launch(_ appearance: XCUIDevice.Appearance, previews: String) {
        XCUIDevice.shared.appearance = appearance
        app.terminate()
        app.launchEnvironment["PT_E2E_PREVIEWS"] = previews
        app.launch()
        Thread.sleep(forTimeInterval: previews == "1" ? 8 : 2)
      }
      launch(.light, previews: "1")
      attachScreenshot(named: "store-\(lang)-1-cards-light")
      launch(.dark, previews: "1")
      app.swipeUp()
      Thread.sleep(forTimeInterval: 2)
      attachScreenshot(named: "store-\(lang)-3-cards-dark")
      launch(.light, previews: "1")
      if chooseCollection(lang == "tr" ? "Seyahat" : "Travel", timeout: 10) {
        Thread.sleep(forTimeInterval: 3)
        attachScreenshot(named: "store-\(lang)-4-collection-light")
      }
      launch(.light, previews: "0")
      attachScreenshot(named: "store-\(lang)-5-list-light")
      launch(.dark, previews: "0")
      let search = app.searchFields.firstMatch
      if search.waitForExistence(timeout: 5) {
        search.tap()
        if showPastronautKeyboard(in: app) {
          Thread.sleep(forTimeInterval: 2)
          attachScreenshot(named: "store-\(lang)-2-keyboard-dark")
        }
      }
      report(["ok": true])
    case "readmeShots":
      // README and store pictures: made-up clips (PT_DEMO, no sync), English, cards and list, light and dark,
      // a collection, the keyboard. Ends by launching normally, which puts the real history back for the keyboard.
      defer {
        XCUIDevice.shared.appearance = .dark
        app.terminate()
        app.launchEnvironment["PT_DEMO"] = nil
        app.launchEnvironment["PT_E2E_PREVIEWS"] = nil
        app.launchArguments = []
        app.launch()
        Thread.sleep(forTimeInterval: 3)
      }
      app.launchEnvironment["PT_DEMO"] = "1"
      app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
      for appearance in [XCUIDevice.Appearance.light, .dark] {
        let name = appearance == .light ? "light" : "dark"
        XCUIDevice.shared.appearance = appearance
        for (layout, mode) in [("cards", "1"), ("list", "0")] {
          app.terminate()
          app.launchEnvironment["PT_E2E_PREVIEWS"] = mode
          app.launch()
          // Map and page previews come from the network the first time.
          Thread.sleep(forTimeInterval: mode == "1" ? 8 : 2)
          attachScreenshot(named: "readme-\(layout)-\(name)")
        }
      }
      // A collection, from the list (dark).
      let menu = app.descendants(matching: .any)["collectionsMenu"].firstMatch
      if menu.waitForExistence(timeout: 3) {
        menu.tap()
        let travel = app.descendants(matching: .any)["collection.Travel"].firstMatch
        if travel.waitForExistence(timeout: 3) {
          travel.tap()
          Thread.sleep(forTimeInterval: 1)
          attachScreenshot(named: "readme-collection-dark")
        }
      }
      // The keyboard, in the app's own search field.
      app.terminate()
      app.launch()
      let search = app.searchFields.firstMatch
      if search.waitForExistence(timeout: 5) {
        search.tap()
        if showPastronautKeyboard(in: app) {
          Thread.sleep(forTimeInterval: 2)
          attachScreenshot(named: "readme-keyboard-dark")
        }
      }
      report(["ok": true])
    case "collectionShots":
      // Design review: the scope bar with a collection, the row menu, the clip's details and Settings › Your Data.
      app.activate()
      let name = env["PT_ACTION"] ?? ""
      _ = chooseCollection(name, timeout: 10)
      Thread.sleep(forTimeInterval: 1)
      attachScreenshot(named: "collection-scope")
      try existingRow().press(forDuration: 1.2)
      let menu = menuButton("collectionMenu", labels: ["Add to Collection", "Koleksiyona Ekle"])
      if menu.waitForExistence(timeout: 5) { menu.tap() }
      Thread.sleep(forTimeInterval: 1)
      attachScreenshot(named: "collection-menu")
      app.terminate()
      app.launch()
      try existingRow().press(forDuration: 1.2)
      let details = app.buttons["showDetails"].firstMatch
      if details.waitForExistence(timeout: 5) { details.tap() }
      Thread.sleep(forTimeInterval: 1.5)
      attachScreenshot(named: "clip-detail")
      app.terminate()
      app.launch()
      app.buttons["settingsButton"].firstMatch.tap()
      Thread.sleep(forTimeInterval: 1)
      app.swipeUp()
      app.swipeUp()
      Thread.sleep(forTimeInterval: 1.5)
      attachScreenshot(named: "settings-data")
      report(["ok": true])
    case "selectShots":
      // Design review: select mode, the new clip sheet and the clipboard settings.
      app.activate()
      app.buttons["selectButton"].firstMatch.tap()
      Thread.sleep(forTimeInterval: 0.5)
      app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'clip.'")).firstMatch.tap()
      Thread.sleep(forTimeInterval: 0.5)
      attachScreenshot(named: "select-mode")
      app.buttons["endSelectButton"].firstMatch.tap()
      app.buttons["newClipButton"].firstMatch.tap()
      Thread.sleep(forTimeInterval: 1)
      attachScreenshot(named: "new-clip")
      app.terminate()
      app.launch()
      app.buttons["settingsButton"].firstMatch.tap()
      Thread.sleep(forTimeInterval: 1)
      app.swipeUp()
      Thread.sleep(forTimeInterval: 2)
      attachScreenshot(named: "settings-clipboard")
      report(["ok": true])
    case "searchShots":
      // Design review: search suggestions, a chosen chip, and the Privacy section of Settings.
      app.launch()
      let search = app.searchFields.firstMatch
      if !search.waitForExistence(timeout: 3) { app.swipeDown() }
      search.tap()
      Thread.sleep(forTimeInterval: 1)
      attachScreenshot(named: "search-suggestions")
      let chip = app.descendants(matching: .any)
        .matching(NSPredicate(format: "label == 'Bağlantılar' OR label == 'Links'")).firstMatch
      if chip.exists {
        chip.tap()
        Thread.sleep(forTimeInterval: 1)
        attachScreenshot(named: "search-token")
      }
      app.terminate()
      app.launch()
      app.buttons["settingsButton"].firstMatch.tap()
      Thread.sleep(forTimeInterval: 1.5)
      app.swipeUp()
      Thread.sleep(forTimeInterval: 2)
      attachScreenshot(named: "settings-privacy")
      report(["ok": true, "chip": chip.exists])
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
      defer { XCUIDevice.shared.appearance = .dark }
      for (name, appearance) in [("light", XCUIDevice.Appearance.light), ("dark", .dark)] {
        XCUIDevice.shared.appearance = appearance
        app.terminate()
        app.launch()
        Thread.sleep(forTimeInterval: 2)
        attachScreenshot(named: "history-\(name)")
        // The bar with the logotype must stay put while the list scrolls under it.
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        attachScreenshot(named: "history-scrolled-\(name)")
        app.swipeDown()
        app.swipeDown()
        let iphoneFilter = app.descendants(matching: .any)["filter.iphone"].firstMatch
        if iphoneFilter.exists {
          iphoneFilter.tap()
          Thread.sleep(forTimeInterval: 1)
          attachScreenshot(named: "history-iphone-\(name)")
          app.descendants(matching: .any)["filter.all"].firstMatch.tap()
        }
      }
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
      for _ in 0..<4 where !setupRow.isHittable {
        app.swipeUp()
      }
      if setupRow.waitForExistence(timeout: 3) {
        setupRow.tap()
        Thread.sleep(forTimeInterval: 1)
        attachScreenshot(named: "setup")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        attachScreenshot(named: "setup-scrolled")
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
        // The leftmost tab touches the backdrop's rounded corner: check it selected too.
        let pinnedTab = app.descendants(matching: .any)["tab.pinned"].firstMatch
        if pinnedTab.exists {
          pinnedTab.tap()
          Thread.sleep(forTimeInterval: 0.5)
          attachScreenshot(named: "kb-pinned-\(name)")
          app.descendants(matching: .any)["tab.recent"].firstMatch.tap()
        }
        let searchKey = app.descendants(matching: .any)["searchKey"].firstMatch
        if searchKey.exists {
          searchKey.tap()
          for letter in ["k", "l"] {
            app.descendants(matching: .any)["letter.\(letter)"].firstMatch.tap()
          }
          Thread.sleep(forTimeInterval: 1)
          attachScreenshot(named: "kb-search-\(name)")
          let digits = app.descendants(matching: .any)["digitsKey"].firstMatch
          if digits.exists {
            digits.tap()
            Thread.sleep(forTimeInterval: 0.5)
            attachScreenshot(named: "kb-digits-\(name)")
            digits.tap()
          }
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

  /// A row in any mode; while selecting, rows are not buttons.
  private func anyRow(_ text: String) -> XCUIElement {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH 'clip.' AND label CONTAINS %@", text))
      .firstMatch
  }

  /// Opens the collections menu next to the device chips and shows whether `name` is in it (the menu stays open).
  private func collectionItem(_ name: String, timeout: TimeInterval) -> Bool {
    let menu = app.descendants(matching: .any)["collectionsMenu"].firstMatch
    guard menu.waitForExistence(timeout: timeout) else { return false }
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      menu.tap()
      if menuItem(name).waitForExistence(timeout: 2) { return true }
      dismissMenu()
      Thread.sleep(forTimeInterval: 1)
    } while Date() < deadline
    return false
  }

  /// Chooses a collection from the collections menu.
  private func chooseCollection(_ name: String, timeout: TimeInterval) -> Bool {
    guard collectionItem(name, timeout: timeout) else { return false }
    menuItem(name).tap()
    return true
  }

  /// Menu items keep their identifiers on some systems; otherwise the label starts with the name ("Adresler · 3").
  private func menuItem(_ name: String) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "identifier == %@ OR label BEGINSWITH %@", "collection.\(name)", name)).firstMatch
  }

  /// Closes an open menu by tapping beside it, at the top of the screen.
  private func dismissMenu() {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03)).tap()
  }

  /// Menu items keep their identifiers on some systems and only their labels on others.
  private func menuButton(_ identifier: String, labels: [String]) -> XCUIElement {
    let byIdentifier = app.buttons[identifier].firstMatch
    if byIdentifier.waitForExistence(timeout: 2) { return byIdentifier }
    return app.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
  }

  /// Taps "Allow Paste" when iOS asks whether Pastronaut may read another app's copy.
  private func allowPasteIfAsked() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let deadline = Date().addingTimeInterval(6)
    while Date() < deadline {
      for alert in [app.alerts.firstMatch, springboard.alerts.firstMatch] where alert.exists {
        // Buttons are "Don't Allow Paste" and "Allow Paste" (in the device language); allow is last.
        let buttons = alert.buttons.allElementsBoundByIndex
        buttons.last?.tap()
        return
      }
      Thread.sleep(forTimeInterval: 0.3)
    }
  }

  private func existingRow() throws -> XCUIElement {
    app.activate()
    let row = row(match)
    if row.waitForExistence(timeout: min(timeout, 10)) || scrollToFind(row) { return row }
    report(["ok": false, "reason": "row missing"])
    throw XCTSkip("row missing")
  }

  /// The list is lazy: rows off screen are not in the hierarchy until scrolled to. The app may still be scrolled
  /// from an earlier step, so this looks towards the top first, then down.
  private func scrollToFind(_ row: XCUIElement) -> Bool {
    for index in 0..<24 {
      if index < 8 { app.swipeDown() } else { app.swipeUp() }
      if row.waitForExistence(timeout: 1) { return true }
    }
    return false
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

  /// A pinned row moves to the top and an unpinned one into the days below, so the row is looked for again
  /// when it left the screen.
  private func waitIdentifier(of element: XCUIElement, equals value: String) -> Bool {
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
      if element.exists, element.identifier == value { return true }
      Thread.sleep(forTimeInterval: 0.25)
    }
    return scrollToFind(element) && element.identifier == value
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
