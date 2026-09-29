#if DEBUG
import Foundation
import SwiftUI

/// Live gesture diagnostics shown by the Debug Monitor window. Debug builds only.
final class DebugMonitor: ObservableObject {
    @Published private(set) var diagnostics: GestureDiagnostics?
    @Published private(set) var lastGesture: String = "—"
    @Published private(set) var lastMetrics: String = "—"
    @Published private(set) var events: [String] = []

    private let maxEvents = 40
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    func ingest(_ diagnostics: GestureDiagnostics) {
        self.diagnostics = diagnostics
    }

    func record(_ event: GestureRecognizerEvent) {
        switch event {
        case .began(let fingers):
            note("began (\(fingers) finger\(fingers == 1 ? "" : "s"))")
        case .recognized(let gesture, let metrics):
            lastGesture = gesture.displayName
            lastMetrics = metrics.summary
            note("RECOGNIZED \(gesture.displayName)  \(metrics.summary)")
        case .rejected(let reason, let metrics):
            lastMetrics = metrics.summary
            note("rejected: \(reason.displayName)  \(metrics.summary)")
        case .debounced(let since):
            note(String(format: "debounce ignored (%.3fs after previous gesture)", since))
        }
    }

    func note(_ message: String) {
        events.insert("\(timeFormatter.string(from: Date()))  \(message)", at: 0)
        if events.count > maxEvents {
            events.removeLast(events.count - maxEvents)
        }
    }

    func clear() {
        events.removeAll()
        lastGesture = "—"
        lastMetrics = "—"
    }
}
#endif
