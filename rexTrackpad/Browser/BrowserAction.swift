import Foundation

/// A browser operation, independent of any particular browser or key combination.
///
/// Planned additions (not implemented in v0.1): restoreTab, pinTab, duplicateTab,
/// focusAddressBar, find, showDownloads, developerTools, newWindow, privateWindow,
/// toggleFullScreen, scrollToTop, scrollToBottom. Each needs a case here plus an
/// entry in the relevant `BrowserCommandProvider`s.
enum BrowserAction: String, Codable, CaseIterable, Sendable {
    case reload
    case hardReload
    case previousTab
    case nextTab
    case newTab
    case closeTab
    /// Reopens the most recently closed tab.
    case reopenClosedTab
    case back
    case forward
    /// Opens the link under the mouse pointer in a new tab and switches to it.
    case openLinkInNewTab

    var displayName: String {
        switch self {
        case .reload: return String(localized: "Reload")
        case .hardReload: return String(localized: "Hard Reload")
        case .previousTab: return String(localized: "Previous Tab")
        case .nextTab: return String(localized: "Next Tab")
        case .newTab: return String(localized: "New Tab")
        case .closeTab: return String(localized: "Close Tab")
        case .reopenClosedTab: return String(localized: "Reopen Closed Tab")
        case .back: return String(localized: "Back")
        case .forward: return String(localized: "Forward")
        case .openLinkInNewTab: return String(localized: "Open Link in New Tab")
        }
    }
}
