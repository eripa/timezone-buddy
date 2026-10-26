// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation

/// A single ticking source of truth for the current time.
///
/// Keeping the clock in one observable object means the menu bar label and the
/// drop-down panel always agree and refresh together.
@MainActor
@Observable
final class ClockModel {
    private(set) var now: Date = .now

    @ObservationIgnored private var ticker: Task<Void, Never>?

    init() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                let current = Date.now
                self.now = current

                // Every surface shows hours and minutes only, so wake on the
                // next minute boundary instead of once a second.
                let secondsIntoMinute = current.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 60)

                try? await Task.sleep(
                    for: .seconds(60 - secondsIntoMinute),
                    tolerance: .seconds(0.2)
                )
            }
        }
    }
}

/// The offset applied by the "time travel" slider.
///
/// The offset is intentionally session-only: restarting the app always starts
/// back at the present moment.
@MainActor
@Observable
final class TimeTravelState {
    static let step: Double = 15

    var offsetMinutes: Double = 0

    var offset: TimeInterval {
        offsetMinutes * 60
    }

    var isNow: Bool {
        abs(offsetMinutes) < 0.01
    }

    /// The slider range for a window of `hours` in each direction.
    static func range(hours: Int) -> ClosedRange<Double> {
        let minutes = Double(max(hours, 1)) * 60
        return -minutes...minutes
    }

    /// Keeps the current offset inside a newly selected window.
    func clamp(toHours hours: Int) {
        let limit = Double(max(hours, 1)) * 60
        offsetMinutes = min(max(offsetMinutes, -limit), limit)
    }

    /// The number of whole hours needed to represent an offset in the slider.
    static func requiredHours(forOffsetMinutes offsetMinutes: Double) -> Int {
        let totalMinutes = Int(abs(offsetMinutes).rounded())
        return (totalMinutes + 59) / 60
    }

    /// Sets the offset only when it fits inside the given slider window.
    @discardableResult
    func setOffset(minutes: Double, maximumHours: Int) -> Bool {
        let limit = Double(max(maximumHours, 1)) * 60
        guard abs(minutes) <= limit else { return false }
        offsetMinutes = minutes
        return true
    }

    /// The date that should be displayed for a given real date.
    func date(from now: Date) -> Date {
        now.addingTimeInterval(offset)
    }

    func reset() {
        offsetMinutes = 0
    }

    /// A compact description such as "+8h" or "−2h 30m".
    var offsetDescription: String {
        guard !isNow else { return "Now" }

        let totalMinutes = Int(abs(offsetMinutes).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let sign = offsetMinutes > 0 ? "+" : "−"

        if hours == 0 {
            return "\(sign)\(minutes)m"
        }
        if minutes == 0 {
            return "\(sign)\(hours)h"
        }
        return "\(sign)\(hours)h \(minutes)m"
    }

    /// A fuller description used by accessibility and the slider caption.
    var accessibilityDescription: String {
        isNow ? "Now" : "\(offsetDescription) from now"
    }
}

// MARK: - Searching Time Zones

/// A searchable description of one time zone known to the system.
///
/// The time zone database names a single reference city per zone, so Calgary
/// has no identifier of its own: it is covered by `America/Edmonton`, just as
/// Miami is covered by `America/New_York`. An entry gathers the friendly names,
/// the abbreviations, and the curated aliases that make a zone findable
/// without already knowing its reference city.
struct TimeZoneEntry: Identifiable, Hashable {
    /// The IANA identifier, e.g. "America/Edmonton".
    let identifier: String
    /// The reference city taken from the identifier, e.g. "Edmonton".
    let cityName: String
    /// The localized zone name, e.g. "Mountain Time".
    let zoneName: String
    /// The standard and daylight-saving short forms, e.g. ["MST", "MDT"].
    let abbreviations: [String]
    /// Other names for the zone, e.g. ["Calgary"].
    let aliases: [String]
    /// Neutral short forms such as "MT", which Foundation doesn't expose.
    let genericShortNames: [String]
    /// Lower values sort first when several zones match a query equally well.
    let priority: Int

