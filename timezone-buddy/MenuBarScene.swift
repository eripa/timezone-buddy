// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// The content shown directly in the macOS menu bar.
struct MenuBarLabel: View {
    let settings: AppSettings
    let clock: ClockModel
    let timeTravel: TimeTravelState

    var body: some View {
        Group {
            switch settings.displayMode {
            case .icon:
                Image(systemName: timeTravel.isNow ? "clock" : "clock.arrow.circlepath")
            case .inline:
                inlineLabel
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    /// The menu bar item's VoiceOver label. Inline clocks need to be read out,
    /// not hidden behind the generic app name.
    private var accessibilityLabel: String {
        guard settings.displayMode == .inline else { return "Timezone Buddy" }

        let times = inlineText(for: settings.enabledZones)
        return times.isEmpty ? "Timezone Buddy" : "Timezone Buddy, \(times)"
    }

    @ViewBuilder
    private var inlineLabel: some View {
        let zones = settings.enabledZones
        if zones.isEmpty {
            Image(systemName: "clock")
        } else {
            Text(inlineText(for: zones))
                .monospacedDigit()
        }
    }

    private func inlineText(for zones: [TimeZoneConfig]) -> String {
        let date = timeTravel.date(from: clock.now)

        let clocks = zones.map { zone -> String in
            let time = TimeFormatting.time(date, in: zone.timeZone)
            let emoji = settings.showEmoji ? zone.displayEmoji : ""
            return emoji.isEmpty ? time : "\(emoji) \(time)"
        }

        var text = clocks.joined(separator: "   ")
        if !timeTravel.isNow {
            text += "   ·   \(timeTravel.offsetDescription)"
        }
        return text
    }
}

/// The drop-down panel shown when the menu bar item is clicked.
struct MenuBarPanel: View {
    let settings: AppSettings
    let clock: ClockModel
    @Bindable var timeTravel: TimeTravelState

    @Environment(\.openSettings) private var openSettings
    @State private var resetRotation: Double = 0

    private var previewDate: Date {
        timeTravel.date(from: clock.now)
    }

    private var sliderRange: ClosedRange<Double> {
        TimeTravelState.range(hours: settings.timeTravelRangeHours)
    }

    private var rangeHoursBinding: Binding<Int> {
        Binding(
            get: { settings.timeTravelRangeHours },
            set: { settings.setTimeTravelRangeHours($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            zonesSection
            Divider()
            timeTravelSection
            Divider()
            footer
        }
        .frame(width: 360)
        .onChange(of: settings.timeTravelRangeHours) { _, newValue in
            timeTravel.clamp(toHours: newValue)
        }
        .onAppear {
            timeTravel.clamp(toHours: settings.timeTravelRangeHours)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Timezone Buddy")
                    .font(.system(size: 15, weight: .semibold))
                Text(previewDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if timeTravel.isNow {
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 5, height: 5)
                Text("Live")
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06), in: Capsule())
        } else {
            Text(timeTravel.offsetDescription)
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.14), in: Capsule())
        }
    }

    // MARK: - Time zones

    @ViewBuilder
    private var zonesSection: some View {
        let zones = settings.enabledZones

        if zones.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 54)
                        }
                        TimeZoneRow(
                            zone: zone,
                            date: previewDate,
                            showEmoji: settings.showEmoji
                        )
                    }
                }
            }
            .frame(height: min(CGFloat(zones.count) * 49 - 1, 336))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No time zones selected")
                .font(.system(size: 12, weight: .medium))
            Button("Choose Time Zones…") {
                openSettingsWindow()
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    // MARK: - Time travel

    private var timeTravelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Time Travel", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(timeTravel.accessibilityDescription)
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(timeTravel.isNow ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
            }

            Slider(
                value: $timeTravel.offsetMinutes,
                in: sliderRange,
                step: TimeTravelState.step
            ) {
                Text("Time offset")
            }
            .labelsHidden()
            .controlSize(.small)
            .accessibilityLabel("Time offset")
            .accessibilityValue(timeTravel.accessibilityDescription)

            HStack(spacing: 4) {
                Text("Window ±")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                TextField("12", value: rangeHoursBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 10))
                    .frame(width: 34)
                    .help("How many hours the slider covers in each direction.")
                    .accessibilityLabel("Slider window in hours")

                Text("h")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Button {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        resetRotation -= 360
                    }
                    settings.setTimeTravelRangeHours(AppSettings.defaultTimeTravelRangeHours)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(resetRotation))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Reset the slider window to 12 hours")
                .accessibilityLabel("Reset slider window to 12 hours")

                Spacer(minLength: 8)

                Button("Back to Now") {
                    timeTravel.reset()
                }
                .controlSize(.small)
                .disabled(timeTravel.isNow)
            }

            Text(previewDescription)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var previewDescription: String {
        let time = TimeFormatting.time(previewDate, in: .autoupdatingCurrent)

        if timeTravel.isNow {
            return "Current time · \(time)"
        }

        let day = previewDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "Previewing \(day) at \(time)"
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                openSettingsWindow()
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
    }

    private func openSettingsWindow() {
        openSettings()
        SettingsWindowPresenter.bringToFrontWhenAvailable()
    }
}

/// One row in the drop-down list.
private struct TimeZoneRow: View {
    let zone: TimeZoneConfig
    let date: Date
    let showEmoji: Bool

    var body: some View {
        HStack(spacing: 10) {
            leadingIcon
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(zone.cityName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(TimeFormatting.time(date, in: zone.timeZone))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(TimeFormatting.dayDescription(zone.timeZone, at: date))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if showEmoji, !zone.displayEmoji.isEmpty {
            Text(zone.displayEmoji)
                .font(.system(size: 17))
        } else {
            Image(systemName: "globe")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        if zone.identifier == TimeZone.autoupdatingCurrent.identifier {
            return "Your time zone"
        }
        let offset = TimeFormatting.gmtOffset(zone.timeZone, at: date)
        let difference = TimeFormatting.differenceDescription(zone.timeZone, at: date)
        return "\(offset) · \(difference)"
    }
}

#Preview("Menu Bar Panel") {
    MenuBarPanel(
        settings: AppSettings(),
        clock: ClockModel(),
        timeTravel: TimeTravelState()
    )
}
#Preview("Time Travel") {
    MenuBarPanel(
        settings: AppSettings(),
        clock: ClockModel(),
        timeTravel: {
            let state = TimeTravelState()
            state.offsetMinutes = 8 * 60
            return state
        }()
    )
}

