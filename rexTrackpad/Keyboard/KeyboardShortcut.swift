import CoreGraphics
import Foundation

/// Modifier keys, independent of Core Graphics.
struct KeyboardModifiers: OptionSet, Hashable, Sendable {
    let rawValue: UInt8

    static let control = KeyboardModifiers(rawValue: 1 << 0)
    static let option = KeyboardModifiers(rawValue: 1 << 1)
    static let shift = KeyboardModifiers(rawValue: 1 << 2)
    static let command = KeyboardModifiers(rawValue: 1 << 3)

    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.command) { flags.insert(.maskCommand) }
        return flags
    }

    /// macOS menu order: ⌃⌥⇧⌘.
    var symbols: String {
        var text = ""
        if contains(.control) { text += "⌃" }
        if contains(.option) { text += "⌥" }
        if contains(.shift) { text += "⇧" }
        if contains(.command) { text += "⌘" }
        return text
    }
}

/// A key, described by meaning rather than by hardware key code.
enum KeyboardKey: Hashable, Sendable {
    /// A printable character, e.g. "r" or "[". Resolved against the active keyboard
    /// layout at send time, so shortcuts work on JIS, ISO and non-QWERTY layouts.
    case character(Character)
    case tab
    case leftArrow
    case rightArrow
    case upArrow
    case downArrow

    var displayName: String {
        switch self {
        case .character(let character): return String(character).uppercased()
        case .tab: return "⇥"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        }
    }

    /// Arrow keys carry the Fn and numeric-pad flags when typed on real hardware;
    /// synthetic events mirror that so apps match them the same way.
    var isArrow: Bool {
        switch self {
        case .leftArrow, .rightArrow, .upArrow, .downArrow: return true
        default: return false
        }
    }
}

/// A key combination such as ⌘R.
struct KeyboardShortcut: Hashable, Sendable, CustomStringConvertible {
    let key: KeyboardKey
    let modifiers: KeyboardModifiers

    init(_ key: KeyboardKey, _ modifiers: KeyboardModifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    var description: String {
        modifiers.symbols + key.displayName
    }
}

/// A shortcut resolved to a concrete virtual key code for the current keyboard layout.
struct ResolvedKeystroke: Equatable, Sendable {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
}
