// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// The preferences window for Timezone Buddy.
struct SettingsView: View {
    let settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            TimeZonesSettingsView(settings: settings)
                .tabItem {
                    Label("Time Zones", systemImage: "globe")
                }
        }
        .frame(width: 580, height: 460)
        .background(SettingsWindowFrontingView())
    }
}

/// Brings the SwiftUI Settings window to the front for this menu bar-only app.
///
/// An `.accessory` app (no Dock icon) can open windows behind the active app.
/// Activating the app and explicitly ordering the Settings window front keeps
/// the Settings button from appearing to do nothing.
@MainActor
enum SettingsWindowPresenter {
    /// Waits for a newly-created Settings window, then brings it forward.
    static func bringToFrontWhenAvailable() {
        Task { @MainActor in
            for attempt in 0..<10 {
                if let window = settingsWindow {
                    NSRunningApplication.current.activate(options: [.activateAllWindows])
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    return
                }

                if attempt < 9 {
                    try? await Task.sleep(for: .milliseconds(80))
                }
            }

            NSRunningApplication.current.activate(options: [.activateAllWindows])
        }
    }

    private static var settingsWindow: NSWindow? {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "com.apple.SwiftUI.Settings" }) {
            return window
        }

        return NSApp.windows.first { window in
            guard window.styleMask.contains(.titled) else { return false }
            return window.title == "General"
                || window.title == "Time Zones"
                || window.title == "About"
                || window.title.localizedCaseInsensitiveContains("settings")
        }
    }
}

/// A zero-size window accessor that forces the hosting Settings window forward
/// when it first appears.
private struct SettingsWindowFrontingView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        SettingsWindowFrontingNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class SettingsWindowFrontingNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }

        NSRunningApplication.current.activate(options: [.activateAllWindows])
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    let settings: AppSettings

    private var displayModeBinding: Binding<MenuBarDisplayMode> {
        Binding(
            get: { settings.displayMode },
            set: { settings.setDisplayMode($0) }
        )
    }

    private var showEmojiBinding: Binding<Bool> {
        Binding(
            get: { settings.showEmoji },
            set: { settings.setShowEmoji($0) }
        )
    }

    private var hideDockIconBinding: Binding<Bool> {
        Binding(
            get: { settings.hideDockIcon },
            set: { settings.setHideDockIcon($0) }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Show in the menu bar", selection: displayModeBinding) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.displayMode.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Show emoji next to times", isOn: showEmojiBinding)
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("The clock list always opens when you click the menu bar item.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Hide Dock icon", isOn: hideDockIconBinding)

                Text("Timezone Buddy lives in the menu bar. When the Dock icon is hidden, open Settings from the menu bar panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Dock")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Time Zones

private struct TimeZonesSettingsView: View {
    let settings: AppSettings
    @State private var isAddingZone = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Drag to reorder. Each zone can have an optional emoji, such as a flag; leave the box empty for none.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            List {
                ForEach(settings.zones) { zone in
                    // Workaround for an Xcode preview crash with custom List rows on macOS.
                    #if DEBUG
                    AnyView(EmptyView())
                    #endif
                    TimeZoneSettingsRow(
                        zone: zone,
                        onEnabledChange: { settings.setZoneEnabled(id: zone.id, enabled: $0) },
                        onEmojiChange: { settings.setZoneEmoji(id: zone.id, emoji: $0) },
                        onDelete: { settings.removeZone(id: zone.id) }
                    )
                }
                .onMove { source, destination in
                    settings.moveZones(fromOffsets: source, toOffset: destination)
                }
                .onDelete { offsets in
                    settings.removeZones(atOffsets: offsets)
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button {
                    isAddingZone = true
                } label: {
                    Label("Add Time Zone", systemImage: "plus")
                }

                Spacer()

                Text("\(settings.enabledZones.count) of \(settings.zones.count) shown in menu bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .sheet(isPresented: $isAddingZone) {
            AddTimeZoneView(settings: settings)
        }
    }
}

private struct TimeZoneSettingsRow: View {
    let zone: TimeZoneConfig
    let onEnabledChange: (Bool) -> Void
    let onEmojiChange: (String) -> Void
    let onDelete: () -> Void

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { zone.isEnabled },
            set: onEnabledChange
        )
    }

    private var emojiBinding: Binding<String> {
        Binding(
            get: { zone.emoji },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                onEmojiChange(String(trimmed.prefix(2)))
            }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Show in menu bar", isOn: enabledBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .help("Show this zone in the menu bar")

            TextField("", text: emojiBinding)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 16))
                .frame(width: 30, height: 24)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .help("Optional emoji or flag for this zone")
                .accessibilityLabel("Emoji for \(zone.cityName)")

            VStack(alignment: .leading, spacing: 1) {
                Text(zone.cityName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(zone.identifier)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(alignment: .trailing, spacing: 1) {
                    Text(TimeFormatting.time(context.date, in: zone.timeZone))
                        .monospacedDigit()
                    Text(TimeFormatting.gmtOffset(zone.timeZone, at: context.date))
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .trailing)
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove \(zone.cityName)")
            .accessibilityLabel("Remove \(zone.cityName)")
        }
        .padding(.vertical, 3)
        .opacity(zone.isEnabled ? 1 : 0.6)
    }
}

#Preview("Settings") {
    SettingsView(settings: AppSettings())
}

#Preview("Time Zones") {
    TimeZonesSettingsView(settings: AppSettings())
        .frame(width: 580, height: 460)
}
