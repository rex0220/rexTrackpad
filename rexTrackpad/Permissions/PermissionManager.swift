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
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func logMissingPermissions() {
        if accessibilityStatus != .granted {
            Log.permission.notice("permission missing: Accessibility (browser shortcuts cannot be sent)")
        }
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}
