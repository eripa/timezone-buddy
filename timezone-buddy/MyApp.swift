// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

@main
struct TimezoneBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var settings = AppSettings.shared
    @State private var clock = ClockModel()
    @State private var timeTravel = TimeTravelState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(
                settings: settings,
                clock: clock,
                timeTravel: timeTravel
            )
        } label: {
            MenuBarLabel(
                settings: settings,
                clock: clock,
                timeTravel: timeTravel
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
        }
    }
}

/// Applies the saved Dock icon preference as soon as the app launches.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIconController.apply(hidden: AppSettings.shared.hideDockIcon)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppSettings.shared.persist()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Reopening the app (for example by clicking its Dock icon) shows Settings,
    /// since there is no main window to bring forward.
    ///
    /// SwiftUI's Settings scene doesn't expose an AppKit API for this, so the
    /// menu-bar-only app uses the conventional `showSettingsWindow:` action.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        return true
    }
}
