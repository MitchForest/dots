import AppKit
import DotsEngine

/// The editor's NSTextView: format commands arrive via the responder chain —
/// the Format menu, the floating bar, and keyboard shortcuts all send the
/// same selectors — and apply pure `MarkdownFormatting` results through the
/// undo-aware editing path.
final class FormattingTextView: NSTextView {
    /// True while an assist streams into the document — editing pauses and
    /// esc cancels instead of its usual duty.
    var isAssistRunning = false
    /// True while ghost text awaits its verdict: Tab accepts, esc/backspace
    /// dismiss, anything else is swallowed.
    var isGhostActive = false
    /// True while dictation listens — esc stops it.
    var isDictating = false
    var onAskRequested: ((NSRange) -> Void)?
    var onDictationToggle: ((Int) -> Void)?
    var onAssist: ((AssistKind) -> Void)?
    var onCancelAssist: (() -> Void)?
    var onGhostAccept: (() -> Void)?
    var onGhostDismiss: (() -> Void)?
    var onGhostRequest: ((Int) -> Void)?
    var onSelectionSettled: (() -> Void)?

    /// Scroll-past-end: extra scrollable room below the last line (set to
    /// half the viewport by the coordinator), so the document's end never
    /// pins against the window bottom — the root of end-of-document jitter.
    var overscroll: CGFloat = 0 {
        didSet {
            if abs(overscroll - oldValue) > 1 {
                let contentHeight = frame.height == inflatedHeight
                    ? frame.height - oldValue
                    : frame.height
                inflatedHeight = -1
                setFrameSize(NSSize(width: frame.width, height: contentHeight))
            }
        }
    }

    private var inflatedHeight: CGFloat = -1

    override func setFrameSize(_ newSize: NSSize) {
        // Content-height sets (from layout) get inflated; pass-throughs of
        // our own inflated height (width-only autoresizes) must not compound.
        var size = newSize
        if abs(newSize.height - inflatedHeight) > 0.5 {
            size.height += overscroll
            inflatedHeight = size.height
        }
        super.setFrameSize(size)
    }

    /// Delimiters that wrap the selection when typed over one, and pairs
    /// that auto-close at the caret.
    private static let wrappingPairs: [String: String] = [
        "*": "*", "_": "_", "~": "~", "`": "`", "\"": "\"", "(": ")", "[": "]"
    ]
    private static let caretPairs: [String: String] = ["(": ")", "[": "]", "`": "`"]

    override func mouseDown(with event: NSEvent) {
        if isGhostActive {
            // A click while ghost text is pending is a dismissal, not an edit.
            onGhostDismiss?()
            return
        }
        // NSTextView tracks the entire drag inside mouseDown; when it
        // returns, the selection is final.
        super.mouseDown(with: event)
        onSelectionSettled?()
    }

    override func cancelOperation(_ sender: Any?) {
        if isDictating {
            onDictationToggle?(selectedRange().location)
        } else if isAssistRunning {
            onCancelAssist?()
        } else if isGhostActive {
            onGhostDismiss?()
        } else {
            super.cancelOperation(sender)
        }
    }

    @objc func dotsToggleDictation(_ sender: Any?) {
        onDictationToggle?(selectedRange().location)
    }

    override func deleteBackward(_ sender: Any?) {
        if isGhostActive {
            onGhostDismiss?()
        } else {
            super.deleteBackward(sender)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)
        guard !isAssistRunning else { return menu }
        let assists = NSMenu()
        for kind in AssistKind.menuKinds where selectedRange().length > 0 {
            let item = NSMenuItem(
                title: kind.displayName,
                action: #selector(assistMenuItemSelected(_:)),
                keyEquivalent: ""
            )
            item.representedObject = kind.rawValue
            item.target = self
            assists.addItem(item)
        }
        if selectedRange().length > 0 {
            assists.addItem(NSMenuItem.separator())
            let ask = NSMenuItem(
                title: "Ask AI…",
                action: #selector(askMenuItemSelected(_:)),
                keyEquivalent: ""
            )
            ask.target = self
            assists.addItem(ask)
        }
        let parent = NSMenuItem(title: "Writing Assists", action: nil, keyEquivalent: "")
        parent.submenu = assists
        menu?.insertItem(NSMenuItem.separator(), at: 0)
        menu?.insertItem(parent, at: 0)
        return menu
    }

