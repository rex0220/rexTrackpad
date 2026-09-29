import AppKit
import Foundation

/// Composition root: creates every component and wires the pipeline
///
///     TrackpadInputProvider → GestureEngine (GestureRecognizer) → conflict filter
///       → ActionDispatcher → BrowserDetector / BrowserCommandResolver → KeyboardEventSender
///
/// Main thread only.
final class AppController {
    let settings: SettingsStore
    let permissions: PermissionManager
    let loginItems: LoginItemManager
    let browserDetector: BrowserDetector
    let conflictDetector: SystemGestureConflictDetector
    let trackpad: TrackpadInputProvider
    let engine: GestureEngine
    let dispatcher: ActionDispatcher

    #if DEBUG
    let debugMonitor = DebugMonitor()
    #endif

    /// Called on the main thread whenever the trackpad input state changes.
    var onTrackpadStateChange: ((TrackpadInputState) -> Void)?

    private var settingsObserver: NSObjectProtocol?

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        permissions = PermissionManager()
        loginItems = LoginItemManager()
        browserDetector = BrowserDetector()
        conflictDetector = SystemGestureConflictDetector()
        trackpad = MultitouchTrackpadProvider()
        engine = GestureEngine(provider: trackpad, configuration: settings.gestureConfiguration)
        dispatcher = ActionDispatcher(
            settings: settings,
            browserDetector: browserDetector,
            keyboard: CGKeyboardEventSender(),
            permissions: permissions
        )
    }

    func start() {
        trackpad.onStateChange = { [weak self] state in
            Log.trackpad.info("trackpad state: \(String(describing: state), privacy: .public)")
            self?.onTrackpadStateChange?(state)
        }
        engine.onGesture = { [weak self] gesture in
            self?.handle(gesture)
        }

        #if DEBUG
        let monitor = debugMonitor
        engine.onDiagnostics = { monitor.ingest($0) }
        engine.onRecognizerEvent = { monitor.record($0) }
        #endif

        settingsObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChangeNotification,
            object: settings,
            queue: .main
        ) { [weak self] _ in
            self?.settingsDidChange()
        }

        permissions.logMissingPermissions()
        applyEnabledState()
    }

    func stop() {
        engine.stop()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        settingsObserver = nil
    }

    /// Conflicting gestures that are currently suppressed.
    func activeConflict(for gesture: TrackpadGesture) -> SystemGestureConflict? {
        conflictDetector.conflict(for: gesture)
    }

    // MARK: - Private

    private func settingsDidChange() {
        engine.update(configuration: settings.gestureConfiguration)
        applyEnabledState()
    }

    /// When disabled, trackpad monitoring is stopped entirely (not just ignored).
    private func applyEnabledState() {
        if settings.isEnabled {
            engine.start()
        } else {
            engine.stop()
        }
    }

    private func handle(_ gesture: TrackpadGesture) {
        if settings.avoidsSystemGestureConflicts, let conflict = conflictDetector.conflict(for: gesture) {
            Log.gesture.info("gesture rejected: \(gesture.identifier, privacy: .public) conflicts with macOS \(conflict.feature.rawValue, privacy: .public)")
            #if DEBUG
            debugMonitor.note("ignored \(gesture.identifier): conflicts with \(conflict.feature.rawValue)")
            #endif
            return
        }
        let outcome = dispatcher.dispatch(gesture)
        #if DEBUG
        debugMonitor.note("\(gesture.displayName) → \(outcome)")
        #endif
    }
}
