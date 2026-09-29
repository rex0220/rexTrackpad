import AppKit
import Foundation

/// Connects a `TrackpadInputProvider` to one `GestureRecognizer` per device.
///
/// Threading
/// - Frames arrive on the provider's thread and are processed on a private serial queue.
/// - `onGesture`, `onRecognizerEvent` and `onDiagnostics` are delivered on the main thread.
final class GestureEngine {
    /// A gesture was recognised. Main thread.
    var onGesture: ((TrackpadGesture) -> Void)?
    /// Every recognizer event (for logging / Debug Monitor). Main thread.
    var onRecognizerEvent: ((GestureRecognizerEvent) -> Void)?
    /// Live diagnostics, throttled. Main thread. Leave nil in production.
    var onDiagnostics: ((GestureDiagnostics) -> Void)? {
        didSet {
            let enabled = onDiagnostics != nil
            queue.async {
                self.diagnosticsEnabled = enabled
                self.recognizers.values.forEach { self.configureDiagnostics(for: $0) }
            }
        }
    }

    let provider: TrackpadInputProvider

    private let queue = DispatchQueue(label: "com.rex0220.rexTrackpad.gesture", qos: .userInteractive)

    // Accessed only on `queue`.
    private var recognizers: [Int: GestureRecognizer] = [:]
    private var configuration: GestureConfiguration
    private var diagnosticsEnabled = false
    private var lastDiagnosticsTime: TimeInterval = 0
    private var lastDiagnosticsFingerCount = -1

    // Main thread.
    private var clickMonitor: Any?
    private(set) var isRunning = false

    init(provider: TrackpadInputProvider, configuration: GestureConfiguration) {
        self.provider = provider
        self.configuration = configuration
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isRunning else { return }
        isRunning = true

        provider.onFrame = { [weak self] frame in
            guard let self else { return }
            self.queue.async { self.process(frame) }
        }
        provider.start()

        // A physical click with 3+ fingers must not count as a tap. Global monitors
        // for mouse-button events need no extra permission and never consume events.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                self.recognizers.values.forEach { $0.noteClick() }
            }
        }
    }

    func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isRunning else { return }
        isRunning = false

        provider.stop()
        provider.onFrame = nil
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        clickMonitor = nil
        queue.async { self.recognizers.removeAll() }
    }

    func update(configuration: GestureConfiguration) {
        queue.async {
            self.configuration = configuration
            self.recognizers.values.forEach { $0.configuration = configuration }
        }
    }

    // MARK: - Queue

    private func process(_ frame: TrackpadFrame) {
        recognizer(for: frame.deviceID).process(frame)
    }

    private func recognizer(for deviceID: Int) -> GestureRecognizer {
        if let existing = recognizers[deviceID] {
            return existing
        }
        let recognizer = GestureRecognizer(configuration: configuration)
        recognizer.onEvent = { [weak self] event in
            self?.handle(event)
        }
        configureDiagnostics(for: recognizer)
        recognizers[deviceID] = recognizer
        return recognizer
    }

    /// Diagnostics are only built when someone is listening, so Release builds pay nothing.
    private func configureDiagnostics(for recognizer: GestureRecognizer) {
        recognizer.onDiagnostics = diagnosticsEnabled
            ? { [weak self] diagnostics in self?.forwardDiagnostics(diagnostics) }
            : nil
    }

    private func handle(_ event: GestureRecognizerEvent) {
        switch event {
        case .began(let fingers):
            Log.verbose(Log.gesture, "gesture begin: fingers=\(fingers)")
        case .recognized(let gesture, let metrics):
            Log.gesture.info("gesture recognized: \(gesture.identifier, privacy: .public)")
            Log.verbose(Log.gesture, "gesture metrics: \(metrics.summary)")
        case .rejected(let reason, let metrics):
            Log.verbose(Log.gesture, "gesture rejected: \(reason.displayName) (\(metrics.summary))")
        case .debounced(let since):
            Log.verbose(Log.gesture, String(format: "debounce ignored: %.3fs after previous gesture", since))
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onRecognizerEvent?(event)
            if case .recognized(let gesture, _) = event {
                self.onGesture?(gesture)
            }
        }
    }

    private func forwardDiagnostics(_ diagnostics: GestureDiagnostics) {
        // ~30 Hz is plenty for a human-readable monitor, but never drop a finger-count change.
        let fingerCountChanged = diagnostics.contacts.count != lastDiagnosticsFingerCount
        guard fingerCountChanged || diagnostics.timestamp - lastDiagnosticsTime >= 1.0 / 30.0 else { return }
        lastDiagnosticsTime = diagnostics.timestamp
        lastDiagnosticsFingerCount = diagnostics.contacts.count
        DispatchQueue.main.async { [weak self] in
            self?.onDiagnostics?(diagnostics)
        }
    }
}