    var id: String { identifier }

    var timeZone: TimeZone {
        TimeZone(identifier: identifier) ?? .current
    }

    /// "MST/MDT", or "MST" for a zone that doesn't observe daylight saving time.
    var abbreviationDescription: String {
        abbreviations.joined(separator: "/")
    }

    /// The zone's friendly name, falling back to the identifier.
    var displayName: String {
        zoneName.isEmpty ? identifier : zoneName
    }

    /// "America/New_York" -> "New York".
    static func cityName(for identifier: String) -> String {
        guard let city = identifier.split(separator: "/").last else {
            return identifier
        }
        return city.replacingOccurrences(of: "_", with: " ")
    }
}

extension TimeZoneEntry {
    /// A zone that matched a search query, along with why it matched.
    struct Match: Identifiable {
        let entry: TimeZoneEntry
        let score: Int
        /// The alias the query hit, when the match came from something other
        /// than the zone's own city or name — for example "Calgary".
        let matchedAlias: String?

        var id: String { entry.identifier }
    }

    /// Every zone known to the system, built once on first use.
    ///
    /// Building this calls `localizedName`, which goes through ICU, so it is
    /// deliberately a one-time cost and must never run per keystroke in a view
    /// body.
    static let all: [TimeZoneEntry] = makeAll()

    /// Returns ranked matches for a query, or every zone when the query is
    /// empty. Kept out of the view so the ranking rules can be unit tested.
    static func search(_ query: String) -> [Match] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return all.map { Match(entry: $0, score: 0, matchedAlias: nil) }
        }

