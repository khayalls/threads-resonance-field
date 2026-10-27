import XCTest

final class ExperienceTests: XCTestCase {
    @MainActor func testSpatialToolbarAndLoopProtection() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test"]
        app.launch()
        let enter = app.buttons["enter-field"]
        XCTAssertTrue(enter.waitForExistence(timeout: 20))
        XCTAssertTrue(enter.isEnabled)
        enter.tap()
        let exit = app.buttons["exit-field"]
        XCTAssertTrue(exit.waitForExistence(timeout: 25), app.debugDescription)

        app.buttons["sound-controls"].tap()
        let volume = app.sliders["Sound level"]
        XCTAssertTrue(volume.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Decrease sound level"].tap()
        XCTAssertTrue(app.staticTexts["60%"].exists)
        app.buttons["Increase sound level"].tap()
        XCTAssertTrue(app.staticTexts["65%"].exists)
        let ambient = app.switches["ambient-notes"]
        XCTAssertTrue(ambient.exists)
        ambient.tap()
        app.buttons["close-controls-panel"].tap()

        func openKeys() {
            app.buttons["field-tools"].tap()
            let play = app.buttons["play-controls"]
            XCTAssertTrue(play.waitForExistence(timeout: 5))
            play.tap()
            XCTAssertTrue(app.buttons["Play D3"].waitForExistence(timeout: 5), app.debugDescription)
        }
        openKeys()
        app.buttons["Play D3"].tap()
        app.buttons["Wave"].tap()
        app.buttons["Resonate"].tap()
        app.buttons["Stretch"].tap()
        app.buttons["close-controls-panel"].tap()

        app.buttons["record-loop"].tap()
        XCTAssertTrue(app.staticTexts["Recording"].waitForExistence(timeout: 5))
        openKeys()
        app.buttons["Play D3"].tap()
        app.buttons["close-controls-panel"].tap()
        if app.staticTexts["Recording"].exists { app.buttons["record-loop"].tap() }
        XCTAssertTrue(app.staticTexts["Loop playing"].waitForExistence(timeout: 5))

        app.buttons["record-loop"].tap()
        XCTAssertTrue(app.buttons["Replace loop"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Loop playing"].exists)

        app.buttons["play-loop"].tap()
        XCTAssertTrue(app.staticTexts["Loop paused"].waitForExistence(timeout: 5))
        app.buttons["clear-loop"].tap()
        let undo = app.buttons["undo-clear-loop"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertTrue(app.staticTexts["Loop paused"].waitForExistence(timeout: 5))

        app.buttons["field-tools"].tap()
        app.buttons["recenter-field"].tap()
        XCTAssertTrue(app.staticTexts["Loop paused"].waitForExistence(timeout: 5))

        exit.tap()
        XCTAssertTrue(app.buttons["Leave field"].waitForExistence(timeout: 5))
        app.buttons["Stay"].tap()
        XCTAssertTrue(app.staticTexts["Loop paused"].exists)
        app.buttons["clear-loop"].tap()

        app.buttons["field-tools"].tap()
        app.buttons["minimize-controls"].tap()
        XCTAssertTrue(app.buttons["expand-controls"].waitForExistence(timeout: 5))
        XCTAssertTrue(exit.exists)
        XCTAssertFalse(app.buttons["sound-controls"].exists)
        app.buttons["expand-controls"].tap()
        XCTAssertTrue(app.buttons["sound-controls"].exists)

        app.buttons["field-tools"].tap()
        app.buttons["help-field"].tap()
        XCTAssertTrue(app.staticTexts["Playing with light"].waitForExistence(timeout: 5))
        app.buttons["close-controls-panel"].tap()
        app.buttons["field-tools"].tap()
        app.buttons["reset-field"].tap()
        exit.tap()
        XCTAssertTrue(enter.waitForExistence(timeout: 15))
        XCTAssertTrue(enter.isEnabled)
    }
}
