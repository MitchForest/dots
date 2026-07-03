import AppKit
import SwiftUI

/// Fades the window's entire titlebar — traffic lights, title, toolbar
/// items and their glass — as one unit, by animating the titlebar
/// container's alpha. This is what makes the chrome fade feel like one
/// breath instead of four mechanisms: nothing is removed, nothing pops,
/// and controls keep their shortcuts while invisible. Slow out (a sunset),
/// quick in (you're reaching for them). Invisible helper view; lives in
/// the workspace background.
struct WindowChromeFader: NSViewRepresentable {
    let isFaded: Bool

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let window = view.window,
              let titlebar = Self.titlebarContainer(of: window)
        else { return }
        let alpha: CGFloat = isFaded ? 0 : 1
        guard titlebar.alphaValue != alpha else { return }
        NSAnimationContext.runAnimationGroup { animation in
            animation.duration = isFaded ? 0.7 : 0.25
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            titlebar.animator().alphaValue = alpha
        }
    }

    /// The close button sits inside the titlebar hierarchy; walk up to the
    /// container that also holds the toolbar.
    private static func titlebarContainer(of window: NSWindow) -> NSView? {
        var view = window.standardWindowButton(.closeButton)?.superview
        while let current = view {
            if String(describing: type(of: current)).contains("NSTitlebarContainerView") {
                return current
            }
            view = current.superview
        }
        return nil
    }
}