    @objc private func assistMenuItemSelected(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let kind = AssistKind(rawValue: raw)
        else { return }
        onAssist?(kind)
    }

    @objc private func askMenuItemSelected(_ sender: Any?) {
        _ = sender
        onAskRequested?(selectedRange())
    }

    @objc func dotsAssistAsk(_ sender: Any?) {
        guard selectedRange().length > 0 else { return }
        onAskRequested?(selectedRange())
    }

    // MARK: Assist selectors (responder chain: format bar, Format menu)

    @objc func dotsAssistFixGrammar(_ sender: Any?) {
        onAssist?(.fixGrammar)
    }

    @objc func dotsAssistTighten(_ sender: Any?) {
        onAssist?(.tighten)
    }

    @objc func dotsAssistFormatMarkdown(_ sender: Any?) {
        onAssist?(.formatMarkdown)
    }

    @objc func dotsAssistExpand(_ sender: Any?) {
        onAssist?(.expand)
    }

    // MARK: Typing intelligence

    override func insertNewline(_ sender: Any?) {
        if isGhostActive {
            onGhostDismiss?()
            return
        }
        guard !hasMarkedText() else {
            super.insertNewline(sender)
            return
        }
        let contents = string as NSString
        let caret = selectedRange()
        let lineRange = contents.lineRange(for: NSRange(location: caret.location, length: 0))
        // Only the text up to the caret decides: Return mid-item splits it.
        let upToCaret = contents.substring(
            with: NSRange(location: lineRange.location, length: caret.location - lineRange.location)
        )
        switch MarkdownTyping.returnBehavior(forLine: upToCaret) {
        case .plain:
            super.insertNewline(sender)
        case .continueMarker(let marker):
            super.insertNewline(sender)
            insertText(marker, replacementRange: selectedRange())
        case .exitEmptyItem(let markerRange):
            let target = NSRange(
                location: lineRange.location + markerRange.lowerBound,
                length: markerRange.count
            )
            if shouldChangeText(in: target, replacementString: "") {
                textStorage?.replaceCharacters(in: target, with: "")
                didChangeText()
            }
        }
    }

    override func insertTab(_ sender: Any?) {
        guard !hasMarkedText() else {
            super.insertTab(sender)
            return
        }
        // The Tab contract: accept a pending ghost; indent a list line;
        // otherwise summon a ghost completion at the caret. Prose never
        // gets a literal tab.
        if isGhostActive {
            onGhostAccept?()
            return
        }
        if rewriteCurrentLine(MarkdownTyping.indented) {
            return
        }
        if isAssistRunning {
            return
        }
        guard selectedRange().length == 0 else {
            super.insertTab(sender)
            return
        }
        onGhostRequest?(selectedRange().location)
    }

    override func insertBacktab(_ sender: Any?) {
        guard !hasMarkedText(), rewriteCurrentLine(MarkdownTyping.outdented) else {
            super.insertBacktab(sender)
            return
        }
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        if isGhostActive {
            // Typing over a pending ghost dismisses it; the keystroke is
            // swallowed so it can't land inside vanishing text.
            onGhostDismiss?()
            return
        }
        guard !hasMarkedText(), let typed = insertString as? String else {
            super.insertText(insertString, replacementRange: replacementRange)
            return
        }
        let selection = selectedRange()
        // Typing a delimiter over a selection wraps it.
        if selection.length > 0, let closer = Self.wrappingPairs[typed] {
            let selected = (string as NSString).substring(with: selection)
            super.insertText(typed + selected + closer, replacementRange: selection)
            setSelectedRange(NSRange(location: selection.location + (typed as NSString).length, length: selection.length))
            return
        }
        // Type-over: typing the closer that already sits at the caret.
        if selection.length == 0, Self.caretPairs.values.contains(typed),
           nextCharacter(at: selection.location) == typed {
            setSelectedRange(NSRange(location: selection.location + (typed as NSString).length, length: 0))
            return
        }
        // Auto-pair at the caret.
        if selection.length == 0, let closer = Self.caretPairs[typed] {
            super.insertText(typed + closer, replacementRange: replacementRange)
            setSelectedRange(NSRange(location: selection.location + (typed as NSString).length, length: 0))
            return
        }
        super.insertText(insertString, replacementRange: replacementRange)
    }

