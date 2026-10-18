import ApplicationServices
import Carbon
import XCTest

// swiftlint:disable file_length
// swiftlint:disable type_body_length
@MainActor
private struct HistoryItemQuery {
  let query: XCUIElementQuery

  var allElementsBoundByIndex: [XCUIElement] {
    query.allElementsBoundByIndex
  }

  subscript(title: String) -> XCUIElement {
    query.matching(
      NSPredicate(format: "label == %@ OR label BEGINSWITH %@", title, "\(title), ")
    ).firstMatch
  }
}

@MainActor
class MaccyUITests: XCTestCase {
  let app = XCUIApplication()
  let pasteboard = NSPasteboard.general

  let copy1 = UUID().uuidString
  let copy2 = UUID().uuidString
  let copy3 = UUID().uuidString

  // https://hetima.github.io/fucking_nsimage_syntax
  let image1 = NSImage(named: "NSAddTemplate")!
  let image2 = NSImage(named: "NSBluetoothTemplate")!

  let file1 = URL.applicationSupportDirectory.appendingPathComponent("file1.txt")
  let file2 = URL.applicationSupportDirectory.appendingPathComponent("file2.txt")

  let rtf1 = NSAttributedString(string: "foo").rtf(
    from: NSRange(0...2),
    documentAttributes: [:]
  )
  let rtf2 = NSAttributedString(string: "bar").rtf(
    from: NSRange(0...2),
    documentAttributes: [:]
  )

  let html1 = "<a href='#'>foo</a>".data(using: .utf8)
  let html2 = "<a href='#'>bar</a>".data(using: .utf8)

  private var items: HistoryItemQuery {
    HistoryItemQuery(
      query: app.descendants(matching: .any).matching(identifier: "copy-history-item")
    )
  }

  var itemTitles: [String] {
    items.allElementsBoundByIndex
      .sorted(by: { $0.frame.origin.y < $1.frame.origin.y })
      .compactMap { $0.label.components(separatedBy: ", ").first }
  }

  override func setUp() async throws {
    try await super.setUp()

    try? "Hello world".write(to: file1, atomically: true, encoding: .utf8)
    try? "Hello world".write(to: file2, atomically: true, encoding: .utf8)

    app.launchArguments.append("enable-testing")
    setKeyboardShortcut("popup", keyCode: kVK_ANSI_C, modifiers: cmdKey | shiftKey)
    setKeyboardShortcut("pin", keyCode: kVK_ANSI_P, modifiers: optionKey)
    setKeyboardShortcut("delete", keyCode: kVK_Delete, modifiers: optionKey)
    setKeyboardShortcut("togglePreview", keyCode: kVK_Space, modifiers: controlKey)
    app.launch()

    copyToClipboard(copy2)
    copyToClipboard(copy1)
  }

  override func tearDown() async throws {
    try await super.tearDown()

    app.terminate()
  }

  func testPopupWithHotkey() throws {
    popUpWithHotkey()
    assertExists(items[copy1])
    assertExists(items[copy2])
  }

  func testCloseWithHotkey() throws {
    popUpWithMouse()
    assertExists(items[copy1])
    simulatePopupHotkey()
    assertNotExists(items[copy1])
  }

  func testPopupWithMenubar() {
    popUpWithMouse()
    assertExists(items[copy1])
    assertExists(items[copy2])
  }

  func testNewCopyIsAdded() {
    popUpWithMouse()
    let copy3 = UUID().uuidString
    copyToClipboard(copy3)
    assertExists(items[copy3])
    app.typeKey(.escape, modifierFlags: [])
    popUpWithMouse()
    assertExists(items[copy2])
  }

  func testSearch() {
    popUpWithMouse()
    search(copy2)
    assertSearchFieldValue(copy2)
    assertExists(app.staticTexts[copy2])
    assertNotExists(items[copy1])
  }

  func testSearchFiles() {
    copyToClipboard(file2)
    copyToClipboard(file1)
    popUpWithMouse()
    search(file2.lastPathComponent)
    assertExists(items[file2.absoluteString.removingPercentEncoding!])
    assertNotExists(items[file1.absoluteString.removingPercentEncoding!])
  }

  func testCopyWithClick() {
    popUpWithMouse()
    scrollIntoViewIfNeeded(items[copy2].firstMatch)
    items[copy2].firstMatch.click()
    assertPasteboardStringEquals(copy2)
  }

