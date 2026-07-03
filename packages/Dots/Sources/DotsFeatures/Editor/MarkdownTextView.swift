import AppKit
import DotsEngine
import SwiftUI

/// The writing surface: a TextKit 2 NSTextView with soft wrap, native
/// undo/IME, and live per-line markdown styling driven by
/// `MarkdownLineStyler`.
///
/// Two presentations of the same buffer — no serialization, ever:
/// - Markdown: every character visible, syntax dimmed.
/// - Rich: syntax concealed except on the caret's line, which reveals for
///   editing and re-conceals when the caret leaves (live-preview style).
///
/// Colors use system semantic NSColors (label/tertiary/link) so styling
/// resolves automatically on appearance changes without a restyle pass.
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var isRich = false
    /// Focus dims everything outside the caret's paragraph.
    var isFocusMode = false
    /// Keeps the caret vertically centered while writing.
    var isTypewriter = false
    /// While an assist streams, editing pauses and esc cancels it.
    var isAssistRunning = false
    /// The pending ghost completion's range — rendered dimmed-italic until
    /// Tab accepts or esc/backspace/typing dismisses.
    var ghostRange: NSRange?
    /// Live dictation's volatile hypothesis — same dimmed styling as the
    /// ghost, but without the Tab/esc verdict keys.
    var dictationVolatileRange: NSRange?
    var isDictating = false
    var onAskRequested: ((NSRange) -> Void)?
    var onDictationToggle: ((Int) -> Void)?
    var onAssist: ((AssistKind, NSRange) -> Void)?
    var onCancelAssist: (() -> Void)?
    var onGhostAccept: (() -> Void)?
    var onGhostDismiss: (() -> Void)?
    var onGhostRequest: ((Int) -> Void)?
    /// The settled selection's first-line rect, in this view's coordinate
    /// space (top-left origin) — the floating format bar anchors to it.
    /// Nil = no settled selection, bar hidden.
    var formatBarAnchor: Binding<CGRect?>?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isRich: isRich, formatBarAnchor: formatBarAnchor)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = FormattingTextView(usingTextLayoutManager: true)
        textView.allowsUndo = true
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.font = MarkdownEditorFont.base
        textView.isHorizontallyResizable = false
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 24, height: 32)
        textView.typingAttributes = MarkdownEditorStyle.baseAttributes

        // Native text services, opinionated: smart punctuation on, spell and
        // grammar underlines on, and nothing that rewrites your words.
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        // Calm surface: the scroller exists only while scrolling.
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        textView.string = text
        textView.onSelectionSettled = { [weak textView, weak coordinator = context.coordinator] in
            guard let textView, let coordinator else { return }
            coordinator.selectionSettled(textView)
        }
        textView.onAssist = { [weak textView, weak coordinator = context.coordinator] kind in
            guard let textView, let coordinator else { return }
            coordinator.onAssist?(kind, textView.selectedRange())
        }
        textView.onCancelAssist = { [weak coordinator = context.coordinator] in
            coordinator?.onCancelAssist?()
        }
        textView.onAskRequested = { [weak coordinator = context.coordinator] range in
            coordinator?.onAskRequested?(range)
        }
        textView.onDictationToggle = { [weak coordinator = context.coordinator] location in
            coordinator?.onDictationToggle?(location)
        }
        textView.onGhostAccept = { [weak coordinator = context.coordinator] in
            coordinator?.onGhostAccept?()
        }
        textView.onGhostDismiss = { [weak coordinator = context.coordinator] in
            coordinator?.onGhostDismiss?()
        }
        textView.onGhostRequest = { [weak coordinator = context.coordinator] location in
            coordinator?.onGhostRequest?(location)
        }
        // Scrolling detaches the bar from its text; hide rather than drift.
        // The same notification keeps the overscroll sized to the viewport.
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollChanged(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        textView.overscroll = scrollView.contentView.bounds.height / 2
        context.coordinator.restyleAll(textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        context.coordinator.onAskRequested = onAskRequested
        context.coordinator.onAssist = onAssist
        context.coordinator.onCancelAssist = onCancelAssist
        context.coordinator.onGhostAccept = onGhostAccept
        context.coordinator.onGhostDismiss = onGhostDismiss
        context.coordinator.onGhostRequest = onGhostRequest
        context.coordinator.onDictationToggle = onDictationToggle
        // Accepting a ghost changes styling without changing text — the
        // range diff must trigger its own repaint. Dictation's volatile
        // range shares the ghost styling channel (without the verdict keys).
        let styledGhost = ghostRange ?? dictationVolatileRange
        let ghostChanged = context.coordinator.ghostRange != styledGhost
        context.coordinator.ghostRange = styledGhost
        if let formatting = textView as? FormattingTextView {
            formatting.isAssistRunning = isAssistRunning
            formatting.isDictating = isDictating
            formatting.isEditable = !isAssistRunning && !isDictating
            formatting.isGhostActive = ghostRange != nil
        }
        context.coordinator.isTypewriter = isTypewriter
        if context.coordinator.isRich != isRich
            || context.coordinator.isFocusMode != isFocusMode
            || ghostChanged {
            context.coordinator.isFocusMode = isFocusMode
            context.coordinator.isRich = isRich
            context.coordinator.restyleAll(textView)
        }
        guard textView.string != text else { return }

        // External update (reload, document switch): replace wholesale,
        // keeping the selection pinned within bounds.
        let selection = textView.selectedRange()
        textView.string = text
        let limit = (text as NSString).length
        textView.setSelectedRange(NSRange(location: min(selection.location, limit), length: 0))
        context.coordinator.restyleAll(textView)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var ghostRange: NSRange?
        var isFocusMode = false
        var isRich: Bool
        var isTypewriter = false
        var onAskRequested: ((NSRange) -> Void)?
        var onDictationToggle: ((Int) -> Void)?
        var onAssist: ((AssistKind, NSRange) -> Void)?
        var onCancelAssist: (() -> Void)?
        var onGhostAccept: (() -> Void)?
        var onGhostDismiss: (() -> Void)?
        var onGhostRequest: ((Int) -> Void)?
        private var activeLineRange = NSRange(location: 0, length: 0)
        private var focusRange: NSRange?
        private let formatBarAnchor: Binding<CGRect?>?
        private let text: Binding<String>

        init(text: Binding<String>, isRich: Bool, formatBarAnchor: Binding<CGRect?>?) {
            self.formatBarAnchor = formatBarAnchor
            self.isRich = isRich
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            activeLineRange = Self.caretLineRange(of: textView)
            formatBarAnchor?.wrappedValue = nil
            let previousFocusStart = focusRange?.location
            if refreshFocus(textView), focusRange?.location != previousFocusStart {
                // A different paragraph came into focus — the dim region
                // moved, repaint everything. Mere growth of the current
                // paragraph (every keystroke) only needs the edited line;
                // a full-document restyle per keystroke makes layout churn
                // visibly at the bottom of the page.
                MarkdownEditorStyle.restyleAll(
                    textView,
                    concealing: isRich,
                    activeLine: activeLineRange,
                    focus: focusRange,
                    ghost: ghostRange
                )
            } else {
                MarkdownEditorStyle.restyleAfterEdit(
                    textView,
                    concealing: isRich,
                    activeLine: activeLineRange,
                    focus: focusRange,
                    ghost: ghostRange
                )
            }
            if isTypewriter {
                centerCaret(textView)
            } else {
                keepCaretMargin(textView)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Keyboard-driven selection settles immediately; mouse drags
            // settle when mouseDown returns (see FormattingTextView).
            if NSEvent.pressedMouseButtons & 1 == 0 {
                selectionSettled(textView)
            }
            let focusChanged = refreshFocus(textView)
            let newActive = Self.caretLineRange(of: textView)
            let lineChanged = newActive != activeLineRange
            let previous = activeLineRange
            activeLineRange = newActive

            if focusChanged {
                // The dimmed region spans the document; repaint it all.
                MarkdownEditorStyle.restyleAll(
                    textView,
                    concealing: isRich,
                    activeLine: newActive,
                    focus: focusRange,
                    ghost: ghostRange
                )
            } else if isRich, lineChanged {
                // Re-conceal the line the caret left; reveal the one it entered.
                for location in [previous.location, newActive.location] {
                    MarkdownEditorStyle.restyle(
                        textView,
                        lineAt: location,
                        concealing: isRich,
                        activeLine: newActive,
                        focus: focusRange,
                        ghost: ghostRange
                    )
                }
            }
        }

        /// Recomputes the focus range around the caret; true when it moved.
        private func refreshFocus(_ textView: NSTextView) -> Bool {
            let newRange: NSRange?
            if isFocusMode {
                let contents = textView.string
                let caret = min(textView.selectedRange().location, (contents as NSString).length)
                let range = FocusRanges.paragraph(around: caret, in: contents)
                newRange = NSRange(location: range.lowerBound, length: range.count)
            } else {
                newRange = nil
            }
            guard newRange != focusRange else { return false }
            focusRange = newRange
            return true
        }

        private func centerCaret(_ textView: NSTextView) {
            guard let window = textView.window,
                  let scrollView = textView.enclosingScrollView
            else { return }
            var actual = NSRange()
            let caret = textView.selectedRange()
            let screenRect = textView.firstRect(
                forCharacterRange: NSRange(location: caret.location, length: 0),
                actualRange: &actual
            )
            guard screenRect.height > 0 else { return }
            let local = textView.convert(window.convertFromScreen(screenRect), from: nil)
            let visibleHeight = scrollView.contentView.bounds.height
            // Clamp to the scrollable range: past-the-end targets fight the
            // clip view's own constraint and read as an up-down jump.
            let maxOffset = max(0, textView.frame.height - visibleHeight)
            let target = min(max(0, local.midY - visibleHeight / 2), maxOffset)
            // Skip sub-point adjustments — they read as jitter, not centering.
            guard abs(target - scrollView.contentView.bounds.origin.y) > 1 else { return }
            scrollView.contentView.setBoundsOrigin(
                NSPoint(x: scrollView.contentView.bounds.origin.x, y: target)
            )
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        func selectionSettled(_ textView: NSTextView) {
            guard let formatBarAnchor else { return }
            let selection = textView.selectedRange()
            guard selection.length > 0,
                  let window = textView.window,
                  let scrollView = textView.enclosingScrollView
            else {
                formatBarAnchor.wrappedValue = nil
                return
            }
            var actual = NSRange()
            let screenRect = textView.firstRect(forCharacterRange: selection, actualRange: &actual)
            guard screenRect.width.isFinite, screenRect.height > 0 else {
                formatBarAnchor.wrappedValue = nil
                return
            }
            let windowRect = window.convertFromScreen(screenRect)
            let viewRect = scrollView.convert(windowRect, from: nil)
            // SwiftUI's overlay space is top-left origin; AppKit's here is not.
            let topY = scrollView.isFlipped
                ? viewRect.minY
                : scrollView.bounds.height - viewRect.maxY
            formatBarAnchor.wrappedValue = CGRect(
                x: viewRect.minX,
                y: topY,
                width: viewRect.width,
                height: viewRect.height
            )
        }

        @objc func scrollChanged(_ notification: Notification) {
            formatBarAnchor?.wrappedValue = nil
            guard let clipView = notification.object as? NSClipView,
                  let textView = clipView.documentView as? FormattingTextView
            else { return }
            textView.overscroll = clipView.bounds.height / 2
        }

        /// The caret never rides the viewport's bottom edge: when typing
        /// would push it within the keep-away margin, one exact scroll holds
        /// it at a fixed visual line — text flows up, eyes stay still.
        private func keepCaretMargin(_ textView: NSTextView) {
            guard let window = textView.window,
                  let scrollView = textView.enclosingScrollView
            else { return }
            let margin: CGFloat = 96
            var actual = NSRange()
            let caret = textView.selectedRange()
            let screenRect = textView.firstRect(
                forCharacterRange: NSRange(location: caret.location, length: 0),
                actualRange: &actual
            )
            guard screenRect.height > 0 else { return }
            let local = textView.convert(window.convertFromScreen(screenRect), from: nil)
            let clipView = scrollView.contentView
            let visibleBottom = clipView.bounds.origin.y + clipView.bounds.height
            guard local.maxY > visibleBottom - margin else { return }
            let maxOffset = max(0, textView.frame.height - clipView.bounds.height)
            let target = min(max(0, local.maxY - clipView.bounds.height + margin), maxOffset)
            guard abs(target - clipView.bounds.origin.y) > 1 else { return }
            clipView.setBoundsOrigin(NSPoint(x: clipView.bounds.origin.x, y: target))
            scrollView.reflectScrolledClipView(clipView)
        }

        func restyleAll(_ textView: NSTextView) {
            activeLineRange = Self.caretLineRange(of: textView)
            _ = refreshFocus(textView)
            MarkdownEditorStyle.restyleAll(
                textView,
                concealing: isRich,
                activeLine: activeLineRange,
                focus: focusRange,
                ghost: ghostRange
            )
        }

        private static func caretLineRange(of textView: NSTextView) -> NSRange {
            let contents = textView.string as NSString
            let caret = min(textView.selectedRange().location, contents.length)
            return contents.lineRange(for: NSRange(location: caret, length: 0))
        }
    }
}

// MARK: - Styling

private enum MarkdownEditorFont {
    static let base = NSFont.systemFont(ofSize: 16, weight: .regular)
    static let bold = NSFont.systemFont(ofSize: 16, weight: .semibold)
    static let mono = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    /// Concealment: effectively zero advance, characters stay in the buffer.
    static let concealed = NSFont.systemFont(ofSize: 0.1)

    static let italic: NSFont = {
        let descriptor = base.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: base.pointSize) ?? base
    }()

    static func heading(_ level: Int) -> NSFont {
        let sizes: [CGFloat] = [28, 23, 20, 18, 17, 16]
        let size = sizes[min(max(level, 1), 6) - 1]
        return NSFont.systemFont(ofSize: size, weight: .bold)
    }
}

private enum MarkdownEditorStyle {
    static var baseAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.35
        return [
            .font: MarkdownEditorFont.base,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
            .strikethroughStyle: 0
        ]
    }

    static func restyleAll(
        _ textView: NSTextView,
        concealing: Bool,
        activeLine: NSRange,
        focus: NSRange?,
        ghost: NSRange?
    ) {
        guard let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        style(
            storage: storage,
            in: full,
            contents: textView.string,
            concealing: concealing,
            activeLine: activeLine,
            focus: focus,
            ghost: ghost
        )
    }

    /// Restyles the edited line; fence-toggling edits restyle everything
    /// because fence state changes every line below.
    static func restyleAfterEdit(
        _ textView: NSTextView,
        concealing: Bool,
        activeLine: NSRange,
        focus: NSRange?,
        ghost: NSRange?
    ) {
        let contents = textView.string as NSString
        let caret = min(textView.selectedRange().location, contents.length)
        let lineRange = contents.lineRange(for: NSRange(location: caret, length: 0))

        if contents.substring(with: lineRange).contains("```") {
            restyleAll(textView, concealing: concealing, activeLine: activeLine, focus: focus, ghost: ghost)
        } else {
            restyle(
                textView,
                lineAt: lineRange.location,
                concealing: concealing,
                activeLine: activeLine,
                focus: focus,
                ghost: ghost
            )
        }
    }

    static func restyle(
        _ textView: NSTextView,
        lineAt location: Int,
        concealing: Bool,
        activeLine: NSRange,
        focus: NSRange?,
        ghost: NSRange?
    ) {
        guard let storage = textView.textStorage else { return }
        let contents = textView.string as NSString
        guard location <= contents.length else { return }
        let lineRange = contents.lineRange(for: NSRange(location: min(location, contents.length), length: 0))
        style(
            storage: storage,
            in: lineRange,
            contents: textView.string,
            concealing: concealing,
            activeLine: activeLine,
            focus: focus,
            ghost: ghost
        )
    }

    private static func style(
        storage: NSTextStorage,
        in range: NSRange,
        contents: String,
        concealing: Bool,
        activeLine: NSRange,
        focus: NSRange?,
        ghost: NSRange?
    ) {
        let nsContents = contents as NSString
        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: range)

        var fenceOpen = false
        var location = 0
        while location < nsContents.length {
            let lineRange = nsContents.lineRange(for: NSRange(location: location, length: 0))
            defer { location = lineRange.location + lineRange.length }

            let line = nsContents.substring(with: lineRange)
                .trimmingCharacters(in: .newlines)
            let isFenceLine = line.trimmingCharacters(in: .whitespaces).hasPrefix("```")

            let intersects = NSIntersectionRange(lineRange, range).length > 0
                || (lineRange.length == 0 && lineRange.location >= range.location)
            if intersects {
                // The caret's line always reveals its syntax for editing.
                let conceal = concealing && NSIntersectionRange(lineRange, activeLine) != lineRange
                if fenceOpen || isFenceLine {
                    storage.addAttributes(
                        [
                            .font: MarkdownEditorFont.mono,
                            .foregroundColor: NSColor.secondaryLabelColor
                        ],
                        range: NSRange(location: lineRange.location, length: (line as NSString).length)
                    )
                } else {
                    apply(
                        spans: MarkdownLineStyler.spans(forLine: line, inCodeFence: false),
                        lineStart: lineRange.location,
                        to: storage,
                        concealed: conceal
                    )
                }
                if let focus {
                    dim(storage: storage, lineRange: lineRange, focus: focus)
                }
                if let ghost {
                    paintGhost(storage: storage, lineRange: lineRange, ghost: ghost)
                }
            }

            if isFenceLine {
                fenceOpen.toggle()
            }
            if lineRange.length == 0 { break }
        }
        storage.endEditing()
    }

    /// Pending ghost text renders dimmed-italic — visibly not yet yours.
    private static func paintGhost(storage: NSTextStorage, lineRange: NSRange, ghost: NSRange) {
        let intersection = NSIntersectionRange(lineRange, ghost)
        guard intersection.length > 0 else { return }
        storage.addAttributes(
            [
                .foregroundColor: NSColor.tertiaryLabelColor,
                .font: MarkdownEditorFont.italic
            ],
            range: intersection
        )
    }

    /// Focus mode: everything on this line outside the focus range recedes
    /// to muted ink. Concealed (clear) runs stay concealed.
    private static func dim(storage: NSTextStorage, lineRange: NSRange, focus: NSRange) {
        let inFocus = NSIntersectionRange(lineRange, focus)
        var outside: [NSRange] = []
        if inFocus.length == 0 {
            outside = [lineRange]
        } else {
            if inFocus.location > lineRange.location {
                outside.append(
                    NSRange(
                        location: lineRange.location,
                        length: inFocus.location - lineRange.location
                    )
                )
            }
            let focusEnd = inFocus.location + inFocus.length
            let lineEnd = lineRange.location + lineRange.length
            if lineEnd > focusEnd {
                outside.append(NSRange(location: focusEnd, length: lineEnd - focusEnd))
            }
        }
        for range in outside where range.length > 0 {
            storage.enumerateAttribute(.foregroundColor, in: range) { value, subrange, _ in
                if (value as? NSColor) != NSColor.clear {
                    storage.addAttribute(
                        .foregroundColor,
                        value: NSColor.tertiaryLabelColor,
                        range: subrange
                    )
                }
            }
        }
    }

    private static func apply(
        spans: [MarkdownSpan],
        lineStart: Int,
        to storage: NSTextStorage,
        concealed: Bool
    ) {
        for span in spans {
            let range = NSRange(
                location: lineStart + span.range.lowerBound,
                length: span.range.upperBound - span.range.lowerBound
            )
            guard range.location + range.length <= storage.length else { continue }
            storage.addAttributes(attributes(for: span.kind, concealed: concealed), range: range)
        }
    }

    private static func attributes(
        for kind: MarkdownSpan.Kind,
        concealed: Bool
    ) -> [NSAttributedString.Key: Any] {
        switch kind {
        case .blockquoteMarker:
            [.foregroundColor: NSColor.tertiaryLabelColor]
        case .codeFenceMarker:
            [.font: MarkdownEditorFont.mono, .foregroundColor: NSColor.tertiaryLabelColor]
        case .codeSpan:
            [.font: MarkdownEditorFont.mono, .foregroundColor: NSColor.secondaryLabelColor]
        case .emphasis:
            [.font: MarkdownEditorFont.italic]
        case .heading(let level):
            [.font: MarkdownEditorFont.heading(level)]
        case .linkText:
            [.foregroundColor: NSColor.linkColor]
        case .linkURL:
            concealed
                ? [.font: MarkdownEditorFont.concealed, .foregroundColor: NSColor.clear]
                : [.foregroundColor: NSColor.tertiaryLabelColor]
        case .listMarker:
            [.foregroundColor: NSColor.tertiaryLabelColor]
        case .strikethrough:
            [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        case .strong:
            [.font: MarkdownEditorFont.bold]
        case .syntax:
            concealed
                ? [.font: MarkdownEditorFont.concealed, .foregroundColor: NSColor.clear]
                : [.foregroundColor: NSColor.tertiaryLabelColor]
        }
    }
}
