// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import timezone_buddy

struct CustomNameTests {
    @Test
    func customNameOverridesTheCityName() {
        let zone = TimeZoneConfig(identifier: "Europe/London", customName: "Leeds")

        #expect(zone.cityName == "London")
        #expect(zone.displayName == "Leeds")
        #expect(zone.hasCustomName)
    }

    @Test
    func whitespaceOnlyNameFallsBackToTheCity() {
        let zone = TimeZoneConfig(identifier: "Europe/London", customName: "   ")

        #expect(zone.displayName == "London")
        #expect(!zone.hasCustomName)
    }
}

@MainActor
struct CustomNamePersistenceTests {
    @Test
    func customNameSurvivesReloadAndCanBeCleared() throws {
        let suiteName = "timezone-buddyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)
        settings.addZone(identifier: "Europe/London")
        let zone = try #require(settings.zones.first { $0.identifier == "Europe/London" })

        settings.setZoneCustomName(id: zone.id, name: "Leeds")
        #expect(settings.zones.first { $0.id == zone.id }?.displayName == "Leeds")

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.zones.first { $0.id == zone.id }?.displayName == "Leeds")

        reloaded.setZoneCustomName(id: zone.id, name: "")
        #expect(reloaded.zones.first { $0.id == zone.id }?.displayName == "London")
    }
}
