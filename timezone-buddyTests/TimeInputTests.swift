// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import timezone_buddy

struct TimeInputTests {
    @Test
    func parsesColonAndCompactForms() throws {
        let expected = TimeInput.Value(hour: 9, minute: 41)

        #expect(TimeInput.parse("9:41") == expected)
        #expect(TimeInput.parse("09:41") == expected)
        #expect(TimeInput.parse("941") == expected)
        #expect(TimeInput.parse("0941") == expected)
    }

    @Test
    func rejectsInvalidTimes() {
        #expect(TimeInput.parse("24:00") == nil)
        #expect(TimeInput.parse("12:60") == nil)
        #expect(TimeInput.parse("12:345") == nil)
        #expect(TimeInput.parse("") == nil)
    }

    @Test
    func sanitizesPastedInput() {
        #expect(TimeInput.sanitize("12:34 PM") == "12:34")
        #expect(TimeInput.sanitize("9:41") == "9:41")
    }

    @Test
    func completenessMatchesLiveEditingRules() {
        #expect(TimeInput.isComplete("9:41"))
        #expect(TimeInput.isComplete("0941"))
        #expect(!TimeInput.isComplete("9:4"))
        #expect(!TimeInput.isComplete("941"))
    }

    @Test
    func formatsWithLeadingZeroes() {
        #expect(TimeInput.format(hour: 9, minute: 4) == "09:04")
        #expect(TimeInput.format(hour: 23, minute: 59) == "23:59")
    }
}
