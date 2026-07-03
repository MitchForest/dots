import AppKit
import Carbon.HIToolbox
import DotsRoot
import SwiftUI

/// Owns what SwiftUI scenes can't: the global capture hotkey.
@MainActor
final class DotsAppDelegate: NSObject, NSApplicationDelegate {
    // periphery:ignore - retained for its registration side effect
    private var captureHotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ⌥Space, from anywhere, while Dots runs.
        captureHotKey = GlobalHotKey(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey)
        ) {
            CapturePanelController.shared.toggle()
        }
    }
}

@main
struct DotsApp: App {
    @NSApplicationDelegateAdaptor(DotsAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            DotsRootScreen()
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Sign Out…") {
                    DotsRootScreen.signOut()
                }
            }
            // Find routes to the focused text view's find bar; disabled (and
            // the shortcut released to views) when no editor has focus.
            CommandGroup(after: .pasteboard) {
                Divider()
                find("Find…", .showFindInterface).keyboardShortcut("f")
                find("Find Next", .nextMatch).keyboardShortcut("g")
                find("Find Previous", .previousMatch)
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            // Format commands route down the responder chain to the focused
            // editor; AppKit disables them when no editor responds.
            CommandMenu("Format") {
                format("Bold", "dotsToggleBold:").keyboardShortcut("b")
                format("Italic", "dotsToggleItalic:").keyboardShortcut("i")
                format("Strikethrough", "dotsToggleStrikethrough:")
                    .keyboardShortcut("x", modifiers: [.command, .shift])
                format("Code", "dotsToggleCode:").keyboardShortcut("e")
                format("Link", "dotsInsertLink:").keyboardShortcut("k")
                Divider()
                format("Heading 1", "dotsHeading1:").keyboardShortcut("1")
                format("Heading 2", "dotsHeading2:").keyboardShortcut("2")
                format("Heading 3", "dotsHeading3:").keyboardShortcut("3")
                Divider()
                format("Bullet List", "dotsToggleBullet:")
                    .keyboardShortcut("8", modifiers: [.command, .shift])
                format("Numbered List", "dotsToggleOrdered:")
                    .keyboardShortcut("7", modifiers: [.command, .shift])
                format("Quote", "dotsToggleQuote:")
                    .keyboardShortcut("9", modifiers: [.command, .shift])
                Divider()
                format("Fix Grammar", "dotsAssistFixGrammar:")
                format("Tighten", "dotsAssistTighten:")
                format("Expand", "dotsAssistExpand:")
                format("Format as Markdown", "dotsAssistFormatMarkdown:")
            }
        }

        // ⌘, — the one place Dots has configuration: which AI answers.
        Settings {
            DotsSettingsScreen()
        }

        // The always-there dot: capture from anywhere, status at a glance.
        // Brand blue like the browser extension's dot — a full-color icon,
        // deliberately not a template, so it stands out in the menu bar.
        MenuBarExtra {
            DotsMenuBarContent()
        } label: {
            Image(nsImage: Self.menuBarDot)
        }
    }

    /// The same dot the Chrome extension wears: system blue, non-template.
    /// The drawing block re-runs per appearance, so the blue tracks the
    /// system accent rendering in light and dark menu bars.
    private static let menuBarDot: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let diameter: CGFloat = 12
            let dotRect = NSRect(
                x: (rect.width - diameter) / 2,
                y: (rect.height - diameter) / 2,
                width: diameter,
                height: diameter
            )
            NSColor.systemBlue.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }()

    private func format(_ title: String, _ selector: String) -> some View {
        Button(title) {
            NSApp.sendAction(Selector((selector)), to: nil, from: nil)
        }
    }

    private struct DotsMenuBarContent: View {
        @Environment(\.openWindow) private var openWindow

        var body: some View {
            Button("Capture…") {
                CapturePanelController.shared.toggle()
            }
            .keyboardShortcut(" ", modifiers: .option)
            Button("Open Dots") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("Quit Dots") {
                NSApp.terminate(nil)
            }
        }
    }

    private func find(_ title: String, _ action: NSTextFinder.Action) -> some View {
        Button(title) {
            // performTextFinderAction reads the action from the sender's tag.
            let proxy = NSMenuItem()
            proxy.tag = action.rawValue
            NSApp.sendAction(
                #selector(NSTextView.performTextFinderAction(_:)),
                to: nil,
                from: proxy
            )
        }
    }
}
