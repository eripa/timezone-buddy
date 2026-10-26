// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import timezone_buddy

@MainActor
struct AppSettingsTests {
    @Test
    func defaultsAreStable() throws {
        let defaults = try makeDefaults()
        let settings = AppSettings(defaults: defaults)

        #expect(settings.displayMode == .icon)
        #expect(settings.showEmoji)
        #expect(settings.hideDockIcon)
        #expect(settings.timeTravelRangeHours == AppSettings.defaultTimeTravelRangeHours)
        #expect(settings.zones.count == TimeZoneConfig.defaultZones().count)
    }

    @Test
    func valuesPersistAcrossReloads() throws {
        let defaults = try makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.setDisplayMode(.inline)
        settings.setShowEmoji(false)
        settings.setTimeTravelRangeHours(6)
        settings.addZone(identifier: "Europe/Paris", emoji: "🇫🇷")

        let reloaded = AppSettings(defaults: defaults)

        #expect(reloaded.displayMode == .inline)
        #expect(!reloaded.showEmoji)
        #expect(reloaded.timeTravelRangeHours == 6)
        #expect(reloaded.zones.contains { $0.identifier == "Europe/Paris" })
    }

    @Test
    func timeTravelRangeIsClamped() throws {
        let settings = AppSettings(defaults: try makeDefaults())

        settings.setTimeTravelRangeHours(0)
        #expect(settings.timeTravelRangeHours == 1)

        settings.setTimeTravelRangeHours(100)
        #expect(settings.timeTravelRangeHours == 48)
    }

    @Test
    func zonesCanBeAddedAndRemoved() throws {
        let settings = AppSettings(defaults: try makeDefaults())
        let originalCount = settings.zones.count

        settings.addZone(identifier: "Europe/Paris", emoji: "🇫🇷")
        settings.addZone(identifier: "Europe/Paris", emoji: "🇫🇷")

        #expect(settings.zones.count == originalCount + 1)

        let zone = try #require(settings.zones.first { $0.identifier == "Europe/Paris" })
        settings.removeZone(id: zone.id)

        #expect(!settings.zones.contains { $0.id == zone.id })
    }

    @Test
    func zonesCanBeReordered() throws {
        let settings = AppSettings(defaults: try makeDefaults())
        settings.addZone(identifier: "Europe/Paris")
        let firstID = try #require(settings.zones.first?.id)
        let secondID = try #require(settings.zones.dropFirst().first?.id)

        settings.moveZones([firstID], before: nil)
        #expect(settings.zones.last?.id == firstID)

        settings.moveZones([firstID], before: secondID)
        #expect(settings.zones.first?.id == firstID)
    }

    @Test
    func moveZoneMovesOneStepUpAndDown() throws {
        let settings = AppSettings(defaults: try makeDefaults())
        let firstID = try #require(settings.zones.first?.id)
        let secondID = try #require(settings.zones.dropFirst().first?.id)

        settings.moveZone(id: firstID, by: 1)
        #expect(settings.zones.first?.id == secondID)
        #expect(settings.zones.dropFirst().first?.id == firstID)

        settings.moveZone(id: firstID, by: -1)
        #expect(settings.zones.first?.id == firstID)
    }

    @Test
    func corruptedDataFallsBackToDefaults() throws {
        let defaults = try makeDefaults()
        defaults.set(Data("not json".utf8), forKey: AppSettings.storageKey)

        let settings = AppSettings(defaults: defaults)

        #expect(settings.displayMode == .icon)
        #expect(settings.showEmoji)
        #expect(settings.hideDockIcon)
        #expect(settings.timeTravelRangeHours == AppSettings.defaultTimeTravelRangeHours)
        #expect(settings.zones.count == TimeZoneConfig.defaultZones().count)
    }

    @Test
    func invalidAndDuplicateZonesAreDroppedOnLoad() throws {
        let defaults = try makeDefaults()
        let valid = TimeZoneConfig(identifier: "Europe/London")
        let duplicate = TimeZoneConfig(identifier: "Europe/London")
        let invalid = TimeZoneConfig(identifier: "Not/AZone")
        let raw = RawSettings(
            displayMode: .inline,
            showEmoji: false,
            hideDockIcon: false,
            zones: [valid, duplicate, invalid],
            timeTravelRangeHours: 99
        )
        defaults.set(try JSONEncoder().encode(raw), forKey: AppSettings.storageKey)

        let settings = AppSettings(defaults: defaults)

        #expect(settings.displayMode == .inline)
        #expect(settings.zones.map(\.identifier) == ["Europe/London"])
        #expect(settings.timeTravelRangeHours == 48)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "timezone-buddyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct RawSettings: Codable {
    let displayMode: MenuBarDisplayMode
    let showEmoji: Bool
    let hideDockIcon: Bool
    let zones: [TimeZoneConfig]
    let timeTravelRangeHours: Int?
}