    /// Rewrites the caret's line when it carries a block marker; returns
    /// false to fall through to the default key behavior.
    private func rewriteCurrentLine(_ transform: (String) -> String) -> Bool {
        let contents = string as NSString
        let caret = selectedRange()
        let lineRange = contents.lineRange(for: NSRange(location: caret.location, length: 0))
        let line = contents.substring(with: lineRange)
        let trimmed = line.hasSuffix("\n") ? String(line.dropLast()) : line
        guard MarkdownTyping.hasBlockMarker(trimmed) else { return false }
        let rewritten = transform(trimmed)
        let target = NSRange(location: lineRange.location, length: (trimmed as NSString).length)
        guard shouldChangeText(in: target, replacementString: rewritten) else { return true }
        let delta = (rewritten as NSString).length - target.length
        textStorage?.replaceCharacters(in: target, with: rewritten)
        didChangeText()
        setSelectedRange(NSRange(location: max(lineRange.location, caret.location + delta), length: 0))
        return true
    }

    private func nextCharacter(at location: Int) -> String? {
        let contents = string as NSString
        guard location < contents.length else { return nil }
        return contents.substring(with: NSRange(location: location, length: 1))
    }

    // MARK: Inline styles

    @objc func dotsToggleBold(_ sender: Any?) {
        apply { MarkdownFormatting.toggle(.bold, in: $0, selection: $1) }
    }

    @objc func dotsToggleItalic(_ sender: Any?) {
        apply { MarkdownFormatting.toggle(.italic, in: $0, selection: $1) }
    }

    @objc func dotsToggleStrikethrough(_ sender: Any?) {
        apply { MarkdownFormatting.toggle(.strikethrough, in: $0, selection: $1) }
    }

    @objc func dotsToggleCode(_ sender: Any?) {
        apply { MarkdownFormatting.toggle(.code, in: $0, selection: $1) }
    }

    @objc func dotsInsertLink(_ sender: Any?) {
        apply { MarkdownFormatting.insertLink(in: $0, selection: $1) }
    }

    // MARK: Line styles

    @objc func dotsHeading1(_ sender: Any?) {
        apply { MarkdownFormatting.toggle(.heading(1), in: $0, selection: $1) }
    }

    @objc func dotsHeading2(_ sender: Any?) {
        apply { MarkdownFormatting.toggle(.heading(2), in: $0, selection: $1) }
    }

    @objc func dotsHeading3(_ sender: Any?) {
        apply { MarkdownFormatting.toggle(.heading(3), in: $0, selection: $1) }
    }

    @objc func dotsToggleBullet(_ sender: Any?) {
        apply { MarkdownFormatting.toggle(.bullet, in: $0, selection: $1) }
    }

    @objc func dotsToggleOrdered(_ sender: Any?) {
        apply { MarkdownFormatting.toggle(.ordered, in: $0, selection: $1) }
    }

    @objc func dotsToggleQuote(_ sender: Any?) {
        apply { MarkdownFormatting.toggle(.quote, in: $0, selection: $1) }
    }

    // MARK: Applying

    private func apply(_ command: (String, Range<Int>) -> MarkdownFormatting.Result) {
        let current = selectedRange()
        let selection = current.location..<(current.location + current.length)
        let result = command(string, selection)

        if result.text != string {
            let full = NSRange(location: 0, length: (string as NSString).length)
            guard shouldChangeText(in: full, replacementString: result.text) else { return }
            textStorage?.replaceCharacters(in: full, with: result.text)
            didChangeText()
        }
        let newRange = NSRange(
            location: result.selection.lowerBound,
            length: result.selection.count
        )
        setSelectedRange(newRange)
        scrollRangeToVisible(newRange)
        onSelectionSettled?()
    }
}
