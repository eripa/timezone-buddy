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

    /// Spacing between the slider's tick marks. Wide windows need sparser
    /// ticks so the track stays legible in a 360pt-wide panel.
    private var tickStride: Double {
        switch settings.timeTravelRangeHours {
        case ...3: 60
        case ...12: 180
        default: 360
        }
    }

    /// The tick positions themselves, including both ends of the slider.
    private var tickValues: [Double] {
        let step = tickStride
        return Array(
            stride(from: sliderRange.lowerBound, through: sliderRange.upperBound, by: step)
        )
    }

    private var rangeHoursBinding: Binding<Int> {
        Binding(
            get: { settings.timeTravelRangeHours },
            set: { settings.setTimeTravelRangeHours($0) }
        )
    }

    /// The slider snaps while dragging, but allows exact-minute values set from
    /// an editable clock.
    private var sliderValueBinding: Binding<Double> {
        Binding(
            get: { timeTravel.offsetMinutes },
            set: { newValue in
                let snapped = (newValue / TimeTravelState.step).rounded() * TimeTravelState.step
                timeTravel.offsetMinutes = snapped
            }
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
            .background(.quaternary, in: Capsule())
        } else {
            Text(timeTravel.offsetDescription)
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
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
                            showEmoji: settings.showEmoji,
                            onTimeChange: { setTime($0) }
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
                value: sliderValueBinding,
                in: sliderRange,
                neutralValue: 0
            ) {
                Text("Time offset")
            } ticks: {
                SliderTickContentForEach(tickValues, id: \.self) { minutes in
                    SliderTick(minutes)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .tint(timeTravel.isNow ? .accentColor : .orange)
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

    /// Applies a time entered in a zone and keeps the slider and all other
    /// zones in sync. Returns `false` when the requested moment is outside the
    /// slider's maximum window.
    private func setTime(_ target: Date) -> Bool {
        let offsetMinutes = (target.timeIntervalSince(clock.now) / 60).rounded()
        let requiredHours = TimeTravelState.requiredHours(forOffsetMinutes: offsetMinutes)

        guard requiredHours <= AppSettings.timeTravelRangeLimits.upperBound else {
            return false
        }

        if requiredHours > settings.timeTravelRangeHours {
            settings.setTimeTravelRangeHours(requiredHours)
        }

        return timeTravel.setOffset(
            minutes: offsetMinutes,
            maximumHours: settings.timeTravelRangeHours
        )
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
    let onTimeChange: (Date) -> Bool

    @State private var isEditing = false
    @FocusState private var isEditingFocused: Bool
    @State private var draft = ""
    @State private var isInvalid = false
    @State private var isHoveringTime = false

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
                timeControl
                    .frame(width: 70, alignment: .trailing)
                Text(TimeFormatting.dayDescription(zone.timeZone, at: date))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    @ViewBuilder
    private var timeControl: some View {
        if isEditing {
            TextField("HH:mm", text: $draft)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 62)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            isInvalid ? Color.red : Color.accentColor.opacity(0.8),
                            lineWidth: 1
                        )
                )
                .focused($isEditingFocused)
                .onAppear {
                    isEditingFocused = true
                }
                .onSubmit {
                    submitDraft()
                }
                .onChange(of: draft) { _, newValue in
                    handleDraftChange(newValue)
                }
                .onChange(of: isEditingFocused) { _, focused in
                    if !focused {
                        finishEditing()
                    }
                }
                .onExitCommand {
                    cancelEditing()
                }
                .help("Enter a 24-hour time, e.g. 20:19")
                .accessibilityLabel("Time for \(zone.cityName)")
        } else {
            Button(action: beginEditing) {
                Text(TimeFormatting.time(date, in: zone.timeZone))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background {
                        if isHoveringTime {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(.quaternary)
                        }
                    }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringTime = hovering
            }
            .help("Click to edit this time")
            .accessibilityLabel("Edit \(zone.cityName) time")
            .accessibilityValue(TimeFormatting.time(date, in: zone.timeZone))
        }
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

    private func beginEditing() {
        draft = TimeFormatting.editableTime(date, in: zone.timeZone)
        isInvalid = false
        isEditing = true
    }

    private func handleDraftChange(_ newValue: String) {
        guard isEditing else { return }

        let sanitized = TimeInput.sanitize(newValue)
        if sanitized != newValue {
            draft = sanitized
            return
        }

        guard TimeInput.isComplete(draft) else {
            isInvalid = false
            return
        }

        if let parsed = TimeInput.parse(draft) {
            isInvalid = !apply(parsed)
        } else {
            isInvalid = true
        }
    }

    @discardableResult
    private func apply(_ value: TimeInput.Value) -> Bool {
        let current = TimeFormatting.timeComponents(date, in: zone.timeZone)
        guard value.hour != current.hour || value.minute != current.minute else { return true }

        guard let target = TimeFormatting.date(
            on: date,
            atHour: value.hour,
            minute: value.minute,
            in: zone.timeZone
        ) else {
            return false
        }

        return onTimeChange(target)
    }

    private func submitDraft() {
        guard let parsed = TimeInput.parse(draft) else {
            isInvalid = true
            return
        }

        guard apply(parsed) else {
            isInvalid = true
            return
        }

        draft = TimeInput.format(hour: parsed.hour, minute: parsed.minute)
        isEditing = false
        isEditingFocused = false
        isInvalid = false
    }

    private func finishEditing() {
        guard isEditing else { return }

        if let parsed = TimeInput.parse(draft), apply(parsed) {
            draft = TimeInput.format(hour: parsed.hour, minute: parsed.minute)
        } else {
            draft = TimeFormatting.editableTime(date, in: zone.timeZone)
        }

        isEditing = false
        isInvalid = false
    }

    private func cancelEditing() {
        draft = TimeFormatting.editableTime(date, in: zone.timeZone)
        isEditing = false
        isEditingFocused = false
        isInvalid = false
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

