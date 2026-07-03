/// Typing intelligence for markdown lines: what Return, Tab, and ⇧Tab do
/// on list, task, and quote lines. Pure — the text view applies results.
public enum MarkdownTyping {
    public enum ReturnBehavior: Equatable, Sendable {
        /// Ordinary newline.
        case plain
        /// Newline followed by this continuation marker (indentation included).
        case continueMarker(String)
        /// The item is empty: delete this range within the line (the marker)
        /// instead of inserting a newline — exits the list/quote.
        case exitEmptyItem(markerRange: Range<Int>)
    }

    /// Behavior of Return pressed with the caret at the END of `line`
    /// (the common case; callers may pass the text up to the caret).
    public static func returnBehavior(forLine line: String) -> ReturnBehavior {
        let units = Array(line.utf16)
        guard let marker = BlockMarker.parse(units) else { return .plain }
        guard marker.hasContent(in: units) else {
            // An empty item exits: everything before the (missing) content is
            // the marker plus whitespace, so deleting the whole non-content
            // prefix leaves an empty line.
            return .exitEmptyItem(markerRange: 0..<units.count)
        }
        return .continueMarker(marker.continuation(in: units))
    }

    /// True when the line carries a list/task/quote marker (Tab indents).
    public static func hasBlockMarker(_ line: String) -> Bool {
        BlockMarker.parse(Array(line.utf16)) != nil
    }

    /// The line indented by two spaces.
    public static func indented(_ line: String) -> String {
        "  " + line
    }

    /// The line outdented by up to two leading spaces.
    public static func outdented(_ line: String) -> String {
        let units = Array(line.utf16)
        var removed = 0
        while removed < 2, removed < units.count, units[removed] == Unit.space {
            removed += 1
        }
        return String(decoding: units[removed...], as: UTF16.self)
    }
}

// MARK: - Marker parsing

/// A block marker at the head of a line: leading whitespace, then a bullet,
/// task checkbox, ordered number, or quote angle, each with its trailing
/// space. Offsets are UTF-16 code units within the line.
private struct BlockMarker {
    enum Kind: Equatable {
        case bullet(UInt16)
        case ordered(number: Int, punctuation: UInt16)
        case quote
        case task
    }

    let indentEnd: Int
    let kind: Kind
    let markerEnd: Int

    static func parse(_ units: [UInt16]) -> BlockMarker? {
        var indent = 0
        while indent < units.count, isWhitespace(units[indent]) {
            indent += 1
        }
        guard indent < units.count else { return nil }
        if let quote = parseQuote(units, indent: indent) { return quote }
        if let bullet = parseBullet(units, indent: indent) { return bullet }
        return parseOrdered(units, indent: indent)
    }

    /// True when anything but whitespace follows the marker.
    func hasContent(in units: [UInt16]) -> Bool {
        units[markerEnd...].contains { !Self.isWhitespace($0) }
    }

    /// The marker the next line starts with, indentation included.
    func continuation(in units: [UInt16]) -> String {
        let indent = String(decoding: units[..<indentEnd], as: UTF16.self)
        switch kind {
        case .bullet(let bullet):
            return indent + String(decoding: [bullet, Unit.space], as: UTF16.self)
        case .ordered(let number, let punctuation):
            return indent + "\(number + 1)" + String(decoding: [punctuation, Unit.space], as: UTF16.self)
        case .quote:
            return indent + "> "
        case .task:
            // A finished task never carries its checkmark forward.
            return indent + "- [ ] "
        }
    }

    // MARK: Kinds

    private static func parseQuote(_ units: [UInt16], indent: Int) -> BlockMarker? {
        guard units[indent] == Unit.greaterThan, unit(units, at: indent + 1) == Unit.space else { return nil }
        return BlockMarker(indentEnd: indent, kind: .quote, markerEnd: indent + 2)
    }

    private static func parseBullet(_ units: [UInt16], indent: Int) -> BlockMarker? {
        let bullet = units[indent]
        let isBullet = bullet == Unit.hyphen || bullet == Unit.asterisk || bullet == Unit.plus
        guard isBullet, unit(units, at: indent + 1) == Unit.space else { return nil }
        if isCheckbox(units, at: indent + 2) {
            return BlockMarker(indentEnd: indent, kind: .task, markerEnd: indent + 6)
        }
        return BlockMarker(indentEnd: indent, kind: .bullet(bullet), markerEnd: indent + 2)
    }

    private static func isCheckbox(_ units: [UInt16], at index: Int) -> Bool {
        guard unit(units, at: index) == Unit.openBracket else { return false }
        guard let mark = unit(units, at: index + 1) else { return false }
        guard mark == Unit.space || mark == Unit.lowerX || mark == Unit.upperX else { return false }
        return unit(units, at: index + 2) == Unit.closeBracket && unit(units, at: index + 3) == Unit.space
    }

    private static func parseOrdered(_ units: [UInt16], indent: Int) -> BlockMarker? {
        var end = indent
        while end < units.count, Unit.isDigit(units[end]) {
            end += 1
        }
        // No real list reaches ten digits; the cap keeps `number + 1` safe.
        guard end > indent, end - indent <= 9 else { return nil }
        guard let punctuation = unit(units, at: end),
              punctuation == Unit.dot || punctuation == Unit.closeParen else { return nil }
        guard unit(units, at: end + 1) == Unit.space else { return nil }
        var number = 0
        for index in indent..<end {
            number = number * 10 + Int(units[index] - Unit.digitZero)
        }
        return BlockMarker(
            indentEnd: indent,
            kind: .ordered(number: number, punctuation: punctuation),
            markerEnd: end + 2
        )
    }

    // MARK: Primitives

    private static func unit(_ units: [UInt16], at index: Int) -> UInt16? {
        index >= 0 && index < units.count ? units[index] : nil
    }

    private static func isWhitespace(_ unit: UInt16) -> Bool {
        unit == Unit.space || unit == Unit.tab
    }
}

private enum Unit {
    static let asterisk: UInt16 = 0x2A
    static let closeBracket: UInt16 = 0x5D
    static let closeParen: UInt16 = 0x29
    static let digitNine: UInt16 = 0x39
    static let digitZero: UInt16 = 0x30
    static let dot: UInt16 = 0x2E
    static let greaterThan: UInt16 = 0x3E
    static let hyphen: UInt16 = 0x2D
    static let lowerX: UInt16 = 0x78
    static let openBracket: UInt16 = 0x5B
    static let plus: UInt16 = 0x2B
    static let space: UInt16 = 0x20
    static let tab: UInt16 = 0x09
    static let upperX: UInt16 = 0x58

    static func isDigit(_ unit: UInt16) -> Bool {
        unit >= digitZero && unit <= digitNine
    }
}
