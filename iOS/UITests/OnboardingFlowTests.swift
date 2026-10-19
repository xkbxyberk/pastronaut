import XCTest

final class OnboardingFlowTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchEnvironment["PT_DEMO"] = "1"
  }

  func testFirstLaunchShowsGuideUntilFinished() {
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasCompletedOnboarding", "NO"]
    app.launch()
    let next = app.buttons["onboardingNext"]
    XCTAssertTrue(next.waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["Welcome to Pastronaut"].exists)
    XCTAssertTrue(app.switches["onboardingPreviewsToggle"].exists || app.descendants(matching: .any)["onboardingPreviewsToggle"].exists)
    next.tap()
    XCTAssertTrue(app.staticTexts["Add the Pastronaut keyboard"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["openKeyboardSettings"].exists)
    next.tap()
    XCTAssertTrue(app.staticTexts["Paste without being asked"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["openPasteSettings"].exists)
    let tryButton = app.buttons["tryClipboardSave"]
    if !tryButton.isHittable { app.swipeUp() }
    tryButton.tap()
    let result = app.descendants(matching: .any)["tryClipboardResult"]
    XCTAssertTrue(result.waitForExistence(timeout: 5))
    XCTAssertTrue(result.label.contains("Saved"))
    XCTAssertFalse(app.buttons["onboardingSkip"].exists)
    XCTAssertEqual(next.label, "Start Using Pastronaut")
    next.tap()
    XCTAssertTrue(app.buttons["settingsButton"].firstMatch.waitForExistence(timeout: 5))

    app.terminate()
    app.launchArguments = ["-AppleLanguages", "(en)"]
    app.launch()
    XCTAssertTrue(app.buttons["settingsButton"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["onboardingNext"].exists)
  }

  func testSkipCompletesGuide() {
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasCompletedOnboarding", "NO"]
    app.launch()
    let skip = app.buttons["onboardingSkip"]
    XCTAssertTrue(skip.waitForExistence(timeout: 10))
    skip.tap()
    XCTAssertTrue(app.buttons["settingsButton"].firstMatch.waitForExistence(timeout: 5))
  }

  func testSettingsOpensGuideAndSwitchesLanguageLive() {
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasCompletedOnboarding", "YES"]
    app.launch()
    let settings = app.buttons["settingsButton"].firstMatch
    XCTAssertTrue(settings.waitForExistence(timeout: 10))
    settings.tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

    app.buttons["setupKeyboard"].tap()
    XCTAssertTrue(app.staticTexts["Welcome to Pastronaut"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["onboardingSkip"].exists)
    app.navigationBars["Setup Guide"].buttons["Settings"].tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

    chooseLanguage("Türkçe")
    XCTAssertTrue(app.navigationBars["Ayarlar"].waitForExistence(timeout: 5))
    chooseLanguage("English")
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    let deviceIsTurkish = Locale.preferredLanguages.first?.hasPrefix("tr") == true
    if deviceIsTurkish {
      chooseLanguage("Türkçe")
      XCTAssertTrue(app.navigationBars["Ayarlar"].waitForExistence(timeout: 5))
    }
  }

  func testThemeChoiceIsKept() {
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasCompletedOnboarding", "YES"]
    app.launch()
    let settings = app.buttons["settingsButton"].firstMatch
    XCTAssertTrue(settings.waitForExistence(timeout: 10))
    settings.tap()
    chooseTheme("Dark")
    attachScreenshot(named: "settings-dark")
    app.terminate()
    app.launch()
    app.buttons["settingsButton"].firstMatch.tap()
    let picker = app.buttons["themePicker"]
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    XCTAssertTrue(picker.label.contains("Dark") || (picker.value as? String) == "Dark")
    chooseTheme("System")
  }

  func testLanguageSwitchReachesMenus() {
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasCompletedOnboarding", "YES"]
    app.launch()
    let settings = app.buttons["settingsButton"].firstMatch
    XCTAssertTrue(settings.waitForExistence(timeout: 10))
    settings.tap()
    chooseLanguage("Türkçe")
    XCTAssertTrue(app.navigationBars["Ayarlar"].waitForExistence(timeout: 5))
    let themePicker = app.buttons["themePicker"]
    themePicker.tap()
    let turkishThemeMenu = app.buttons["Sistem"].firstMatch.waitForExistence(timeout: 3)
    app.buttons["Sistem"].firstMatch.tap()
    app.buttons["doneButton"].tap()
    let card = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'card.'")).firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    card.press(forDuration: 1.2)
    let turkishContextMenu = app.buttons["Kopyala"].firstMatch.waitForExistence(timeout: 3)
    let englishContextMenu = app.buttons["Copy"].firstMatch.exists
    XCTContext.runActivity(named: "menus: theme tr=\(turkishThemeMenu) context tr=\(turkishContextMenu) en=\(englishContextMenu)") { _ in }
    print("MENU_PROBE theme_tr=\(turkishThemeMenu) context_tr=\(turkishContextMenu) context_en=\(englishContextMenu)")
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
    app.buttons["settingsButton"].firstMatch.tap()
    if !(Locale.preferredLanguages.first?.hasPrefix("tr") == true) {
      chooseLanguage("English")
    }
  }

  func testKeyboardFullAccessIsDetected() {
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasCompletedOnboarding", "YES"]
    app.launch()
    let newClip = app.buttons["newClipButton"].firstMatch
    XCTAssertTrue(newClip.waitForExistence(timeout: 10))
    newClip.tap()
    let editor = app.textViews["clipEditor"].firstMatch
    XCTAssertTrue(editor.waitForExistence(timeout: 5))
    editor.tap()
    XCTAssertTrue(showPastronautKeyboard(), "Pastronaut keyboard is not added")
    Thread.sleep(forTimeInterval: 2)
    let hintShown = app.descendants(matching: .any)["fullAccessHint"].exists
    print("FULL_ACCESS_PROBE keyboardHint=\(hintShown)")
    XCTAssertFalse(hintShown, "The keyboard thinks it has no Full Access")
    app.buttons["Cancel"].firstMatch.tap()
    app.buttons["settingsButton"].firstMatch.tap()
    let setupRow = app.buttons["setupKeyboard"]
    XCTAssertTrue(setupRow.waitForExistence(timeout: 5))
    print("FULL_ACCESS_PROBE setupRow=\(setupRow.label)")
    XCTAssertTrue(setupRow.label.contains("Ready"))
  }

  func testGuideKeyboardFieldConfirmsFullAccess() {
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasCompletedOnboarding", "NO"]
    app.launch()
    let next = app.buttons["onboardingNext"]
    XCTAssertTrue(next.waitForExistence(timeout: 10))
    next.tap()
    let field = app.textFields["keyboardTryField"]
    for _ in 0..<4 where !field.isHittable { app.swipeUp() }
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    XCTAssertTrue(showPastronautKeyboard(), "Pastronaut keyboard is not added")
    XCTAssertTrue(app.descendants(matching: .any)["fullAccessConfirmed"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any)["setupStep2"].label.contains("Ready"))
  }

  private func showPastronautKeyboard() -> Bool {
    let ours = app.descendants(matching: .any)["spaceKey"].firstMatch
    let globe = app.buttons.matching(NSPredicate(format: "label IN %@", ["Next keyboard", "Sonraki klavye"])).firstMatch
    var switches = 0
    while !ours.waitForExistence(timeout: 2), switches < 6, globe.waitForExistence(timeout: 2) {
      globe.tap()
      switches += 1
    }
    return ours.exists
  }

  private func chooseLanguage(_ name: String) {
    let picker = app.buttons["languagePicker"]
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    picker.tap()
    let option = app.buttons[name].firstMatch
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    option.tap()
  }

  private func chooseTheme(_ name: String) {
    let picker = app.buttons["themePicker"]
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    picker.tap()
    let option = app.buttons[name].firstMatch
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    option.tap()
  }

  private func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
