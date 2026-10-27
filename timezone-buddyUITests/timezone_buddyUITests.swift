// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import XCUIAutomation

final class TimezoneBuddyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsWindowOpensAndSwitchesPanes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-openSettingsForTesting"]
        app.launch()

        XCTAssertTrue(app.windows["Settings"].waitForExistence(timeout: 10))

        let generalTab = app.radioButtons["General"]
        XCTAssertTrue(generalTab.waitForExistence(timeout: 5))
        generalTab.click()

        let aboutTab = app.radioButtons["About"]
        XCTAssertTrue(aboutTab.waitForExistence(timeout: 5))
        aboutTab.click()

        let timeZonesTab = app.radioButtons["Time Zones"]
        XCTAssertTrue(timeZonesTab.waitForExistence(timeout: 5))
        timeZonesTab.click()

        XCTAssertTrue(app.buttons["Add Time Zone"].waitForExistence(timeout: 5))
    }
}
