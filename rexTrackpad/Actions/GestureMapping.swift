import Foundation

/// Which action each gesture triggers. Kept separate from both gestures and actions
/// so that users can rebind freely.
struct GestureMapping: Equatable, Sendable {
    private(set) var bindings: [TrackpadGesture: GestureAction]

    init(_ bindings: [TrackpadGesture: GestureAction] = [:]) {
        self.bindings = bindings
    }

    /// Default bindings (as requested in the v0.1 spec).
    ///
    /// Swipes use the same motions as macOS system gestures under default System
    /// Settings, so they only fire when the corresponding system gesture is turned off
    /// or moved to a different finger count (see `SystemGestureConflictDetector`).
    static let defaults = GestureMapping([
        .threeFingerTap: .browser(.reload),
        // Tap on the left / right side of the trackpad to go back / forward.
        .threeFingerTapLeft: .browser(.back),
        .threeFingerTapRight: .browser(.forward),
        // Point at a link and tap with four fingers. Hard Reload is available from the menu.
        .fourFingerTap: .browser(.openLinkInNewTab),

        .threeFingerSwipeLeft: .browser(.previousTab),
        .threeFingerSwipeRight: .browser(.nextTab),

        .threeFingerSwipeUp: .browser(.newTab),
        .threeFingerSwipeDown: .browser(.closeTab),

        .fourFingerSwipeLeft: .browser(.back),
        .fourFingerSwipeRight: .browser(.forward),

        // Draw a circle with three fingers.
        .threeFingerCircleClockwise: .browser(.reopenClosedTab),
        .threeFingerCircleCounterClockwise: .browser(.hardReload),
        // One-finger circles need no macOS settings changes.
        .oneFingerCircleClockwise: .browser(.forward),
        .oneFingerCircleCounterClockwise: .browser(.back),
    ])

    /// The action to run: the gesture's own binding, else its fallback's
    /// (a zone tap without a binding acts like the plain tap).
    func action(for gesture: TrackpadGesture) -> GestureAction? {
        bindings[gesture] ?? gesture.fallback.flatMap { bindings[$0] }
    }

    /// The gesture's own binding, ignoring fallbacks (for the menu).
    func ownAction(for gesture: TrackpadGesture) -> GestureAction? {
        bindings[gesture]
    }

    /// Binds `gesture` to `action`, or removes the binding when `action` is nil.
    mutating func bind(_ gesture: TrackpadGesture, to action: GestureAction?) {
        bindings[gesture] = action
    }
}

extension GestureMapping: Codable {
    /// Stored as `{"tap.3": "browser.reload", …}` so the JSON stays readable.
    /// Unknown identifiers (from a newer version) are skipped instead of failing.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: String].self)
        var bindings: [TrackpadGesture: GestureAction] = [:]
        for (gestureID, actionID) in raw {
            guard let gesture = TrackpadGesture(identifier: gestureID),
                  let action = GestureAction(identifier: actionID) else { continue }
            bindings[gesture] = action
        }
        self.bindings = bindings
    }

    func encode(to encoder: Encoder) throws {
        var raw: [String: String] = [:]
        for (gesture, action) in bindings {
            raw[gesture.identifier] = action.identifier
        }
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}
