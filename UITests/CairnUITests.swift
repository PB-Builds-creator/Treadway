import XCTest

/// UI tests for the primary flows. Run in Xcode (⌘U) with the CairnUITests target.
/// They drive the app through its accessible labels, so they double as an
/// accessibility smoke test. Launch arg `-uiTestingResetOnboarding` is honored by
/// the app to start from a known state (see CairnApp / AppSettings if you wire it).
final class CairnUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "1"]
        app.launch()
        // Dismiss onboarding by installing the routine if the sheet is present.
        let install = app.buttons["Install my default routine"]
        if install.waitForExistence(timeout: 3) {
            install.tap()
        }
        return app
    }

    func testTodayScreenLoads() throws {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5)
                      || app.staticTexts["Today"].waitForExistence(timeout: 5))
    }

    func testCreateTask() throws {
        let app = launchApp()
        app.buttons["Add Task"].firstMatch.tap()
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Evening walk")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Evening walk"].waitForExistence(timeout: 4))
    }

    func testCompleteTask() throws {
        let app = launchApp()
        // Complete the first available task via its checkbox accessibility label.
        let checkbox = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Complete '")).firstMatch
        XCTAssertTrue(checkbox.waitForExistence(timeout: 4))
        checkbox.tap()
        // After completion the label flips to "Mark ... not done".
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Mark '")).firstMatch.waitForExistence(timeout: 4))
    }

    func testAddWater() throws {
        let app = launchApp()
        let addButton = app.buttons["Add 16 ounces"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 4))
        addButton.tap()
        // Progress label should now reflect a non-zero amount somewhere on screen.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS ' oz'")).firstMatch.exists)
    }

    func testNavigateToWeekAndHistory() throws {
        let app = launchApp()
        app.buttons["Week"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '–'")).firstMatch.waitForExistence(timeout: 4)
                      || app.navigationBars["Week"].waitForExistence(timeout: 4))
        app.buttons["History"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 4)
                      || app.staticTexts["History"].waitForExistence(timeout: 4))
    }

    func testOpenSettings() throws {
        let app = launchApp()
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 4))
    }
}