        return all
            .compactMap { $0.match(for: trimmed) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.entry.priority != rhs.entry.priority {
                    return lhs.entry.priority < rhs.entry.priority
                }
                return lhs.entry.cityName < rhs.entry.cityName
            }
    }

    /// Scores this zone against a query, or returns `nil` when it doesn't match.
    ///
    /// Matching works on whole words rather than raw substrings, because a
    /// substring search for "EST" also hits "W(est) Africa Time", which is only
    /// noise. Exact city and abbreviation hits score highest so the zone people
    /// most likely mean arrives first.
    func match(for query: String) -> Match? {
        let needle = Self.normalized(query)
        guard !needle.isEmpty else { return nil }

        var best = 0
        var matchedAlias: String?

        func consider(_ text: String, exact: Int, prefix: Int, word: Int, alias: String? = nil) {
            let score = Self.score(text, for: needle, exact: exact, prefix: prefix, word: word)
            guard score > best else { return }
            best = score
            matchedAlias = alias
        }

        consider(cityName, exact: 100, prefix: 88, word: 70)
        consider(identifier, exact: 96, prefix: 58, word: 52)
        consider(zoneName, exact: 92, prefix: 86, word: 72)

        // Abbreviations are short enough that prefix matching would only add
        // noise, so they match exactly or not at all.
        for abbreviation in abbreviations {
            consider(abbreviation, exact: 94, prefix: 0, word: 0)
        }
        for name in genericShortNames {
            consider(name, exact: 93, prefix: 0, word: 0)
        }
        for alias in aliases {
            consider(alias, exact: 90, prefix: 84, word: 66, alias: alias)
        }

        guard best > 0 else { return nil }
        return Match(entry: self, score: best, matchedAlias: matchedAlias)
    }

    /// Folds a string down to plain lowercase words so that
    /// "America/New_York", "montréal", and "Montreal" all compare the same way.
    private static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func score(
        _ text: String,
        for query: String,
        exact: Int,
        prefix: Int,
        word: Int
    ) -> Int {
        let candidate = normalized(text)
        guard !candidate.isEmpty else { return 0 }

        if candidate == query { return exact }
        if prefix > 0, candidate.hasPrefix(query) { return prefix }
        guard word > 0 else { return 0 }

        // Match on word boundaries so "new york" is found inside
        // "America/New_York" without "est" matching "west".
        if " \(candidate) ".contains(" \(query) ") { return word }
        if candidate.split(separator: " ").contains(where: { $0.hasPrefix(query) }) {
            return word
        }
        return 0
    }

    private static func makeAll() -> [TimeZoneEntry] {
        let aliasIndex = ZoneCuration.aliasIndex
        let shortNames = ZoneCuration.shortNamesByIdentifier

        // "UTC" resolves through `TimeZone(identifier:)` but is missing from
        // `knownTimeZoneIdentifiers`, so the curated extras are merged in.
        let identifiers = Set(
            TimeZone.knownTimeZoneIdentifiers + ZoneCuration.additionalIdentifiers
        ).sorted()

        // An alias that repeats a reference city would list the same place
        // twice, so those are dropped: "Montreal" is already a zone.
        let referenceCities = Set(identifiers.map { normalized(cityName(for: $0)) })

        return identifiers
            .compactMap { identifier in
                guard let timeZone = TimeZone(identifier: identifier) else { return nil }

                let city = cityName(for: identifier)
                let correction = ZoneCuration.corrections[identifier]
                return TimeZoneEntry(
                    identifier: identifier,
                    cityName: city,
                    zoneName: correction?.name
                        ?? timeZone.localizedName(for: .generic, locale: .current) ?? city,
                    abbreviations: correction?.abbreviations ?? abbreviations(for: timeZone),
                    aliases: (aliasIndex[identifier] ?? []).filter {
                        !referenceCities.contains(normalized($0))
                    },
                    genericShortNames: shortNames[identifier] ?? [],
                    priority: ZoneCuration.priority[identifier]
                        ?? ZoneCuration.priorityOrder.count
                )
            }
    }

    /// The standard and daylight-saving short forms, e.g. ["MST", "MDT"].
    ///
    /// Abbreviations are resolved against `en_US` because the current locale
    /// isn't guaranteed to define them — with a regionless locale the system
    /// answers "GMT-6" instead of "MST". Those placeholders are dropped since
    /// the row already shows the offset.
    private static func abbreviations(for timeZone: TimeZone) -> [String] {
        let names = [TimeZone.NameStyle.shortStandard, .shortDaylightSaving]
            .compactMap { timeZone.localizedName(for: $0, locale: abbreviationLocale) }

        var seen = Set<String>()
        return names.filter { !$0.hasPrefix("GMT") && seen.insert($0).inserted }
    }

    private static let abbreviationLocale = Locale(identifier: "en_US")
}

/// Hand-written naming data that the system's time zone database doesn't carry.
private enum ZoneCuration {
    /// Zones the system knows but omits from `knownTimeZoneIdentifiers`.
    ///
    /// "UTC" resolves through `TimeZone(identifier:)`, yet the identifier list
    /// only names the zero-offset zone "GMT", so UTC would otherwise be
    /// impossible to add.
    static let additionalIdentifiers = ["UTC"]

    /// Corrections for zones the system describes misleadingly.
    ///
    /// Foundation treats UTC as the same zone as GMT and reports its name as
    /// "Greenwich Mean Time" with the abbreviation "GMT", which would make the
    /// row indistinguishable from GMT. The empty abbreviation list drops the
    /// badge because the city name already is the abbreviation.
    static let corrections: [String: (name: String, abbreviations: [String])] = [
        "UTC": ("Coordinated Universal Time", [])
    ]

