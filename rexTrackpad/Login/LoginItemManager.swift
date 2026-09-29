import Foundation
import ServiceManagement

/// Launch at Login via `SMAppService.mainApp` (macOS 13+), the current recommended API.
/// The deprecated `SMLoginItemSetEnabled` / shared-file-list APIs are not used.
final class LoginItemManager {
    enum Status: Equatable {
        case enabled
        case disabled
        /// Registered, but the user must allow it in System Settings › General › Login Items.
        case requiresApproval
        case notFound
    }

    var status: Status {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .notRegistered: return .disabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .notFound
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        Log.app.info("launch at login set to \(enabled, privacy: .public); status: \(String(describing: self.status), privacy: .public)")
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
