import AppKit
import ApplicationServices
import IOKit.hid

enum PermissionStatus: Equatable {
    case granted
    case denied
    case unknown
}

/// Checks and requests the privacy permissions rexTrackpad uses.
///
/// - **Accessibility** — required. Posting synthetic keyboard events (the browser
///   shortcuts) is only allowed for trusted apps.
/// - **Input Monitoring** — *not requested*. Reading MultitouchSupport contact frames
///   and observing mouse clicks with a global NSEvent monitor does not need it on
///   current macOS. The status is shown for troubleshooting only.
final class PermissionManager: PermissionChecking {
    var accessibilityStatus: PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    var inputMonitoringStatus: PermissionStatus {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        if access == kIOHIDAccessTypeGranted { return .granted }
        if access == kIOHIDAccessTypeDenied { return .denied }
        return .unknown
    }

    var canPostKeyboardEvents: Bool {
        accessibilityStatus == .granted
    }

    /// Shows the system prompt that adds rexTrackpad to Privacy & Security › Accessibility.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        Log.permission.info("accessibility requested (trusted: \(trusted, privacy: .public))")
    }

    func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openPrivacyPane("Privacy_ListenEvent")
    }

    func logMissingPermissions() {
        if accessibilityStatus != .granted {
            Log.permission.notice("permission missing: Accessibility (browser shortcuts cannot be sent)")
        }
    }

    /// Opens System Settings › Privacy & Security › `anchor`.
    /// The `com.apple.settings.PrivacySecurity.extension` form is the one current macOS
    /// resolves reliably; the legacy `com.apple.preference.security` form is a fallback.
    private func openPrivacyPane(_ anchor: String) {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)",
            "x-apple.systempreferences:com.apple.preference.security?\(anchor)",
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
