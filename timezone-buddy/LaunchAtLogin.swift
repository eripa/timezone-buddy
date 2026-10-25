// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation
import ServiceManagement

/// Manages the app's login item using the modern Service Management API.
@MainActor
@Observable
final class LaunchAtLoginController {
    static let shared = LaunchAtLoginController()

    private(set) var status: SMAppService.Status
    private(set) var errorMessage: String?

    init() {
        status = SMAppService.mainApp.status
    }

    /// A registered item that still needs user approval counts as enabled,
    /// so the toggle doesn't snap back off while System Settings is pending.
    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    var requiresApproval: Bool {
        status == .requiresApproval
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        do {
            if enabled {
                guard !isEnabled else { return }
                try SMAppService.mainApp.register()
            } else {
                guard status != .notRegistered else { return }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }

        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static func friendlyMessage(for error: Error) -> String {
        "Couldn’t update the login item: \(error.localizedDescription) If this is a development build, move Timezone Buddy to /Applications and sign it with your Developer ID, then try again."
    }
}
