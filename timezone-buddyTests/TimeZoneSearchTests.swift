// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import timezone_buddy

@MainActor
struct TimeZoneSearchTests {
    @Test
    func findsCalgaryThroughTheEdmontonAlias() throws {
        let match = try #require(TimeZoneEntry.search("Calgary").first)

        #expect(match.entry.identifier == "America/Edmonton")
        #expect(match.matchedAlias == "Calgary")
    }

    @Test
    func prefersNewYorkForEST() throws {
        let match = try #require(TimeZoneEntry.search("EST").first)

        #expect(match.entry.identifier == "America/New_York")
    }

    @Test
    func prefersDenverForMSTAndMountainTime() throws {
        #expect(TimeZoneEntry.search("MST").first?.entry.identifier == "America/Denver")
        #expect(
            TimeZoneEntry.search("Mountain Time").first?.entry.identifier == "America/Denver"
        )
    }

    @Test
    func exactCityBeatsPartialMatches() throws {
        let matches = TimeZoneEntry.search("New York")

        #expect(matches.first?.entry.identifier == "America/New_York")
        #expect(matches.first?.score == 100)
    }

    @Test
    func emptyQueryReturnsEveryZone() {
        #expect(TimeZoneEntry.search("").count == TimeZoneEntry.all.count)
    }

    @Test
    func nonsenseQueryReturnsNoMatches() {
        #expect(TimeZoneEntry.search("zzzz").isEmpty)
    }

    @Test
    func zoneIndexContainsTheExpectedBreadth() {
        #expect(TimeZoneEntry.all.count > 400)
        #expect(Set(TimeZoneEntry.all.map(\.identifier)).count == TimeZoneEntry.all.count)
    }
}
