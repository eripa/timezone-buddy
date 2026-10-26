// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Locale-aware time formatting for a specific time zone.
///
/// `DateFormatter` instances are cached per time zone because the panel
/// redraws as the clock and time-travel slider update. The cache is main-actor
/// isolated alongside the views that use it.
@MainActor
enum TimeFormatting {
    private static var timeFormatters: [String: DateFormatter] = [:]
    private static var weekdayFormatters: [String: DateFormatter] = [:]

    /// A localized time such as "9:41 AM" or "09:41", depending on the user's locale.
    static func time(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter: DateFormatter
        if let cached = timeFormatters[timeZone.identifier] {
            formatter = cached
        } else {
            let newFormatter = DateFormatter()
            newFormatter.locale = .autoupdatingCurrent
            newFormatter.timeZone = timeZone
            newFormatter.setLocalizedDateFormatFromTemplate("j:mm")
            timeFormatters[timeZone.identifier] = newFormatter
            formatter = newFormatter
        }
        return formatter.string(from: date)
    }

    /// A short localized weekday name in the given time zone.
    static func weekday(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter: DateFormatter
        if let cached = weekdayFormatters[timeZone.identifier] {
            formatter = cached
        } else {
            let newFormatter = DateFormatter()
            newFormatter.locale = .autoupdatingCurrent
            newFormatter.timeZone = timeZone
            newFormatter.setLocalizedDateFormatFromTemplate("EEE")
            weekdayFormatters[timeZone.identifier] = newFormatter
            formatter = newFormatter
        }
        return formatter.string(from: date)
    }

    /// The zone's offset from GMT at a specific date, e.g. "GMT+9" or "GMT−3:30".
    static func gmtOffset(_ timeZone: TimeZone, at date: Date) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        guard seconds != 0 else { return "GMT" }

        let sign = seconds < 0 ? "−" : "+"
        let totalMinutes = abs(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if minutes == 0 {
            return "GMT\(sign)\(hours)"
        }
        let paddedMinutes = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        return "GMT\(sign)\(hours):\(paddedMinutes)"
    }

    /// How far the zone is from the user's current zone, e.g. "3h ahead".
    static func differenceDescription(_ timeZone: TimeZone, at date: Date) -> String {
        let localSeconds = TimeZone.autoupdatingCurrent.secondsFromGMT(for: date)
        let zoneSeconds = timeZone.secondsFromGMT(for: date)
        let delta = zoneSeconds - localSeconds
        guard delta != 0 else { return "same time as local" }

        let totalMinutes = abs(delta) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        let amount: String
        if hours == 0 {
            amount = "\(minutes)m"
        } else if minutes == 0 {
            amount = "\(hours)h"
        } else {
            amount = "\(hours)h \(minutes)m"
        }

        return delta > 0 ? "\(amount) ahead" : "\(amount) behind"
    }

    /// The zone's calendar day compared with the user's calendar day: "Today",
    /// "Tomorrow", "Yesterday", or a weekday for larger differences.
    static func dayDescription(_ timeZone: TimeZone, at date: Date) -> String {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone
        let zoneDay = calendar.ordinality(of: .day, in: .era, for: date)

        calendar.timeZone = .autoupdatingCurrent
        let localDay = calendar.ordinality(of: .day, in: .era, for: date)

        guard let zoneDay, let localDay else {
            return weekday(date, in: timeZone)
        }

        switch zoneDay - localDay {
        case 0:
            return "Today"
        case 1:
            return "Tomorrow"
        case -1:
            return "Yesterday"
        default:
            let difference = zoneDay - localDay
            return difference > 0 ? "+\(difference) days" : "\(difference) days"
        }
    }

    /// The zone's hour and minute at a date, used by the editable clock fields.
    static func timeComponents(_ date: Date, in timeZone: TimeZone) -> (hour: Int, minute: Int) {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }

    /// A 24-hour, numeric representation used while editing a clock.
    static func editableTime(_ date: Date, in timeZone: TimeZone) -> String {
        let components = timeComponents(date, in: timeZone)
        return TimeInput.format(hour: components.hour, minute: components.minute)
    }

    /// Combines a displayed calendar day with a newly entered time in a zone.
    static func date(
        on day: Date,
        atHour hour: Int,
        minute: Int,
        in timeZone: TimeZone
    ) -> Date? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }

        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone

        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.nanosecond = 0

        guard let target = calendar.date(from: components) else { return nil }

        // Reject times that a daylight-saving transition skipped or moved.
        let verified = calendar.dateComponents([.hour, .minute], from: target)
        guard verified.hour == hour, verified.minute == minute else { return nil }

        return target
    }
}

/// Parsing and formatting for the numeric clock editors.
///
/// Accepts `HH:mm`, `H:mm`, `HHmm`, and `Hmm`. Anything else is rejected, and
/// hours/minutes must be inside valid clock ranges.
enum TimeInput {
    struct Value: Equatable {
        let hour: Int
        let minute: Int
    }

    static func sanitize(_ text: String) -> String {
        var result = ""
        var hasColon = false

        for character in text {
            if character.isNumber {
                result.append(character)
            } else if character == ":", !hasColon {
                result.append(character)
                hasColon = true
            }
        }

        return String(result.prefix(5))
    }

    static func parse(_ text: String) -> Value? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)

        if parts.count == 2 {
            guard !parts[0].isEmpty, !parts[1].isEmpty,
                parts[0].count <= 2, parts[1].count <= 2,
                let hour = Int(parts[0]), let minute = Int(parts[1]),
                (0...23).contains(hour), (0...59).contains(minute)
            else {
                return nil
            }
            return Value(hour: hour, minute: minute)
        }

        guard parts.count == 1 else { return nil }
        let digits = String(parts[0])
        guard digits.allSatisfy(\.isNumber) else { return nil }

        switch digits.count {
        case 4:
            guard let hour = Int(digits.prefix(2)),
                let minute = Int(digits.suffix(2)),
                (0...23).contains(hour), (0...59).contains(minute)
            else {
                return nil
            }
            return Value(hour: hour, minute: minute)
        case 3:
            guard let hour = Int(digits.prefix(1)),
                let minute = Int(digits.suffix(2)),
                (0...23).contains(hour), (0...59).contains(minute)
            else {
                return nil
            }
            return Value(hour: hour, minute: minute)
        default:
            return nil
        }
    }

    /// True once the input has enough digits to apply live, before the user
    /// presses Return or leaves the field.
    static func isComplete(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)

        if parts.count == 2 {
            return parts[0].count >= 1
                && parts[0].count <= 2
                && parts[1].count == 2
        }

        return parts.count == 1
            && trimmed.count == 4
            && trimmed.allSatisfy(\.isNumber)
    }

    static func format(hour: Int, minute: Int) -> String {
        let hourText = hour < 10 ? "0\(hour)" : "\(hour)"
        let minuteText = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(hourText):\(minuteText)"
    }
}
