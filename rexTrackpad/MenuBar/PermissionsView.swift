import SwiftUI

final class PermissionsViewModel: ObservableObject {
    @Published private(set) var accessibility: PermissionStatus = .unknown
    @Published private(set) var inputMonitoring: PermissionStatus = .unknown
    @Published private(set) var trackpadState: TrackpadInputState = .stopped
    @Published private(set) var framesReceived: UInt64 = 0

    private let permissions: PermissionManager
    private let trackpad: TrackpadInputProvider
    private var timer: Timer?

    init(permissions: PermissionManager, trackpad: TrackpadInputProvider) {
        self.permissions = permissions
        self.trackpad = trackpad
        refresh()
    }

    deinit {
        timer?.invalidate()
    }

    func startPolling() {
        refresh()
        guard timer == nil else { return }
        // Accessibility changes have no reliable notification, so poll while visible.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        accessibility = permissions.accessibilityStatus
        inputMonitoring = permissions.inputMonitoringStatus
        trackpadState = trackpad.state
        framesReceived = trackpad.framesReceived
    }

    func requestAccessibility() {
        permissions.requestAccessibility()
        refresh()
    }

    func openAccessibilitySettings() {
        permissions.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        permissions.openInputMonitoringSettings()
    }
}

struct PermissionsView: View {
    @ObservedObject var model: PermissionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PermissionRow(
                title: "Accessibility",
                status: model.accessibility == .granted ? PermissionBadge.ok("Granted") : .problem("Required"),
                detail: "Needed to send keyboard shortcuts (⌘R, ⌘T, …) to the browser."
            ) {
                if model.accessibility != .granted {
                    Button("Request Access…") { model.requestAccessibility() }
                }
                Button("Open System Settings") { model.openAccessibilitySettings() }
            }

            Divider()

            PermissionRow(
                title: "Input Monitoring",
                status: model.inputMonitoring == .granted ? PermissionBadge.ok("Granted") : .neutral("Not required"),
                detail: "rexTrackpad does not request this. Grant it only if Trackpad Input below stays at 0 frames while you touch the trackpad."
            ) {
                Button("Open System Settings") { model.openInputMonitoringSettings() }
            }

            Divider()

            PermissionRow(
                title: "Trackpad Input",
                status: trackpadStatus,
                detail: "\(model.trackpadState.displayText) · \(model.framesReceived) frames received"
            ) {
                EmptyView()
            }

            Text("After rebuilding the app, macOS may treat it as a new app. If gestures stop working, remove rexTrackpad from the Accessibility list and add it again.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { model.startPolling() }
        .onDisappear { model.stopPolling() }
    }

    private var trackpadStatus: PermissionBadge {
        switch model.trackpadState {
        case .running:
            return model.framesReceived > 0 ? .ok("Receiving touches") : .neutral("Waiting for touches")
        case .stopped:
            return .neutral("Stopped (rexTrackpad is disabled)")
        case .unavailable:
            return .problem("Unavailable")
        }
    }
}

private enum PermissionBadge {
    case ok(String)
    case problem(String)
    case neutral(String)
}

private struct PermissionRow<Buttons: View>: View {
    let title: String
    let status: PermissionBadge
    let detail: String
    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                statusLabel
            }
            Text(detail)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack { buttons() }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch status {
        case .ok(let text):
            Label(text, systemImage: "checkmark.circle.fill").foregroundColor(.green)
        case .problem(let text):
            Label(text, systemImage: "xmark.circle.fill").foregroundColor(.red)
        case .neutral(let text):
            Label(text, systemImage: "minus.circle").foregroundColor(.secondary)
        }
    }
}
