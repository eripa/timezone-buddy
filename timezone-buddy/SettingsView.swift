// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// The panes shown in the Settings window.
enum SettingsPane: String {
    case general
    case timeZones
    case about
}

/// The preferences window for Timezone Buddy.
struct SettingsView: View {
    let settings: AppSettings

    /// Reopens the pane people used last, which the HIG recommends for
    /// settings windows with more than one pane.
    @AppStorage("timezoneBuddy.settingsPane") private var selectedPane: SettingsPane = .general

    var body: some View {
        TabView(selection: $selectedPane) {
            Tab("General", systemImage: "gearshape", value: SettingsPane.general) {
                GeneralSettingsView(settings: settings)
            }

            Tab("Time Zones", systemImage: "globe", value: SettingsPane.timeZones) {
                TimeZonesSettingsView(settings: settings)
            }

            Tab("About", systemImage: "info.circle", value: SettingsPane.about) {
                AboutSettingsView()
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
    @State private var launchAtLogin = LaunchAtLoginController.shared

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

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
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
                Toggle("Launch at login", isOn: launchAtLoginBinding)

                if launchAtLogin.requiresApproval {
                    Label(
                        "Approve Timezone Buddy in System Settings → General → Login Items.",
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)

                    Button("Open Login Items Settings…") {
                        launchAtLogin.openLoginItemsSettings()
                    }
                    .controlSize(.small)
                }

                if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Startup")
            } footer: {
                Text("Starts Timezone Buddy in the menu bar when you log in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Hide Dock icon", isOn: hideDockIconBinding)

                Text(
                    "Timezone Buddy lives in the menu bar. When the Dock icon is hidden, open Settings from the menu bar panel."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("Dock")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin.refresh()
        }
        .task {
            // Refresh after returning from System Settings or a login.
            for await _ in NotificationCenter.default.notifications(
                named: NSApplication.didBecomeActiveNotification
            ) {
                launchAtLogin.refresh()
            }
        }
    }
}

// MARK: - Time Zones

private struct TimeZonesSettingsView: View {
    let settings: AppSettings
    @State private var isAddingZone = false

    var body: some View {
        VStack(spacing: 0) {
            Text(
                "Drag the handle to reorder, or use the reorder menu for keyboard access. Click a name to relabel that zone — Calgary for Edmonton, say — and leave it empty to use the city name. The emoji box is optional."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(settings.zones.enumerated()), id: \.element.id) { index, zone in
                        VStack(spacing: 0) {
                            TimeZoneSettingsRow(
                                zone: zone,
                                canMoveUp: index > 0,
                                canMoveDown: index < settings.zones.count - 1,
                                onMoveUp: { settings.moveZone(id: zone.id, by: -1) },
                                onMoveDown: { settings.moveZone(id: zone.id, by: 1) },
                                onEnabledChange: { settings.setZoneEnabled(id: zone.id, enabled: $0) },
                                onEmojiChange: { settings.setZoneEmoji(id: zone.id, emoji: $0) },
                                onNameChange: { settings.setZoneCustomName(id: zone.id, name: $0) },
                                onDelete: { settings.removeZone(id: zone.id) }
                            )
                            .padding(.horizontal, 16)

                            if zone.id != settings.zones.last?.id {
                                Divider()
                                    .padding(.leading, 86)
                            }
                        }
                    }
                    .reorderable()
                }
                .padding(.vertical, 4)
            }
            .reorderContainer(for: TimeZoneConfig.self) { difference in
                settings.applyReorder(difference)
            }

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
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onEnabledChange: (Bool) -> Void
    let onEmojiChange: (String) -> Void
    let onNameChange: (String) -> Void
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

    /// Edits the custom name directly. The field is empty when the zone still
    /// uses its city name, so the city shows as the placeholder.
    private var customNameBinding: Binding<String> {
        Binding(
            get: { zone.customName ?? "" },
            set: onNameChange
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            DragHandle()

            Toggle("Show in menu bar", isOn: enabledBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .help("Show this zone in the menu bar")

            TextField("", text: emojiBinding)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 16))
                .frame(width: 30, height: 24)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .help("Optional emoji or flag for this zone")
                .accessibilityLabel("Emoji for \(zone.displayName)")

            VStack(alignment: .leading, spacing: 1) {
                TextField("", text: customNameBinding, prompt: Text(zone.cityName))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .help("Optional name, shown instead of \(zone.cityName)")
                    .accessibilityLabel("Name for \(zone.cityName)")

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

            Menu {
                Button {
                    onMoveUp()
                } label: {
                    Label("Move Up", systemImage: "arrow.up")
                }
                .disabled(!canMoveUp)

                Button {
                    onMoveDown()
                } label: {
                    Label("Move Down", systemImage: "arrow.down")
                }
                .disabled(!canMoveDown)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Move \(zone.displayName)")
            .accessibilityLabel("Reorder \(zone.displayName)")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove \(zone.displayName)")
            .accessibilityLabel("Remove \(zone.displayName)")
        }
        .padding(.vertical, 6)
        .opacity(zone.isEnabled ? 1 : 0.6)
    }
}

/// The classic six-dot grip at the leading edge of a reorderable row.
///
/// SF Symbols has no two-by-three dot grid, so the dots are drawn directly.
/// The handle carries no gesture of its own — `reorderable()` starts its drag
/// anywhere in the row — so this only marks where to grab.
private struct DragHandle: View {
    private static let rowCount = 3
    private static let dotSize: CGFloat = 2.5

    var body: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(0..<Self.rowCount, id: \.self) { _ in
                GridRow {
                    ForEach(0..<2, id: \.self) { _ in
                        Circle()
                            .fill(.secondary)
                            .frame(width: Self.dotSize, height: Self.dotSize)
                    }
                }
            }
        }
        .frame(width: 12, height: 18)
        .contentShape(Rectangle())
        .help("Drag to reorder")
        .accessibilityHidden(true)
    }
}

// MARK: - About

/// Mirrors the standard About panel, which is otherwise reachable only from
/// the app menu — and that menu is gone while the Dock icon is hidden.
private struct AboutSettingsView: View {
    private var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(shortVersion) (\(build))"
    }

    /// Read from the bundle so the line stays in step with the project's
    /// `NSHumanReadableCopyright` setting.
    private var copyright: String? {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)

            Text("Timezone Buddy")
                .font(.system(size: 24, weight: .semibold))
                .padding(.top, 12)

            Text(versionDescription)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if let copyright {
                Text(copyright)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Settings") {
    SettingsView(settings: AppSettings())
}

#Preview("Time Zones") {
    TimeZonesSettingsView(settings: AppSettings())
        .frame(width: 580, height: 460)
}

#Preview("About") {
    AboutSettingsView()
        .frame(width: 580, height: 460)
}
