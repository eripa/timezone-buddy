// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import timezone_buddy

@MainActor
struct TimeFormattingTests {
    @Test
    func gmtOffsetFormatsWholeAndHalfHours() throws {
        let date = Date(timeIntervalSince1970: 0)
        let kolkata = try #require(TimeZone(identifier: "Asia/Kolkata"))
        let newYork = try #require(TimeZone(identifier: "America/New_York"))

        #expect(TimeFormatting.gmtOffset(kolkata, at: date) == "GMT+5:30")
        #expect(TimeFormatting.gmtOffset(newYork, at: date) == "GMT−5")
    }

    @Test
    func gmtOffsetUsesBareGMTForZeroOffset() throws {
        let date = Date(timeIntervalSince1970: 0)
        let utc = try #require(TimeZone(identifier: "UTC"))

        #expect(TimeFormatting.gmtOffset(utc, at: date) == "GMT")
    }
}
