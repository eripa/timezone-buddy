// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Locale-aware time formatting for a specific time zone.
///
/// `DateFormatter` instances are cached per time zone because the drop-down
/// refreshes every second. The cache is main-actor isolated alongside the views
/// that use it.
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
}
