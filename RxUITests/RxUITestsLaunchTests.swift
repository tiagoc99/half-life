// Launch screenshot test. runsForEachTargetApplicationUIConfiguration is true, so XCTest runs the test once for each UI configuration, including light and dark appearance.
// continueAfterFailure is false. testLaunch starts the app and attaches a screenshot named Launch Screen. The comment inside the method is the placeholder for steps to add before that screenshot.

//
//  RxUITestsLaunchTests.swift
//  RxUITests
//
//  Created by Tiago Costa on 08/10/2025.
//

import XCTest

// XCTest case that records the first screen after launch.
final class RxUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
