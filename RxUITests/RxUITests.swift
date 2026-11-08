//
//  RxUITests.swift
//  RxUITests
//

import XCTest

final class RxUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddButtonOpensSheet() throws {
        let app = XCUIApplication()
        app.launch()

        // Prefer Sources tab if present
        let sourcesTab = app.tabBars.buttons["Sources"]
        if sourcesTab.waitForExistence(timeout: 5) {
            sourcesTab.tap()
        }

        let addButton = app.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 8), "Add button not found on Sources")
        addButton.tap()

        let title = app.navigationBars["Add Source"]
        let nameField = app.textFields["Source Name"]
        let cancel = app.buttons["Cancel"]

        let sheetVisible = title.waitForExistence(timeout: 5)
            || nameField.waitForExistence(timeout: 2)
            || cancel.waitForExistence(timeout: 2)

        // Capture post-tap screenshot into Desktop for inspection
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "AfterAddTap"
        attachment.lifetime = .keepAlways
        add(attachment)

        let png = shot.pngRepresentation
        let out = URL(fileURLWithPath: NSHomeDirectory() + "/Desktop/rx-after-add.png")
        try? png.write(to: out)

        XCTAssertTrue(sheetVisible, "Expected Add Source sheet after tapping Add")
    }
}