    /// Other names for a zone, keyed by the zone they resolve to.
    ///
    /// These are curated rather than generated: guessing which reference city
    /// covers a region is exactly how the wrong clock gets added. The list is
    /// meant to grow as gaps turn up. An alias that repeats an existing
    /// reference city is ignored, so listing one is harmless.
    static let aliases: [String: String] = [
        // Canada
        "Alberta": "America/Edmonton",
        "Banff": "America/Edmonton",
        "Calgary": "America/Edmonton",
        "Jasper": "America/Edmonton",
        "Lethbridge": "America/Edmonton",
        "Red Deer": "America/Edmonton",
        "British Columbia": "America/Vancouver",
        "Kelowna": "America/Vancouver",
        "Victoria": "America/Vancouver",
        "Whistler": "America/Vancouver",
        "Manitoba": "America/Winnipeg",
        "Saskatchewan": "America/Regina",
        "Saskatoon": "America/Regina",
        "Newfoundland": "America/St_Johns",
        "New Brunswick": "America/Halifax",
        "Nova Scotia": "America/Halifax",
        "Prince Edward Island": "America/Halifax",
        "Charlottetown": "America/Halifax",
        "Fredericton": "America/Halifax",
        "Moncton": "America/Halifax",
        "Montreal": "America/Toronto",
        "Ontario": "America/Toronto",
        "Ottawa": "America/Toronto",
        "Quebec": "America/Toronto",
        "Quebec City": "America/Toronto",
        "Yukon": "America/Whitehorse",
        "Northwest Territories": "America/Yellowknife",
        "Nunavut": "America/Iqaluit",

        // United States — Eastern
        "Atlanta": "America/New_York",
        "Baltimore": "America/New_York",
        "Boston": "America/New_York",
        "Buffalo": "America/New_York",
        "Charlotte": "America/New_York",
        "Cleveland": "America/New_York",
        "Columbus": "America/New_York",
        "Connecticut": "America/New_York",
        "Florida": "America/New_York",
        "Fort Lauderdale": "America/New_York",
        "Georgia": "America/New_York",
        "Hartford": "America/New_York",
        "Jacksonville": "America/New_York",
        "Maryland": "America/New_York",
        "Massachusetts": "America/New_York",
        "Miami": "America/New_York",
        "North Carolina": "America/New_York",
        "Ohio": "America/New_York",
        "Orlando": "America/New_York",
        "Pennsylvania": "America/New_York",
        "Philadelphia": "America/New_York",
        "Pittsburgh": "America/New_York",
        "Providence": "America/New_York",
        "Raleigh": "America/New_York",
        "Rhode Island": "America/New_York",
        "Richmond": "America/New_York",
        "Tampa": "America/New_York",
        "Virginia": "America/New_York",
        "Washington DC": "America/New_York",
        "West Palm Beach": "America/New_York",

        // United States — Central
        "Alabama": "America/Chicago",
        "Arkansas": "America/Chicago",
        "Austin": "America/Chicago",
        "Birmingham": "America/Chicago",
        "Dallas": "America/Chicago",
        "Des Moines": "America/Chicago",
        "Houston": "America/Chicago",
        "Iowa": "America/Chicago",
        "Kansas City": "America/Chicago",
        "Little Rock": "America/Chicago",
        "Louisiana": "America/Chicago",
        "Memphis": "America/Chicago",
        "Milwaukee": "America/Chicago",
        "Minneapolis": "America/Chicago",
        "Minnesota": "America/Chicago",
        "Mississippi": "America/Chicago",
        "Missouri": "America/Chicago",
        "Nashville": "America/Chicago",
        "Nebraska": "America/Chicago",
        "New Orleans": "America/Chicago",
        "Oklahoma": "America/Chicago",
        "Oklahoma City": "America/Chicago",
        "Omaha": "America/Chicago",
        "Saint Louis": "America/Chicago",
        "San Antonio": "America/Chicago",
        "Tennessee": "America/Chicago",
        "Texas": "America/Chicago",
        "Wisconsin": "America/Chicago",

        // United States — Mountain
        "Albuquerque": "America/Denver",
        "Billings": "America/Denver",
        "Cheyenne": "America/Denver",
        "Colorado": "America/Denver",
        "Idaho": "America/Boise",
        "Montana": "America/Denver",
        "New Mexico": "America/Denver",
        "Salt Lake City": "America/Denver",
        "Santa Fe": "America/Denver",
        "Utah": "America/Denver",
        "Wyoming": "America/Denver",

        // United States — Arizona, Alaska, Hawaii
        "Arizona": "America/Phoenix",
        "Scottsdale": "America/Phoenix",
        "Tucson": "America/Phoenix",
        "Alaska": "America/Anchorage",
        "Fairbanks": "America/Anchorage",
        "Juneau": "America/Anchorage",
        "Hawaii": "Pacific/Honolulu",
        "Maui": "Pacific/Honolulu",

        // United States — Pacific
        "California": "America/Los_Angeles",
        "Fresno": "America/Los_Angeles",
        "Las Vegas": "America/Los_Angeles",
        "Nevada": "America/Los_Angeles",
        "Oakland": "America/Los_Angeles",
        "Oregon": "America/Los_Angeles",
        "Portland": "America/Los_Angeles",
        "Sacramento": "America/Los_Angeles",
        "San Diego": "America/Los_Angeles",
        "San Francisco": "America/Los_Angeles",
        "San Jose": "America/Los_Angeles",
        "Seattle": "America/Los_Angeles",
        "Tacoma": "America/Los_Angeles",
        "Washington State": "America/Los_Angeles",

        // Global
        "Zulu": "UTC",
        "Zulu Time": "UTC"
    ]