  func testCopyWithEnter() {
    popUpWithMouse()
    scrollIntoViewIfNeeded(items[copy2].firstMatch)
    hover(items[copy2].firstMatch)
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy2)
  }

  func testCopyWithCommandShortcut() {
    popUpWithMouse()
    app.typeKey("2", modifierFlags: [.command])
    assertPasteboardStringEquals(copy2)
  }

  func testSearchAndCopyWithCommandShortcut() {
    popUpWithMouse()
    search(copy2)
    app.typeKey("1", modifierFlags: [.command])
    assertPasteboardStringEquals(copy2)
  }

  func testCopyImage() {
    copyToClipboard(image2)
    copyToClipboard(image1)
    popUpWithMouse()
    let allItems = items.allElementsBoundByIndex
    guard allItems.count > 1 else {
      XCTFail("Expected at least 2 history items, found \(allItems.count)")
      return
    }
    scrollIntoViewIfNeeded(allItems[1])
    hoverAndClick(allItems[1])
    assertPasteboardDataCountEquals(image2.tiffRepresentation!.count, forType: .tiff)
  }

  func testCopyFile() {
    copyToClipboard(file2)
    copyToClipboard(file1)
    popUpWithMouse()

    XCTAssertEqual(Array(itemTitles.prefix(2)), [
      file1.absoluteString.removingPercentEncoding!,
      file2.absoluteString.removingPercentEncoding!
    ])
    scrollIntoViewIfNeeded(items[file2.absoluteString.removingPercentEncoding!].firstMatch)
    hoverAndClick(items[file2.absoluteString.removingPercentEncoding!].firstMatch)
    assertPasteboardStringEquals(file2.absoluteString, forType: .fileURL)
  }

  func testCopyRTF() {
    copyToClipboard(rtf2, .rtf)
    popUpWithHotkey()
    closePopupByClickingOutside()
    copyToClipboard(rtf1, .rtf)
    popUpWithHotkey()
    XCTAssertEqual(Array(itemTitles.prefix(2)), ["foo", "bar"])
    scrollIntoViewIfNeeded(items["bar"].firstMatch)
    hoverAndClick(items["bar"].firstMatch)
    XCTAssertEqual(pasteboard.data(forType: .rtf), rtf2)
  }

  func testCopyHTML() {
    copyToClipboard(html2, .html)
    copyToClipboard(html1, .html)
    popUpWithMouse()
    XCTAssertEqual(Array(itemTitles.prefix(2)), ["foo", "bar"])
    scrollIntoViewIfNeeded(items["bar"].firstMatch)
    hoverAndClick(items["bar"].firstMatch)
    assertPasteboardDataEquals(html2, forType: .html)
  }

  func testDownArrow() {
    popUpWithMouse()
    app.typeKey(.downArrow, modifierFlags: [])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy2)
  }

  func testUpArrow() {
    popUpWithMouse()
    app.typeKey(.downArrow, modifierFlags: [])
    app.typeKey(.upArrow, modifierFlags: [])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy1)
  }

  func testControlJ() {
    popUpWithMouse()
    app.typeKey("j", modifierFlags: [.control])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy2)
  }

  func testControlK() {
    popUpWithMouse()
    app.typeKey("j", modifierFlags: [.control])
    app.typeKey("k", modifierFlags: [.control])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy1)
  }

  func testDeleteEntry() {
    popUpWithMouse()
    app.typeKey(.delete, modifierFlags: [.option])
    assertNotExists(items[copy1])

    app.typeKey(.escape, modifierFlags: [])
    popUpWithMouse()
    assertNotExists(items[copy1])
  }

  func testDeleteEntryDuringSearch() {
    popUpWithMouse()
    search(copy2)
    app.typeKey(.delete, modifierFlags: [.option])
    assertNotExists(items[copy2])

    app.typeKey(.escape, modifierFlags: [])
    popUpWithMouse()
    assertNotExists(items[copy2])
  }

  func testClear() {
    popUpWithMouse()
    scrollIntoViewIfNeeded(items[copy2].firstMatch)
    pin(copy2)
    hoverAndClick(app.buttons["Clear"].firstMatch)
    confirmClear()
    popUpWithMouse()
    assertNotExists(items[copy1])
    assertExists(items[copy2])
  }

  func testClearDuringSearch() {
    popUpWithMouse()
    search(copy2)
    hoverAndClick(app.buttons["Clear"].firstMatch)
    confirmClear()
    popUpWithMouse()
    assertNotExists(items[copy1])
    assertNotExists(items[copy2])
  }

  func testClearAll() {
    popUpWithMouse()
    scrollIntoViewIfNeeded(items[copy2].firstMatch)
    pin(copy2)
    XCUIElement.perform(withKeyModifiers: [.shift]) {
      hoverAndClick(app.buttons["Clear all"].firstMatch)
    }
    confirmClear()
    popUpWithMouse()
    assertNotExists(items[copy1])
    assertNotExists(items[copy2])
  }

  func testPin() {
    popUpWithMouse()
    scrollIntoViewIfNeeded(items[copy2].firstMatch)
    pin(copy2)
    XCTAssertEqual(Array(itemTitles.prefix(2)), [copy2, copy1])

    app.typeKey(.escape, modifierFlags: [])
    popUpWithMouse()
    XCTAssertEqual(Array(itemTitles.prefix(2)), [copy2, copy1])
  }

  func testPinDuringSearch() {
    popUpWithMouse()
    search(copy2)
    scrollIntoViewIfNeeded(items[copy2].firstMatch)
    pin(copy2)
    assertSearchFieldValue("")
    XCTAssertEqual(Array(itemTitles.prefix(2)), [copy2, copy1])
  }

  func testUnpin() {
    popUpWithMouse()
    scrollIntoViewIfNeeded(items[copy2].firstMatch)
    pin(copy2)
    pin(copy2)
    XCTAssertEqual(Array(itemTitles.prefix(2)), [copy1, copy2])
  }

  func testReorderPinsByDragging() {
    popUpWithMouse()
    pin(copy1)
    pin(copy2)
    XCTAssertEqual(Array(itemTitles.prefix(2)), [copy1, copy2])

    drag(items[copy2].firstMatch, before: items[copy1].firstMatch)
    XCTAssertEqual(Array(itemTitles.prefix(2)), [copy2, copy1])

    app.typeKey(.escape, modifierFlags: [])
    popUpWithMouse()
    XCTAssertEqual(Array(itemTitles.prefix(2)), [copy2, copy1])
  }

  func testRemoveLastWordFromSearchWithControlW() {
    popUpWithMouse()
    search("foo bar")
    app.typeKey("w", modifierFlags: [.control])
    assertSearchFieldValue("foo ")
  }

  func testPasteToSearch() {
    popUpWithMouse()
    app.typeKey("v", modifierFlags: [.command])
    waitForSearch()
    assertSearchFieldValue(copy1)
    assertExists(items[copy1])
    assertNotExists(items[copy2])
  }

  func testDisablesOnOptionClickingMenubarIcon() {
    XCUIElement.perform(withKeyModifiers: .option) {
      clickStatusItem()
    }

    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)

    popUpWithMouse()
    assertNotExists(items[copy3])
    assertNotExists(items[copy4])

    app.typeKey(.escape, modifierFlags: [])
    XCUIElement.perform(withKeyModifiers: .option) {
      clickStatusItem()
    }
  }

  func testDisablesOnlyForNextCopyOnOptionShiftClickingMenubarIcon() {
    XCUIElement.perform(withKeyModifiers: [.option, .shift]) {
      clickStatusItem()
    }

    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)

    popUpWithMouse()
    assertNotExists(items[copy3])
    assertExists(items[copy4])
  }

  func testCreatesNewCopyOnEnterWhenSearchResultsAreEmpty() {
    popUpWithMouse()
    search("foo bar")
    app.typeKey(.return, modifierFlags: [])
    XCTAssertEqual(pasteboard.string(forType: .string), "foo bar")
    assertExists(items["foo bar"])
  }

  func testOpenAndClose() throws {
    // Simulate the popup hotkey press (Cmd + Shift + C).
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)!
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    // Release the 'C' key but keep the popup open.
    let cUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)!
    cUp.flags = [.maskCommand, .maskShift]
    cUp.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    // Release the 'Shift' key and assert that the popup remains open - "normal" mode.
    let shiftUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: false)!
    shiftUp.flags = [.maskCommand] // Command remains active, Shift released
    shiftUp.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    // Release the 'CMD' key and assert that the popup remains open - "normal" mode.
    let commandUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Command), keyDown: false)!
    commandUp.flags = []
    commandUp.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    // Press shortcut again and assert the window closes
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    assertPopupDismissed()
  }

  func testOpenAndSelectSecondItem() throws {
    // Simulate the popup hotkey press (Cmd + Shift + C).
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)!
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    let cUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)!
    cUp.flags = [.maskCommand, .maskShift]
    cUp.post(tap: .cghidEventTap)

    // Press C 1 more time while keeping the modifier keys pressed
    cDown.post(tap: .cghidEventTap)

    // Release all modifiers keys and assert that the popup closes.
    let modifiersUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: false)!
    modifiersUp.flags = []
    modifiersUp.post(tap: .cghidEventTap)

    assertPopupDismissed()
    assertPasteboardStringEquals(copy2)
  }

  func testOpenAndSelectThirdItem() throws {
    copyToClipboard(copy3)

    // Simulate the popup hotkey press (Cmd + Shift + C).
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)!
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    let cUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)!
    cUp.flags = [.maskCommand, .maskShift]
    cUp.post(tap: .cghidEventTap)

    // Press C 2 more times while keeping the modifier keys pressed
    cDown.post(tap: .cghidEventTap)
    cUp.post(tap: .cghidEventTap)
    cDown.post(tap: .cghidEventTap)

    // Release all modifiers keys and assert that the popup closes.
    let modifiersUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: false)!
    modifiersUp.flags = []
    modifiersUp.post(tap: .cghidEventTap)

    assertPopupDismissed()
    assertPasteboardStringEquals(copy2)
  }

  func testOpenAndSelectThirdItemRepeatedPress() throws {
    copyToClipboard(copy3)

    // Simulate the popup hotkey press (Cmd + Shift + C).
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)!
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    // Press C 2 more times while keeping the modifier keys pressed
    cDown.post(tap: .cghidEventTap)
    cDown.post(tap: .cghidEventTap)

    // Release all modifiers keys and assert that the popup closes.
    let modifiersUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: false)!
    modifiersUp.flags = []
    modifiersUp.post(tap: .cghidEventTap)

    assertPopupDismissed()
    assertPasteboardStringEquals(copy2)
  }

  func testTogglePopupAndCloseOnClickOutside() {
    popUpWithHotkey()

    closePopupByClickingOutside()
    assertNotExists(items[copy1])

    // Assert that the hotkeys still work
    popUpWithHotkey()

    simulatePopupHotkey()
    assertPopupDismissed()
  }

  // Pastronaut: screenshots for design review, not assertions. Run with
  // -only-testing:MaccyUITests/MaccyUITests/testPastronautScreenshots and export the result bundle's attachments.
  func testPastronautScreenshots() throws {
    // This Mac runs in dark mode; the light pass forces Aqua for this launch only.
    for appearance in ["dark", "light"] {
      if appearance == "light" {
        app.terminate()
        app.launchArguments += ["-NSRequiresAquaSystemAppearance", "YES"]
        app.launch()
      }
      for text in [
        "#5B4BD0", "git push origin main", "+90 555 010 20 30", "ayse@example.com",
        "Caferağa Mah. Moda Cad. No:12 34710 Kadıköy/İstanbul", "https://developer.apple.com/documentation/cloudkit"
      ] {
        copyToClipboard(text)
      }
      // A Universal Clipboard copy, i.e. one made on the iPhone.
      pasteboard.clearContents()
      pasteboard.setString("Toplantı Perşembe 14:00'te, 3. kattaki salonda.", forType: .string)
      pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("com.apple.is-remote-clipboard"))
      waitTillClipboardCheck()

      popUpWithMouse()
      usleep(300_000)
      attachScreenshot(app.dialogs.firstMatch, named: "popup-\(appearance)")
      sleep(3) // The preview opens on its own after a short delay.
      attachScreenshot(app.dialogs.firstMatch, named: "popup-preview-\(appearance)")
      let filter = app.descendants(matching: .any)["device-filter"].firstMatch
      let iphone = filter.descendants(matching: .any).matching(NSPredicate(format: "label == 'iPhone'")).firstMatch
      if iphone.exists {
        iphone.click()
        sleep(1)
        attachScreenshot(app.dialogs.firstMatch, named: "popup-iphone-\(appearance)")
      }
      app.typeKey(.escape, modifierFlags: [])
      sleep(1)
    }

    // The first-launch welcome window.
    app.terminate()
    app.launchArguments.append("pastronaut-show-onboarding")
    app.launch()
    sleep(2)
    attachScreenshot(app.windows.firstMatch, named: "popup-onboarding")
  }

  // Pastronaut: pictures for the README and the App Store, with made-up clips, in English and Turkish (light),
  // plus English dark for the README: the list, a code preview, a queue, a typed filter, the iPhone filter.
  func testPastronautReadmeShots() throws {
    for (lang, appearance) in [("en", "dark"), ("en", "light"), ("tr", "light")] {
      app.terminate()
      app.launchArguments = ["enable-testing", "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "tr" ? "tr_TR" : "en_US",
                             "-openPreviewAutomatically", "<false/>"]
      if appearance == "light" {
        app.launchArguments += ["-NSRequiresAquaSystemAppearance", "YES"]
      }
      app.launch()
      let meeting = lang == "tr" ? "Toplantı perşembe 14:00'e alındı, 3B salonu." : "Meeting moved to Thursday 2 pm, room 3B."
      // Each copy names a plausible source app (TestSourceApp), not the app that runs the test.
      for (text, source) in [
        ("swift test --parallel", "com.apple.Terminal"), ("41.0256, 28.9741", "com.apple.Maps"),
        (meeting, "com.apple.Notes"), ("git push origin main", "com.apple.Terminal"),
        ("+1 555 0100 2030", "com.apple.AddressBook"),
        (lang == "tr" ? "merhaba@example.com" : "hello@example.com", "com.apple.mail"),
        ("#5B4BD0", "com.apple.DigitalColorMeter"),
        ("func greet(_ name: String) -> String {\n  // Say hello\n  return \"Hello, \\(name)!\"\n}", "com.apple.dt.Xcode"),
        ("https://developer.apple.com/documentation/cloudkit", "com.apple.Safari")
      ] {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setString(source, forType: NSPasteboard.PasteboardType("com.xkbxyberk.pastronaut.test-source-app"))
        waitTillClipboardCheck()
      }
      // A Universal Clipboard copy, i.e. one made on the iPhone.
      pasteboard.clearContents()
      pasteboard.setString("Galata Kulesi, Bereketzade Mah., Galata Kulesi Sk., 34421 Beyoğlu/İstanbul", forType: .string)
      pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("com.apple.is-remote-clipboard"))
      waitTillClipboardCheck()

      let tag = "\(lang)-\(appearance)"
      popUpWithMouse()
      app.typeKey(.downArrow, modifierFlags: [])
      app.typeKey(.upArrow, modifierFlags: [])
      usleep(500_000)
      attachScreenshot(app.dialogs.firstMatch, named: "readme-mac-\(tag)")
      // The code clip's preview.
      let code = historyRow("func greet")
      if code.exists {
        code.hover()
        app.typeKey(.space, modifierFlags: [])
        sleep(1)
        attachScreenshot(app.dialogs.firstMatch, named: "readme-mac-preview-\(tag)")
        app.typeKey(.space, modifierFlags: [])
        sleep(1)
      }
      // A queue of three.
      historyRow("https://developer.apple.com").hover()
      XCUIElement.perform(withKeyModifiers: .command) {
        historyRow(lang == "tr" ? "merhaba@example.com" : "hello@example.com").click()
        historyRow("git push origin main").click()
      }
      usleep(500_000)
      attachScreenshot(app.dialogs.firstMatch, named: "readme-mac-queue-\(tag)")
      app.typeKey(.escape, modifierFlags: [])
      sleep(1)
      // A typed filter: only code.
      popUpWithMouse()
      search(lang == "tr" ? "tür:kod" : "type:code")
      usleep(800_000)
      attachScreenshot(app.dialogs.firstMatch, named: "readme-mac-filter-\(tag)")
      app.typeKey(.escape, modifierFlags: [])
      sleep(1)
      // What came from the iPhone.
      popUpWithMouse()
      let iphone = app.descendants(matching: .any)["device-filter"].firstMatch.descendants(matching: .any)
        .matching(NSPredicate(format: "label == 'iPhone'")).firstMatch
      if iphone.exists {
        iphone.click()
        usleep(800_000)
        attachScreenshot(app.dialogs.firstMatch, named: "readme-mac-iphone-\(tag)")
      }
      app.typeKey(.escape, modifierFlags: [])
      sleep(1)
    }
  }

  // Pastronaut: row context menu, undo after deleting, "Show in History" and the timed pause.
  func testPastronautPopupExtras() throws {
    for text in ["c0ffee", "git push origin main", "Toplantı Perşembe 14:00'te"] {
      copyToClipboard(text)
    }

    // Context menu, then delete and undo.
    popUpWithMouse()
    let row = historyRow("git push origin main")
    XCTAssertTrue(row.waitForExistence(timeout: 3))
    row.rightClick()
    let delete = app.menuItems["context-delete"].firstMatch
    XCTAssertTrue(delete.waitForExistence(timeout: 3))
    attachScreenshot(app.menus.containing(.menuItem, identifier: "context-delete").firstMatch, named: "extras-context-menu")
    delete.click()
    XCTAssertTrue(waitForNonExistence(row, timeout: 3))
    let undo = app.buttons["undo-button"].firstMatch
    XCTAssertTrue(undo.waitForExistence(timeout: 3))
    attachScreenshot(app.dialogs.firstMatch, named: "extras-undo")
    app.typeKey("z", modifierFlags: .command)
    XCTAssertTrue(historyRow("git push origin main").waitForExistence(timeout: 3))

    // Show in History clears the search. Reopen first: typing while the preview slides out moves the window
    // (Maccy behaviour, see SlideoutController.togglePreview).
    app.typeKey(.escape, modifierFlags: [])
    popUpWithMouse()
    search("toplant")
    let result = historyRow("Toplantı Perşembe 14:00'te")
    XCTAssertTrue(result.waitForExistence(timeout: 3))
    attachScreenshot(app.dialogs.firstMatch, named: "extras-search")
    result.rightClick()
    attachScreenshot(app.menus.containing(.menuItem, identifier: "context-delete").firstMatch, named: "extras-search-menu")
    let reveal = app.menuItems["context-reveal"].firstMatch
    XCTAssertTrue(reveal.waitForExistence(timeout: 3))
    reveal.click()
    XCTAssertTrue(historyRow("c0ffee").waitForExistence(timeout: 3))
    app.typeKey(.escape, modifierFlags: [])
    sleep(1)

    // Pause for 15 minutes from the menu bar item's right-click menu: new copies are not saved.
    app.statusItems.firstMatch.rightClick()
    let pause = app.menuItems["pause-copying"].firstMatch
    XCTAssertTrue(pause.waitForExistence(timeout: 3))
    pause.hover()
    let fifteen = app.menuItems["pause-fifteenMinutes"].firstMatch
    XCTAssertTrue(fifteen.waitForExistence(timeout: 3))
    attachScreenshot(app.menus.containing(.menuItem, identifier: "pause-copying").firstMatch, named: "extras-status-menu")
    fifteen.click()
    copyToClipboard("copied while paused")
    popUpWithMouse()
    XCTAssertTrue(app.buttons["resume-button"].firstMatch.waitForExistence(timeout: 3))
    XCTAssertFalse(historyRow("copied while paused").exists)
    attachScreenshot(app.dialogs.firstMatch, named: "extras-paused")
    app.buttons["resume-button"].firstMatch.click()
    XCTAssertTrue(waitForNonExistence(app.buttons["resume-button"].firstMatch, timeout: 3))
    app.typeKey(.escape, modifierFlags: [])
    copyToClipboard("copied after resuming")
    popUpWithMouse()
    XCTAssertTrue(historyRow("copied after resuming").waitForExistence(timeout: 3))
  }

  // Pastronaut: Space shows the preview while the search is empty, and the preview fits the kind.
  func testPastronautQuickPreview() throws {
    // Without the automatic preview (it opens after 1.5 s), so each Space below opens or closes it.
    app.terminate()
    app.launchArguments += ["-openPreviewAutomatically", "<false/>"]
    app.launch()
    for text in ["func greet() {\n  print(\"hi\")\n}", "#2364D2", "https://example.com/preview"] {
      copyToClipboard(text)
    }
    popUpWithMouse()
    XCTAssertTrue(historyRow("https://example.com/preview").waitForExistence(timeout: 3))
    app.typeKey(.downArrow, modifierFlags: [])
    app.typeKey(.upArrow, modifierFlags: [])

    // The link (first row): Space opens the preview with its button, Space again closes it.
    app.typeKey(.space, modifierFlags: [])
    let action = app.descendants(matching: .any)["preview-action"].firstMatch
    XCTAssertTrue(action.waitForExistence(timeout: 3))
    attachScreenshot(app.dialogs.firstMatch, named: "preview-link")
    app.typeKey(.space, modifierFlags: [])
    XCTAssertTrue(waitForNonExistence(action, timeout: 3))

    // The color, then the code.
    app.typeKey(.downArrow, modifierFlags: [])
    app.typeKey(.space, modifierFlags: [])
    XCTAssertTrue(app.descendants(matching: .any)["preview-swatch"].firstMatch.waitForExistence(timeout: 3))
    attachScreenshot(app.dialogs.firstMatch, named: "preview-color")
    app.typeKey(.downArrow, modifierFlags: [])
    XCTAssertTrue(app.descendants(matching: .any)["preview-code"].firstMatch.waitForExistence(timeout: 3))
    attachScreenshot(app.dialogs.firstMatch, named: "preview-code")
    app.typeKey(.space, modifierFlags: [])
    XCTAssertTrue(waitForNonExistence(app.descendants(matching: .any)["preview-code"].firstMatch, timeout: 3))

    // With something typed, Space goes into the search.
    search("let")
    app.typeKey(.space, modifierFlags: [])
    assertSearchFieldValue("let ")
    XCTAssertFalse(app.descendants(matching: .any)["preview-code"].firstMatch.exists)
  }

  // Pastronaut: select several rows, Return starts a queue, each ⌘V elsewhere moves the next one to the clipboard.
  func testPastronautQueue() throws {
    for text in ["queue three", "queue two", "queue one"] {
      copyToClipboard(text)
    }
    popUpWithMouse()
    let one = historyRow("queue one"), two = historyRow("queue two"), three = historyRow("queue three")
    XCTAssertTrue(three.waitForExistence(timeout: 3))
    one.hover()
    XCUIElement.perform(withKeyModifiers: .command) {
      two.click()
      three.click()
    }
    let hint = app.descendants(matching: .any)["queue-hint"].firstMatch
    XCTAssertTrue(hint.waitForExistence(timeout: 3))
    XCTAssertTrue(hint.staticTexts.matching(NSPredicate(format: "value BEGINSWITH '3'")).firstMatch.exists)
    attachScreenshot(app.dialogs.firstMatch, named: "queue-selected")
    app.typeKey(.return, modifierFlags: [])
    assertPopupDismissed()
    assertPasteboardStringEquals("queue one")

    popUpWithMouse()
    XCTAssertTrue(app.descendants(matching: .any)["queue-notice"].firstMatch.waitForExistence(timeout: 3))
    attachScreenshot(app.dialogs.firstMatch, named: "queue-running")
    // Each ⌘V in another app moves the next one to the clipboard: HistoryTests.testQueue (a UI test's keystrokes
    // don't reach the global key monitor).
    let end = app.descendants(matching: .any)["queue-end"].firstMatch
    XCTAssertTrue(end.waitForExistence(timeout: 3))
    end.click()
    XCTAssertTrue(waitForNonExistence(end, timeout: 3))
    app.typeKey(.escape, modifierFlags: [])

    // A queue started from the keyboard and the notice's button.
    popUpWithMouse()
    XCTAssertFalse(app.descendants(matching: .any)["queue-notice"].firstMatch.exists)
    app.typeKey(.downArrow, modifierFlags: [])
    app.typeKey(.upArrow, modifierFlags: [])
    app.typeKey(.downArrow, modifierFlags: .shift)
    let start = app.descendants(matching: .any)["queue-start"].firstMatch
    XCTAssertTrue(start.waitForExistence(timeout: 3))
    start.click()
    assertPopupDismissed()
    assertPasteboardStringEquals("queue one")
  }

  // Pastronaut: filters typed into the search (type:, tür:, app:) and ⌘G back to the whole history.
  func testPastronautTypedFilters() throws {
    for text in ["plain typed words", "#FF8800", "https://example.com/typed"] {
      copyToClipboard(text)
    }
    popUpWithMouse()
    XCTAssertTrue(historyRow("plain typed words").waitForExistence(timeout: 3))

    search("type:link")
    XCTAssertTrue(waitForNonExistence(historyRow("plain typed words"), timeout: 3))
    XCTAssertTrue(historyRow("https://example.com/typed").exists)
    XCTAssertFalse(historyRow("#FF8800").exists)

    app.typeKey("u", modifierFlags: .control)
    search("tür:renk")
    XCTAssertTrue(historyRow("#FF8800").waitForExistence(timeout: 3))
    XCTAssertTrue(waitForNonExistence(historyRow("https://example.com/typed"), timeout: 3))
    attachScreenshot(app.dialogs.firstMatch, named: "typed-filter-color")

    // ⌘G: the color among the rest, search cleared.
    app.typeKey("g", modifierFlags: .command)
    XCTAssertTrue(historyRow("plain typed words").waitForExistence(timeout: 3))
    assertSearchFieldValue("")

    search("app:no-such-app")
    XCTAssertTrue(waitForNonExistence(historyRow("plain typed words"), timeout: 3))
    app.typeKey("u", modifierFlags: .control)
    XCTAssertTrue(historyRow("plain typed words").waitForExistence(timeout: 3))
  }

  private func historyRow(_ text: String) -> XCUIElement {
    app.dialogs.firstMatch.descendants(matching: .any)
      .matching(identifier: "copy-history-item")
      .matching(NSPredicate(format: "label BEGINSWITH %@", text))
      .firstMatch
  }

  // Pastronaut: the filter menu next to the device chips narrows the list to one kind.
  func testPastronautFilterMenu() throws {
    for text in ["https://example.com/filter", "plain words for the filter", "ayse@example.com"] {
      copyToClipboard(text)
    }
    popUpWithMouse()
    XCTAssertTrue(historyRow("plain words for the filter").waitForExistence(timeout: 3))
    let menu = app.descendants(matching: .any)["clip-filter-menu"].firstMatch
    XCTAssertTrue(menu.waitForExistence(timeout: 3))
    menu.click()
    let links = app.menuItems.matching(NSPredicate(format: "title == 'Links' OR title == 'Bağlantılar'")).firstMatch
    XCTAssertTrue(links.waitForExistence(timeout: 3))
    links.click()
    XCTAssertTrue(waitForNonExistence(historyRow("plain words for the filter"), timeout: 3))
    XCTAssertTrue(historyRow("https://example.com/filter").exists)
    XCTAssertFalse(historyRow("ayse@example.com").exists)
    attachScreenshot(app.dialogs.firstMatch, named: "filter-links")
  }

  private func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
    let deadline = Date.now.addingTimeInterval(timeout)
    while element.exists && Date.now < deadline {
      usleep(100_000)
    }
    return !element.exists
  }

  private func attachScreenshot(_ element: XCUIElement, named name: String) {
    let attachment = XCTAttachment(screenshot: element.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func popUpWithHotkey() {
    simulatePopupHotkey()
    waitUntilPoppedUp()
  }

  // KeyboardShortcuts persists JSON strings in UserDefaults.standard. Passing them
  // as launch arguments places them in the isolated, higher-priority NSArgumentDomain.
  private func setKeyboardShortcut(_ name: String, keyCode: Int, modifiers: Int) {
    app.launchArguments.append(contentsOf: [
      "-KeyboardShortcuts_\(name)",
      #""{\"carbonKeyCode\":\#(keyCode),\"carbonModifiers\":\#(modifiers)}""#
    ])
  }

  // Click outside the popup to close it
  private func closePopupByClickingOutside() {
    let popup = app.dialogs.firstMatch
    guard popup.exists else {
      return
    }

    let popupFrame = popup.frame
    let screenWidth = NSScreen.screens.first?.frame.width ?? popupFrame.maxX + 100
    let margin: CGFloat = 50
    let targetX = popupFrame.maxX + margin < screenWidth
      ? popupFrame.maxX + margin
      : popupFrame.minX - margin
    popup.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: targetX - popupFrame.minX, dy: popupFrame.height / 2))
      .click()
  }

  private func popUpWithMouse() {
    clickStatusItem()
    waitUntilPoppedUp()
  }

  private var isRunningOnCI: Bool {
    ProcessInfo.processInfo.environment["CI"] == "true"
  }

  private func clickStatusItem() {
    if isRunningOnCI {
      pressStatusItemViaAccessibility()
      return
    }

    let statusItem = app.statusItems.firstMatch
    if statusItem.waitForExistence(timeout: 3), statusItem.isHittable {
      statusItem.click()
    } else {
      pressStatusItemViaAccessibility()
    }
  }

  private func pressStatusItemViaAccessibility() {
    let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "org.p0deje.Maccy")
      .max { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }?
      .processIdentifier
    guard let pid else {
      XCTFail("Maccy is not running")
      return
    }

    let appElement = AXUIElementCreateApplication(pid)
    let deadline = Date.now.addingTimeInterval(3)
    var statusItem = axStatusItem(of: appElement)
    while statusItem == nil && Date.now < deadline {
      Thread.sleep(forTimeInterval: 0.1)
      statusItem = axStatusItem(of: appElement)
    }
    guard let statusItem else {
      XCTFail("Maccy has no status item exposed via accessibility")
      return
    }

    let result = AXUIElementPerformAction(statusItem, kAXPressAction as CFString)
    XCTAssertEqual(result, .success, "Failed to press status item via accessibility")
  }

  private func axStatusItem(of appElement: AXUIElement) -> AXUIElement? {
    guard let extrasMenuBar = axElement(appElement, attribute: kAXExtrasMenuBarAttribute) else {
      return nil
    }

    var children: CFTypeRef?
    guard AXUIElementCopyAttributeValue(extrasMenuBar, kAXChildrenAttribute as CFString, &children) == .success else {
      return nil
    }
    return (children as? [AXUIElement])?.first
  }

  private func axElement(_ element: AXUIElement, attribute: String) -> AXUIElement? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }
    return (value as! AXUIElement) // swiftlint:disable:this force_cast
  }

  private func simulatePopupHotkey() {
    let commandDown = CGEvent(
      keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Command), keyDown: true)!
    let commandUp = CGEvent(
      keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Command), keyDown: false)!
    let shiftDown = CGEvent(
      keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: true)!
    let shiftUp = CGEvent(
      keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: false)!
    shiftDown.flags = [.maskCommand]
    shiftUp.flags = [.maskCommand]
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)!
    let cUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)!
    cDown.flags = [.maskCommand, .maskShift]
    cUp.flags = [.maskCommand, .maskShift]
    commandDown.post(tap: .cghidEventTap)
    shiftDown.post(tap: .cghidEventTap)
    cDown.post(tap: .cghidEventTap)
    cUp.post(tap: .cghidEventTap)
    shiftUp.post(tap: .cghidEventTap)
    commandUp.post(tap: .cghidEventTap)
  }

  private func waitUntilPoppedUp() {
    if !app.dialogs.firstMatch.waitForExistence(timeout: 3) {
      XCTFail("Maccy did not pop up")
    }
  }

  private func assertPopupDismissed() {
    if !app.dialogs.firstMatch.waitForNonExistence(timeout: 3) {
      XCTFail("Maccy did not dismiss")
    }
  }

  private func copyToClipboard(_ content: String) {
    pasteboard.clearContents()
    pasteboard.setString(content, forType: .string)
    waitTillClipboardCheck()
  }

  private func copyToClipboard(_ content: NSImage) {
    pasteboard.clearContents()
    pasteboard.setData(content.tiffRepresentation, forType: .tiff)
    waitTillClipboardCheck()
  }

  private func copyToClipboard(_ content: URL) {
    pasteboard.clearContents()
    pasteboard.setData(content.dataRepresentation, forType: .fileURL)
    // WTF: The subsequent writes to pasteboard are not
    // visible unless we explicitly read the last one?!
    pasteboard.string(forType: .fileURL)
    waitTillClipboardCheck()
  }

  private func copyToClipboard(_ content: Data?, _ type: NSPasteboard.PasteboardType) {
    pasteboard.clearContents()
    pasteboard.setData(content, forType: type)
    waitTillClipboardCheck()
  }

  // Default interval for Maccy to check clipboard is 1 second
  private func waitTillClipboardCheck() {
    usleep(1_500_000)
  }

  private func pin(_ title: String) {
    hover(items[title].firstMatch)
    app.typeKey("p", modifierFlags: [.option])
    usleep(1_500_000)
  }

  private func drag(_ element: XCUIElement, before target: XCUIElement) {
    hover(element)
    let source = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let destination = target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
    source.click(forDuration: 0.5, thenDragTo: destination, withVelocity: .slow, thenHoldForDuration: 0.5)
    usleep(500_000)
  }

  private func hoverAndClick(_ element: XCUIElement) {
    let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    coordinate.hover()
    usleep(200_000)
    coordinate.click()
  }

  private func scrollIntoViewIfNeeded(_ element: XCUIElement) {
    guard element.exists else {
      return
    }

    let container = app.scrollViews["history-scroll-view"].firstMatch
    guard container.exists else {
      return
    }

    var attempts = 0
    while !container.frame.contains(element.frame) && attempts < 15 {
      // Negative deltaY scrolls down (reveals elements below the viewport).
      let delta: CGFloat = element.frame.midY > container.frame.midY ? -10 : 10
      container.scroll(byDeltaX: 0, deltaY: delta)
      usleep(100_000)
      attempts += 1
    }
  }

  private func hover(_ element: XCUIElement) {
    element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).hover()
    usleep(50_000)
    element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
    usleep(200_000)
  }

  private func search(_ string: String) {
    // NOTE: app.typeText is broken in Sonoma and causes some
    //       Chars to be submitted with a .command mask (e.g. 'p', 'k' or 'j')
    string.forEach {
      app.typeKey("\($0)", modifierFlags: [])
    }
    waitForSearch()
  }

  private func waitForSearch() {
    // NOTE: This is a hack and is flaky.
    // Ideally we should wait for a proper condition to detect that search has settled down.
    usleep(500000)  // wait for search throttle
  }

  private func assertExists(_ element: XCUIElement) {
    expectation(for: NSPredicate(format: "exists = 1"), evaluatedWith: element)
    waitForExpectations(timeout: 3)
  }

  private func assertNotExists(_ element: XCUIElement) {
    expectation(for: NSPredicate(format: "exists = 0"), evaluatedWith: element)
    waitForExpectations(timeout: 3)
  }

  private func assertNotVisible(_ element: XCUIElement) {
    expectation(
      for: NSPredicate(format: "(exists = 0) || (isHittable = 0)"), evaluatedWith: element)
    waitForExpectations(timeout: 3)
  }

  private func assertPasteboardDataEquals(
    _ expected: Data?, forType: NSPasteboard.PasteboardType = .string
  ) {
    let predicate = NSPredicate { (object, _) -> Bool in
      guard let copy = object as? Data else {
        return false
      }

      return self.pasteboard.data(forType: forType) == copy
    }
    expectation(for: predicate, evaluatedWith: expected)
    waitForExpectations(timeout: 3)
  }

  private func assertPasteboardDataCountEquals(
    _ expected: Int, forType: NSPasteboard.PasteboardType = .string
  ) {
    let predicate = NSPredicate { (object, _) -> Bool in
      guard let count = object as? Int else {
        return false
      }

      return self.pasteboard.data(forType: forType)!.count == count
    }
    expectation(for: predicate, evaluatedWith: expected)
    waitForExpectations(timeout: 3)
  }

  private func assertPasteboardStringEquals(_ expected: String?, forType: NSPasteboard.PasteboardType = .string) {
      let predicate = NSPredicate { (object, _) -> Bool in
        guard let copy = object as? String else {
          return false
        }
        return self.pasteboard.string(forType: forType) == copy
      }
      expectation(for: predicate, evaluatedWith: expected)
      waitForExpectations(timeout: 3)
    }

  private func assertSearchFieldValue(_ string: String) {
    XCTAssertEqual(app.textFields.firstMatch.value as? String, string)
  }

  private func confirmClear() {
    let button = app.buttons["confirmation-confirm"].firstMatch
    expectation(for: NSPredicate(format: "isHittable = 1"), evaluatedWith: button)
    waitForExpectations(timeout: 3)
    button.click()
  }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
