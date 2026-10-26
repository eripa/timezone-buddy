// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation
import Observation
import SwiftUI

/// How the enabled time zones are presented in the macOS menu bar.
enum MenuBarDisplayMode: String, CaseIterable, Codable, Identifiable {
    case icon
    case inline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .icon: "Single icon"
        case .inline: "Clocks inline"
        }
    }

    var explanation: String {
        switch self {
        case .icon:
            "Show one clock icon in the menu bar. Click it to drop down the full list of time zones."
        case .inline:
            "Show the enabled time zones directly in the menu bar, one after another."
        }
    }
}

/// A time zone the user wants to keep an eye on.
struct TimeZoneConfig: Identifiable, Codable, Hashable {
    var id: UUID
    var identifier: String
    var emoji: String
    var isEnabled: Bool
    /// An optional name shown instead of the reference city, e.g. "Leeds" for
    /// `Europe/London`. Stored exactly as typed; `displayName` trims it.
    var customName: String?

    init(
        id: UUID = UUID(),
        identifier: String,
        emoji: String = "",
        customName: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.identifier = identifier
        self.emoji = emoji
        self.customName = customName
        self.isEnabled = isEnabled
    }

    /// The actual time zone, falling back to the current zone if the stored identifier is invalid.
    var timeZone: TimeZone {
        TimeZone(identifier: identifier) ?? .current
    }

    /// A friendly city name derived from the identifier, e.g. "America/New_York" -> "New York".
    var cityName: String {
        TimeZoneEntry.cityName(for: identifier)
    }