    /// Neutral short forms such as "MT".
    ///
    /// Foundation only exposes the standard and daylight-saving variants
    /// ("MST"/"MDT"), so the form people actually type needs a small table.
    static let genericAbbreviations: [String: String] = [
        "AT": "America/Halifax",
        "CT": "America/Chicago",
        "ET": "America/New_York",
        "MT": "America/Denver",
        "PT": "America/Los_Angeles"
    ]

    /// The zones people ask for most, used only to break ties: "EST" matches
    /// every Eastern zone, and New York should outrank Atikokan.
    static let priorityOrder: [String] = [
        "America/New_York", "America/Chicago", "America/Denver",
        "America/Los_Angeles", "America/Phoenix", "America/Anchorage",
        "Pacific/Honolulu", "America/Toronto", "America/Vancouver",
        "America/Edmonton", "America/Winnipeg", "America/Halifax",
        "America/St_Johns", "America/Mexico_City", "America/Sao_Paulo",
        "America/Argentina/Buenos_Aires", "America/Bogota", "America/Lima",
        "America/Santiago", "Europe/London", "Europe/Paris", "Europe/Berlin",
        "Europe/Madrid", "Europe/Rome", "Europe/Amsterdam", "Europe/Zurich",
        "Europe/Stockholm", "Europe/Moscow", "Europe/Istanbul", "Africa/Cairo",
        "Africa/Johannesburg", "Africa/Lagos", "Asia/Dubai", "Asia/Calcutta",
        "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Tokyo", "Asia/Seoul",
        "Asia/Singapore", "Asia/Bangkok", "Asia/Jakarta", "Australia/Sydney",
        "Australia/Melbourne", "Australia/Perth", "Pacific/Auckland"
    ]

    static let priority: [String: Int] = Dictionary(
        priorityOrder.enumerated().map { pair in (pair.element, pair.offset) },
        uniquingKeysWith: { first, _ in first }
    )

    /// Aliases grouped by the zone they resolve to.
    static let aliasIndex: [String: [String]] = aliases
        .reduce(into: [String: [String]]()) { result, pair in
            result[pair.value, default: []].append(pair.key)
        }
        .mapValues { $0.sorted() }

    /// Generic short forms grouped by the zone they resolve to.
    static let shortNamesByIdentifier: [String: [String]] = genericAbbreviations
        .reduce(into: [String: [String]]()) { result, pair in
            result[pair.value, default: []].append(pair.key)
        }
        .mapValues { $0.sorted() }
}
