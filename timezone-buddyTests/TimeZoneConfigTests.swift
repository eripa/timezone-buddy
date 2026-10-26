// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import timezone_buddy

struct TimeZoneConfigTests {
    @Test
    func cityNameComesFromIdentifier() {
        let zone = TimeZoneConfig(identifier: "America/New_York")

        #expect(zone.cityName == "New York")
    }

    @Test
    func displayEmojiIsTrimmed() {
        let zone = TimeZoneConfig(identifier: "Europe/London", emoji: "  🇬🇧  ")

        #expect(zone.displayEmoji == "🇬🇧")
    }

    @Test
    func invalidIdentifierFallsBackToGMT() {
        let zone = TimeZoneConfig(identifier: "Not/AZone")

        #expect(zone.timeZone.secondsFromGMT(for: .now) == 0)
    }

    @Test
    func defaultZonesContainUniqueIdentifiers() {
        let zones = TimeZoneConfig.defaultZones()

        #expect(!zones.isEmpty)
        #expect(Set(zones.map(\.identifier)).count == zones.count)
        #expect(zones.first?.identifier == TimeZone.autoupdatingCurrent.identifier)
    }
}
