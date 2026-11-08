// UI walk across Settings, Sources, and Calculator. setUp sets continueAfterFailure to true, so a failed check is recorded and later steps still run.
// saveShot attaches a screenshot and writes a PNG under Desktop/Rx Proto2/debug-captures, creating that folder when it can.
// On Settings, when the controls exist, the test sets Distance to inches, Radiation to Bq, and Default Material to Stainless Steel. It moves the first slider to the middle of its range and, when a second slider exists, moves that one to three quarters of its range. The first slider is the correction ratio, 0 to 100 percent. The second is the low-activity warning, 20 to 80 percent. It then chooses the Type IX films category.
// The test requires a Restore Purchases button and an element whose label contains Remove Ads.
// On Sources it taps Add when that button exists, types the name UITest Ir-192, and types the activity 3.7e12. With the radiation unit set to Bq, 3.7e12 becquerels is 100 curies, because one curie is 3.7e10 becquerels. Save is tapped when it is enabled.
// On Calculator it tries a source label containing UITest, then Seeded, then another menu button. It types an SFD of 27.56 and a thickness of 0.47. After the switch to inches, Calculate multiplies by 25.4, so those entries are about 700 mm and about 12 mm. Calculate is tapped when it is enabled.
// The test then looks for a static text label that begins with Time: and for the static text Ad placeholder. It opens Settings and Calculator again for the last screenshots.

import XCTest

final class ManualFlowUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }

    // Stores a named screenshot on the test result and as a PNG on the Desktop.
    private func saveShot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: shot)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        let dir = URL(fileURLWithPath: NSHomeDirectory() + "/Desktop/Rx Proto2/debug-captures")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: dir.appendingPathComponent(name + ".png"))
    }

    @MainActor
    // Changes settings, adds a source, runs Calculate, and checks the purchase controls it can see.
    func testSettingsCalculatorSubscriptionFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8))
        settingsTab.tap()
        saveShot("02-settings-initial")

        // Distance -> in
        if app.buttons["Distance"].waitForExistence(timeout: 3) {
            app.buttons["Distance"].tap()
            if app.buttons["in"].waitForExistence(timeout: 2) { app.buttons["in"].tap() }
        }
        // Radiation -> Bq
        if app.buttons["Radiation"].waitForExistence(timeout: 2) {
            app.buttons["Radiation"].tap()
            if app.buttons["Bq"].waitForExistence(timeout: 2) { app.buttons["Bq"].tap() }
        }
        // Default Material -> Stainless Steel
        if app.buttons["Default Material"].waitForExistence(timeout: 2) {
            app.buttons["Default Material"].tap()
            if app.buttons["Stainless Steel"].waitForExistence(timeout: 2) {
                app.buttons["Stainless Steel"].tap()
            }
        }
        // Correction ~50%
        if app.sliders.firstMatch.waitForExistence(timeout: 2) {
            app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 0.5)
        }
        // Film Type -> Type IX
        if app.buttons["Film Type"].waitForExistence(timeout: 2) {
            app.buttons["Film Type"].tap()
            if app.buttons["Type IX films"].waitForExistence(timeout: 2) {
                app.buttons["Type IX films"].tap()
            }
        }
        // Low activity second slider
        if app.sliders.count >= 2 {
            app.sliders.element(boundBy: 1).adjust(toNormalizedSliderPosition: 0.75)
        }

        XCTAssertTrue(app.buttons["Restore Purchases"].waitForExistence(timeout: 4), "Restore Purchases missing")
        let removeAds = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "Remove Ads")).firstMatch
        XCTAssertTrue(removeAds.waitForExistence(timeout: 4), "Remove Ads UI missing")
        saveShot("03-settings-changed")

        // Sources + Add
        let sourcesTab = app.tabBars.buttons["Sources"]
        XCTAssertTrue(sourcesTab.waitForExistence(timeout: 5))
        sourcesTab.tap()
        saveShot("04-sources")

        if app.buttons["Add"].waitForExistence(timeout: 3) {
            app.buttons["Add"].tap()
            let nameField = app.textFields["Source Name"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5))
            nameField.tap()
            nameField.typeText("UITest Ir-192")
            let act = app.textFields.matching(NSPredicate(format: "label CONTAINS[c] %@", "Initial Activity")).firstMatch
            if act.waitForExistence(timeout: 2) {
                act.tap()
                act.typeText("3.7e12") // ~100 Ci if unit is Bq
            } else if app.textFields.count >= 2 {
                app.textFields.element(boundBy: 1).tap()
                app.textFields.element(boundBy: 1).typeText("3.7e12")
            }
            let save = app.buttons["Save"]
            XCTAssertTrue(save.waitForExistence(timeout: 3))
            if save.isEnabled { save.tap() }
            saveShot("05-after-add-source")
        } else {
            saveShot("05-sources-already-populated")
        }

        // Calculator
        let calcTab = app.tabBars.buttons["Calculator"]
        XCTAssertTrue(calcTab.waitForExistence(timeout: 5))
        calcTab.tap()
        saveShot("06-calculator")

        if app.buttons["Source"].waitForExistence(timeout: 3) {
            app.buttons["Source"].tap()
            let uitest = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "UITest")).firstMatch
            let seeded = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Seeded")).firstMatch
            if uitest.waitForExistence(timeout: 2) {
                uitest.tap()
            } else if seeded.waitForExistence(timeout: 2) {
                seeded.tap()
            } else {
                // Fallback: any non-placeholder source row in the menu
                let menuItems = app.buttons
                for i in 0..<min(menuItems.count, 20) {
                    let b = menuItems.element(boundBy: i)
                    let l = b.label
                    if l.count > 2 && l != "Select a source" && l != "Source" && l != "Cancel"
                        && !l.contains("Calculator") && !l.contains("Settings") && !l.contains("Sources")
                        && !l.contains("tab") {
                        b.tap()
                        break
                    }
                }
            }
        }

        let sfd = app.textFields.matching(NSPredicate(format: "label CONTAINS[c] %@", "SFD")).firstMatch
        let thick = app.textFields.matching(NSPredicate(format: "label CONTAINS[c] %@", "Thickness")).firstMatch
        if sfd.waitForExistence(timeout: 3) { sfd.tap(); sfd.typeText("27.56") } // ~700mm in inches
        if thick.waitForExistence(timeout: 2) { thick.tap(); thick.typeText("0.47") } // ~12mm

        if app.keyboards.buttons["Return"].exists { app.keyboards.buttons["Return"].tap() }

        let calcBtn = app.buttons["Calculate Exposure Time"]
        XCTAssertTrue(calcBtn.waitForExistence(timeout: 4), "Calculate button missing")
        if calcBtn.isEnabled {
            calcBtn.tap()
        } else {
            XCTFail("Calculate disabled — need source + positive SFD/thickness")
        }

        let timeLabel = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Time:")).firstMatch
        XCTAssertTrue(timeLabel.waitForExistence(timeout: 5), "Expected Time: result")
        saveShot("07-calculator-result")

        XCTAssertTrue(app.staticTexts["Ad placeholder"].waitForExistence(timeout: 3), "Ad placeholder missing when unsubscribed")

        settingsTab.tap()
        saveShot("08-settings-persist-check")
        calcTab.tap()
        saveShot("09-calculator-units-check")
    }
}
