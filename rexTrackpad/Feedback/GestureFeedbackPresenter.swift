import AppKit
import SwiftUI

/// Shows a small symbol for the action near the mouse pointer for a moment, so the
/// user can see that a gesture worked.
///
/// The panel never takes focus and ignores the mouse, so clicks and typing go to the
/// browser as usual. It is shown after the shortcut has been sent, so it never delays
/// the action. Main thread only.
final class GestureFeedbackPresenter {
    private static let size = CGSize(width: 44, height: 44)
    /// From the pointer to the panel's top-left corner (panel sits below-right of it).
    private static let offset = CGPoint(x: 18, y: -14)
    private static let fadeIn: TimeInterval = 0.08
    private static let hold: TimeInterval = 0.35
    private static let fadeOut: TimeInterval = 0.25
    /// Slightly see-through, so the page behind stays visible.
    private static let peakAlpha: CGFloat = 0.75

    private lazy var panel: NSPanel = makePanel()
    private var hideWorkItem: DispatchWorkItem?

    func show(_ action: GestureAction) {
        let panel = self.panel
        panel.contentView = NSHostingView(rootView: FeedbackSymbolView(symbolName: action.feedbackSymbol))
        panel.setFrame(frame(near: NSEvent.mouseLocation), display: false)

        hideWorkItem?.cancel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeIn
            panel.animator().alphaValue = Self.peakAlpha
        }

        let hide = DispatchWorkItem { [weak panel] in
            guard let panel = panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Self.fadeOut
                panel.animator().alphaValue = 0
            }, completionHandler: {
                if panel.alphaValue == 0 {
                    panel.orderOut(nil)
                }
            })
        }
        hideWorkItem = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fadeIn + Self.hold, execute: hide)
    }

    private func frame(near pointer: CGPoint) -> CGRect {
        var origin = CGPoint(x: pointer.x + Self.offset.x, y: pointer.y + Self.offset.y - Self.size.height)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX), visible.maxX - Self.size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - Self.size.height)
        }
        return CGRect(origin: origin, size: Self.size)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        return panel
    }
}

private struct FeedbackSymbolView: View {
    let symbolName: String

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(.primary)
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension GestureAction {
    /// SF Symbol shown by `GestureFeedbackPresenter`.
    var feedbackSymbol: String {
        switch self {
        case .browser(let action): return action.feedbackSymbol
        }
    }
}

extension BrowserAction {
    var feedbackSymbol: String {
        switch self {
        case .reload: return "arrow.clockwise"
        case .hardReload: return "arrow.clockwise.circle.fill"
        case .previousTab: return "arrow.left.square"
        case .nextTab: return "arrow.right.square"
        case .newTab: return "plus.square"
        case .closeTab: return "xmark.square"
        case .reopenClosedTab: return "arrow.uturn.backward.square"
        case .back: return "chevron.backward.circle"
        case .forward: return "chevron.forward.circle"
        case .openLinkInNewTab: return "plus.rectangle.on.rectangle"
        case .scrollToTop: return "arrow.up.to.line"
        case .scrollToBottom: return "arrow.down.to.line"
        case .pageUp: return "chevron.up"
        case .pageDown: return "chevron.down"
        }
    }
}
