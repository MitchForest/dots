import AppKit
import DotsRoot
import SwiftUI

/// The floating quick-capture panel: summoned from anywhere by ⌥Space or
/// the menu bar, dismissed by esc, capture, or clicking away.
@MainActor
final class CapturePanelController {
    static let shared = CapturePanelController()

    private var panel: NSPanel?
    private var resignObserver: (any NSObjectProtocol)?

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func close() {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }

    private func show() {
        let hosting = NSHostingController(
            rootView: DotsCaptureScreen { [weak self] in
                self?.close()
            }
        )
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.titled, .fullSizeContentView, .nonactivatingPanel]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false

        // Spotlight posture: centered, upper third of the main screen.
        panel.layoutIfNeeded()
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(
                NSPoint(
                    x: frame.midX - size.width / 2,
                    y: frame.minY + frame.height * 0.62
                )
            )
        }

        self.panel = panel
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // Clicking away means never mind.
            MainActor.assumeIsolated {
                self?.close()
            }
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
