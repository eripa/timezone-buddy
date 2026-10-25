// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import timezone_buddy

@MainActor
struct TimeTravelStateTests {
    @Test
    func rangeCoversRequestedHours() {
        let range = TimeTravelState.range(hours: 12)

        #expect(range.lowerBound == -720)
        #expect(range.upperBound == 720)
    }

    @Test
    func rangeNeverCollapsesToZero() {
        let range = TimeTravelState.range(hours: 0)

        #expect(range.lowerBound == -60)
        #expect(range.upperBound == 60)
    }

    @Test
    func clampKeepsOffsetInsideWindow() {
        let state = TimeTravelState()
        state.offsetMinutes = 90

        state.clamp(toHours: 1)

        #expect(state.offsetMinutes == 60)
    }

    @Test
    func descriptionsCoverCommonOffsets() {
        let state = TimeTravelState()

        #expect(state.offsetDescription == "Now")
        state.offsetMinutes = 15
        #expect(state.offsetDescription == "+15m")
        state.offsetMinutes = 60
        #expect(state.offsetDescription == "+1h")
        state.offsetMinutes = 90
        #expect(state.offsetDescription == "+1h 30m")
        state.offsetMinutes = -90
        #expect(state.offsetDescription == "−1h 30m")
    }

    @Test
    func resetReturnsToNow() {
        let state = TimeTravelState()
        state.offsetMinutes = 120

        state.reset()

        #expect(state.offsetMinutes == 0)
        #expect(state.isNow)
    }

    @Test
    func requiredHoursRoundsUpToCoverOffset() {
        #expect(TimeTravelState.requiredHours(forOffsetMinutes: 0) == 0)
        #expect(TimeTravelState.requiredHours(forOffsetMinutes: 48 * 60) == 48)
        #expect(TimeTravelState.requiredHours(forOffsetMinutes: 48 * 60 + 30) == 49)
    }

    @Test
    func setOffsetRejectsMomentsOutsideTheSliderWindow() {
        let state = TimeTravelState()

        #expect(!state.setOffset(minutes: 49 * 60, maximumHours: 48))
        #expect(state.offsetMinutes == 0)

        #expect(state.setOffset(minutes: 48 * 60, maximumHours: 48))
        #expect(state.offsetMinutes == 48 * 60)
    }
}
