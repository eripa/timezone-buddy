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
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.now = .now
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
