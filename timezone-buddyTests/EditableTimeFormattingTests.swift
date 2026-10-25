// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import timezone_buddy

@MainActor
struct EditableTimeFormattingTests {
    @Test
    func combinesDayAndTimeInTheRequestedZone() throws {
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        let day = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))
        )

        let target = try #require(
            TimeFormatting.date(on: day, atHour: 9, minute: 41, in: newYork)
        )
        let components = TimeFormatting.timeComponents(target, in: newYork)

        #expect(components.hour == 9)
        #expect(components.minute == 41)
    }

    @Test
    func rejectsTimesSkippedByDaylightSaving() throws {
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        let day = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))
        )

        #expect(TimeFormatting.date(on: day, atHour: 2, minute: 30, in: newYork) == nil)
    }

    @Test
    func rejectsOutOfRangeComponents() throws {
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let day = Date(timeIntervalSince1970: 0)

        #expect(TimeFormatting.date(on: day, atHour: 24, minute: 0, in: newYork) == nil)
        #expect(TimeFormatting.date(on: day, atHour: 12, minute: 60, in: newYork) == nil)
    }

    @Test
    func editableTimeUsesTwentyFourHourFormat() throws {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 20, minute: 19))
        )

        #expect(TimeFormatting.editableTime(date, in: tokyo) == "20:19")
    }
}
