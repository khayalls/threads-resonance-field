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
        XCTAssertEqual(app.buttons.matching(identifier: "exit-field").count, 1)

        func reveal(_ element: XCUIElement) {
            let scroll = app.scrollViews.firstMatch
            for _ in 0..<8 {
                if element.isHittable { return }
                scroll.swipeUp()
            }
            XCTAssertTrue(element.isHittable, app.debugDescription)
        }
        func tapTool(_ id: String) { let button = app.buttons[id]; reveal(button); button.tap() }

        app.buttons["sound-controls"].tap()
        XCTAssertTrue(app.buttons["Dawn"].waitForExistence(timeout: 5))
        app.buttons["Dawn"].tap()
        XCTAssertTrue(app.staticTexts["D major · open and luminous"].exists)
        app.buttons["Nocturne"].tap()
        let echo = app.switches["echo-trails"]
        XCTAssertTrue(echo.exists); echo.tap(); echo.tap()
        let volume = app.sliders["Sound level"]
        XCTAssertTrue(volume.waitForExistence(timeout: 5), app.debugDescription)
        reveal(app.buttons["Decrease sound level"])
        app.buttons["Decrease sound level"].tap()
        XCTAssertTrue(app.staticTexts["60%"].exists)
        app.buttons["Increase sound level"].tap()
        XCTAssertTrue(app.staticTexts["65%"].exists)
        let ambient = app.switches["ambient-notes"]
        XCTAssertTrue(ambient.exists)
        reveal(ambient)
        ambient.tap()
        app.buttons["close-controls-panel"].tap()

        func openKeys() {
            app.buttons["field-tools"].tap()
            let play = app.buttons["play-controls"]
            XCTAssertTrue(play.waitForExistence(timeout: 5))
            reveal(play); play.tap()
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
        tapTool("recenter-field")
        XCTAssertTrue(app.staticTexts["Loop paused"].waitForExistence(timeout: 5))

        exit.tap()
        XCTAssertTrue(app.buttons["Leave field"].waitForExistence(timeout: 5))
        app.buttons["Stay"].tap()
        XCTAssertTrue(app.staticTexts["Loop paused"].exists)
        app.buttons["clear-loop"].tap()

        app.buttons["field-tools"].tap()
        tapTool("minimize-controls")
        XCTAssertTrue(app.buttons["expand-controls"].waitForExistence(timeout: 5))
        XCTAssertTrue(exit.exists)
        XCTAssertFalse(app.buttons["sound-controls"].exists)
        app.buttons["expand-controls"].tap()
        XCTAssertTrue(app.buttons["sound-controls"].exists)

        app.buttons["field-tools"].tap()
        tapTool("help-field")
        XCTAssertTrue(app.staticTexts["Playing with light"].waitForExistence(timeout: 5))
        app.buttons["close-controls-panel"].tap()
        app.buttons["field-tools"].tap()
        tapTool("reset-field")
        app.buttons["field-tools"].tap()
        app.buttons["Original"].tap()
        app.buttons["Closer"].tap()
        tapTool("restart-hands")
        app.buttons["close-controls-panel"].tap()
        app.buttons["field-tools"].tap()
        tapTool("guided-play")
        XCTAssertTrue(app.buttons["exit-field"].exists)
        exit.tap()
        XCTAssertTrue(enter.waitForExistence(timeout: 15))
        XCTAssertTrue(enter.isEnabled)
        // Repeated immersion must reuse the single native control window.
        for _ in 0..<3 {
            enter.tap()
            XCTAssertTrue(exit.waitForExistence(timeout: 20))
            XCTAssertEqual(app.buttons.matching(identifier: "exit-field").count, 1)
            exit.tap()
            XCTAssertTrue(enter.waitForExistence(timeout: 15))
        }
    }
}
