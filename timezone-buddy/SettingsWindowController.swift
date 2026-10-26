// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Owns the single Settings window for this menu-bar-only app.
///
/// SwiftUI's `Settings` scene can only be opened from a view's `openSettings`
/// environment action. A normal AppKit window lets the menu bar panel and the
/// Dock-icon reopen path use the same supported code path.
@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController(settings: AppSettings.shared)

    init(settings: AppSettings) {
        let content = NSHostingController(rootView: SettingsView(settings: settings))
        let window = NSWindow(contentViewController: content)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 580, height: 460))
        window.contentMinSize = NSSize(width: 580, height: 460)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("TimezoneBuddySettingsWindow")

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SettingsWindowController does not support storyboards")
    }

    /// Brings the existing Settings window forward, creating it lazily on the
    /// first call.
    func show() {
        NSApp.activate(ignoringOtherApps: true)

        if window?.isMiniaturized == true {
            window?.deminiaturize(nil)
        }

        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
