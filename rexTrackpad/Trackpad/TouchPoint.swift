import CoreGraphics
import Foundation

/// A single contact on the trackpad surface.
///
/// This type is deliberately independent of any private API so that the gesture
/// layer (and its unit tests) never touches MultitouchSupport directly.
struct TouchPoint: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// The finger has just made contact.
        case began
        /// The finger is resting on / moving across the surface.
        case touching
        /// The finger is breaking contact.
        case ended
        /// The finger is near the surface but not touching it.
        case hovering
    }

    /// Identifier that stays stable for the lifetime of one contact.
    let id: Int

    /// Normalised position on the surface.
    /// `x`: 0 = left edge, 1 = right edge. `y`: 0 = bottom edge (nearest the user), 1 = top edge.
    let position: CGPoint

    let phase: Phase

    /// Relative contact size (capacitance). Useful for future palm rejection; 0 when unknown.
    var size: Double = 0

    /// Whether the finger is physically on the surface.
    var isInContact: Bool {
        phase == .began || phase == .touching
    }
}