    /// The trimmed custom name, or an empty string when none is set.
    private var trimmedCustomName: String {
        (customName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What to show for this zone: the custom name when there is one,
    /// otherwise the reference city.
    var displayName: String {
        trimmedCustomName.isEmpty ? cityName : trimmedCustomName
    }

    /// True when the zone is shown under a name other than its reference city.
    var hasCustomName: Bool {
        !trimmedCustomName.isEmpty
    }

    /// The emoji without surrounding whitespace, or an empty string when none is set.
    var displayEmoji: String {
        emoji.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A reasonable starter set: the user's zone plus a few well-known cities.
    static func defaultZones() -> [TimeZoneConfig] {
        let localIdentifier = TimeZone.autoupdatingCurrent.identifier
        var zones = [TimeZoneConfig(identifier: localIdentifier, emoji: "📍")]

        let presets = [
            ("America/New_York", "🇺🇸"),
            ("Europe/London", "🇬🇧"),
            ("Asia/Tokyo", "🇯🇵")
        ]

        for (identifier, emoji) in presets where identifier != localIdentifier {
            zones.append(TimeZoneConfig(identifier: identifier, emoji: emoji))
        }

        return zones
    }
}

/// Observable, user-editable application settings backed by `UserDefaults`.
///
/// Writes go through explicit setters so every change is persisted immediately,
/// regardless of whether it came from a `Picker`, a `TextField`, or a list edit.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()
    static let defaultTimeTravelRangeHours = 12
    static let timeTravelRangeLimits = 1...48

    private(set) var displayMode: MenuBarDisplayMode
    private(set) var showEmoji: Bool
    private(set) var hideDockIcon: Bool
    private(set) var timeTravelRangeHours: Int
    private(set) var zones: [TimeZoneConfig]

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = "timezoneBuddy.settings.v1"

    private struct StoredSettings: Codable {
        var displayMode: MenuBarDisplayMode
        var showEmoji: Bool
        var hideDockIcon: Bool
        var zones: [TimeZoneConfig]
        var timeTravelRangeHours: Int?
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(StoredSettings.self, from: data) {
            displayMode = stored.displayMode
            showEmoji = stored.showEmoji
            hideDockIcon = stored.hideDockIcon
            timeTravelRangeHours = Self.clampRangeHours(
                stored.timeTravelRangeHours ?? Self.defaultTimeTravelRangeHours
            )
            zones = stored.zones
        } else {
            displayMode = .icon
            showEmoji = true
            hideDockIcon = true
            timeTravelRangeHours = Self.defaultTimeTravelRangeHours
            zones = TimeZoneConfig.defaultZones()
        }
    }

    var enabledZones: [TimeZoneConfig] {
        zones.filter(\.isEnabled)
    }

    // MARK: - Mutations

    func setDisplayMode(_ mode: MenuBarDisplayMode) {
        displayMode = mode
        persist()
    }

    func setShowEmoji(_ show: Bool) {
        showEmoji = show
        persist()
    }

    func setHideDockIcon(_ hide: Bool) {
        hideDockIcon = hide
        persist()
        DockIconController.apply(hidden: hide)
    }

    func setTimeTravelRangeHours(_ hours: Int) {
        let clamped = Self.clampRangeHours(hours)
        guard clamped != timeTravelRangeHours else { return }
        timeTravelRangeHours = clamped
        persist()
    }

    func setZoneEnabled(id: UUID, enabled: Bool) {
        updateZone(id: id) { $0.isEnabled = enabled }
    }

    func setZoneEmoji(id: UUID, emoji: String) {
        updateZone(id: id) { $0.emoji = emoji }
    }

    /// Sets the name shown instead of the reference city. An empty string
    /// clears it, so the city name comes back.
    ///
    /// The text is stored untrimmed on purpose: trimming on every keystroke
    /// would eat the space the moment someone types "New ".
    func setZoneCustomName(id: UUID, name: String) {
        updateZone(id: id) { $0.customName = name.isEmpty ? nil : name }
    }

    func addZone(identifier: String, emoji: String = "") {
        guard !zones.contains(where: { $0.identifier == identifier }) else { return }
        zones.append(TimeZoneConfig(identifier: identifier, emoji: emoji))
        persist()
    }

    func removeZone(id: UUID) {
        zones.removeAll { $0.id == id }
        persist()
    }

    /// Applies a drag reorder reported by a `reorderContainer` modifier.
    ///
    /// `ReorderDifference` identifies dragged rows by ID instead of by index,
    /// so the rows are lifted out first and then reinserted ahead of the row
    /// they were dropped on.
    func applyReorder(_ difference: ReorderDifference<UUID, ReorderableSingleCollectionIdentifier>) {
        let targetID: UUID?
        switch difference.destination.position {
        case .before(let id):
            targetID = id
        case .end:
            targetID = nil
        }

        moveZones(Set(difference.sources), before: targetID)
    }

    /// Moves the identified zones ahead of `targetID`, or to the end when it is
    /// `nil`. Split from `applyReorder` so the reorder rule can be tested
    /// without constructing SwiftUI's drop-destination type.
    func moveZones(_ ids: Set<UUID>, before targetID: UUID?) {
        let moving = zones.filter { ids.contains($0.id) }
        guard !moving.isEmpty else { return }

        var remaining = zones.filter { !ids.contains($0.id) }
        let insertionIndex = targetID.flatMap { id in
            remaining.firstIndex { $0.id == id }
        } ?? remaining.count

        remaining.insert(contentsOf: moving, at: insertionIndex)
        zones = remaining
        persist()
    }

    func persist() {
        let stored = StoredSettings(
            displayMode: displayMode,
            showEmoji: showEmoji,
            hideDockIcon: hideDockIcon,
            zones: zones,
            timeTravelRangeHours: timeTravelRangeHours
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func clampRangeHours(_ hours: Int) -> Int {
        min(max(hours, timeTravelRangeLimits.lowerBound), timeTravelRangeLimits.upperBound)
    }

    private func updateZone(id: UUID, change: (inout TimeZoneConfig) -> Void) {
        guard let index = zones.firstIndex(where: { $0.id == id }) else { return }
        change(&zones[index])
        persist()
    }
}

/// Applies the Dock icon preference to the running application.
///
/// The app ships as an `LSUIElement` agent by default, so the Dock icon is hidden
/// unless the user turns that setting off.
@MainActor
enum DockIconController {
    static func apply(hidden: Bool) {
        NSApp.setActivationPolicy(hidden ? .accessory : .regular)
    }
}
