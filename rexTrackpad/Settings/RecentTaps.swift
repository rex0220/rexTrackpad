import CoreGraphics
import Foundation

/// The last few taps and where they landed, so the settings can show how the
/// trackpad is split into tap zones. Kept in memory only. Main thread.
final class RecentTaps: ObservableObject {
    struct Tap: Identifiable, Equatable {
        let id: Int
        /// Normalised trackpad coordinates, y = 0 at the bottom.
        let position: CGPoint
        let gesture: TrackpadGesture
    }

    @Published private(set) var taps: [Tap] = []

    private let limit = 8
    private var nextID = 0

    func record(_ event: GestureRecognizerEvent) {
        guard case .recognized(let gesture, let metrics) = event, let position = metrics.position else { return }
        switch gesture {
        case .tap, .zoneTap: break
        case .swipe, .circle: return
        }
        taps.append(Tap(id: nextID, position: position, gesture: gesture))
        nextID += 1
        if taps.count > limit {
            taps.removeFirst(taps.count - limit)
        }
    }

    func clear() {
        taps.removeAll()
    }
}
