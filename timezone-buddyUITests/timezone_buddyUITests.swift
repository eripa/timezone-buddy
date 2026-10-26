// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import XCUIAutomation

final class TimezoneBuddyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMenuBarPanelOpensSettings() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10)
                || app.state == .runningBackground
        )

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10))

        app.activate()
        statusItem.click()

        let settingsButton = app.buttons["Settings…"]
        if !settingsButton.waitForExistence(timeout: 2) {
            statusItem.click()
        }

        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.click()

        XCTAssertTrue(app.windows["Settings"].waitForExistence(timeout: 10))
    }
}
