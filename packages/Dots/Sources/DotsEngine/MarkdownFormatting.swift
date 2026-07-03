/// Pure markdown format commands: every command maps (text, selection) →
/// (text, selection). Selections are UTF-16 code-unit offsets (NSTextView's
/// currency). Commands never normalize anything they don't touch.

public enum MarkdownFormatting {
    public struct Result: Equatable, Sendable {
        public let selection: Range<Int>
        public let text: String

        public init(text: String, selection: Range<Int>) {
            self.selection = selection
            self.text = text
        }
    }

    public enum InlineStyle: Equatable, Sendable {
        case bold           // **
        case code           // `
        case italic         // *
        case strikethrough  // ~~
    }

    public enum LineStyle: Equatable, Sendable {
        case bullet          // "- "
        case heading(Int)    // 1...3 → "# ", "## ", "### "
        case ordered         // "1. ", "2. ", …
        case quote           // "> "
    }

    /// Wraps, unwraps, or extends the inline delimiters around `selection`.
    public static func toggle(_ style: InlineStyle, in text: String, selection: Range<Int>) -> Result {
        InlineToggle(text: text, selection: selection, style: style).run()
    }

    /// Sets or clears the line prefix on every line intersecting `selection`.
    public static func toggle(_ style: LineStyle, in text: String, selection: Range<Int>) -> Result {
        LineToggle(text: text, selection: selection, style: style).run()
    }

    /// Replaces the selection with `[selection](url)` (or inserts `[](url)` at
    /// a caret) and selects the `url` placeholder so typing replaces it.
    public static func insertLink(in text: String, selection: Range<Int>) -> Result {
        let units = Array(text.utf16)
        let bounds = clamped(selection, count: units.count)
        let placeholder = Array("url".utf16)
        var result = Array(units[..<bounds.lowerBound])
        result.append(Unit.openBracket)
        result.append(contentsOf: units[bounds])
        result.append(Unit.closeBracket)
        result.append(Unit.openParen)
        let urlStart = result.count
        result.append(contentsOf: placeholder)
        result.append(Unit.closeParen)
        result.append(contentsOf: units[bounds.upperBound...])
        return Result(
            text: String(decoding: result, as: UTF16.self),
            selection: urlStart..<(urlStart + placeholder.count)
        )
    }

    /// Clamps a selection to the valid offsets of a text of `count` code units.
    static func clamped(_ selection: Range<Int>, count: Int) -> Range<Int> {
        let lower = min(max(selection.lowerBound, 0), count)
        let upper = min(max(selection.upperBound, lower), count)
        return lower..<upper
    }
}

private enum Unit {
    static let asterisk: UInt16 = 0x2A
    static let backtick: UInt16 = 0x60
    static let closeBracket: UInt16 = 0x5D
    static let closeParen: UInt16 = 0x29
    static let digitNine: UInt16 = 0x39
    static let digitZero: UInt16 = 0x30
    static let dot: UInt16 = 0x2E
    static let greaterThan: UInt16 = 0x3E
    static let hash: UInt16 = 0x23
    static let hyphen: UInt16 = 0x2D
    static let newline: UInt16 = 0x0A
    static let openBracket: UInt16 = 0x5B
    static let openParen: UInt16 = 0x28
    static let plus: UInt16 = 0x2B
    static let space: UInt16 = 0x20
    static let tab: UInt16 = 0x09
    static let tilde: UInt16 = 0x7E

    static func isDigit(_ unit: UInt16) -> Bool {
        unit >= digitZero && unit <= digitNine
    }
}

// MARK: - Inline styles

private struct InlineToggle {
    private let units: [UInt16]
    private let delimiter: [UInt16]
    private let isItalic: Bool
    private let lower: Int
    private let upper: Int

    init(text: String, selection: Range<Int>, style: MarkdownFormatting.InlineStyle) {
        self.units = Array(text.utf16)
        switch style {
        case .bold: self.delimiter = [Unit.asterisk, Unit.asterisk]
        case .code: self.delimiter = [Unit.backtick]
        case .italic: self.delimiter = [Unit.asterisk]
        case .strikethrough: self.delimiter = [Unit.tilde, Unit.tilde]
        }
        self.isItalic = style == .italic
        let bounds = MarkdownFormatting.clamped(selection, count: units.count)
        self.lower = bounds.lowerBound
        self.upper = bounds.upperBound
    }

    func run() -> MarkdownFormatting.Result {
        if selectionIncludesDelimiters { return unwrapInside() }
        if surroundedByDelimiters { return unwrapSurrounding() }
        return wrap()
    }

    // MARK: Unwrap — the selection itself carries the delimiters

    private var selectionIncludesDelimiters: Bool {
        let width = delimiter.count
        guard upper - lower >= 2 * width else { return false }
        guard matches(delimiter, at: lower), matches(delimiter, at: upper - width) else { return false }
        guard isItalic else { return true }
        // A run of exactly two asterisks is a bold marker: a single-star
        // command wraps additionally (→ ***…***) instead of splitting it.
        return asteriskRun(forwardFrom: lower) != 2 && asteriskRun(backwardTo: upper) != 2
    }

    private func unwrapInside() -> MarkdownFormatting.Result {
        let width = delimiter.count
        var result = Array(units[..<lower])
        result.append(contentsOf: units[(lower + width)..<(upper - width)])
        result.append(contentsOf: units[upper...])
        return makeResult(result, selection: lower..<(upper - 2 * width))
    }

    // MARK: Unwrap — the delimiters surround the selection

    private var surroundedByDelimiters: Bool {
        let width = delimiter.count
        guard lower >= width, upper + width <= units.count else { return false }
        guard matches(delimiter, at: lower - width), matches(delimiter, at: upper) else { return false }
        guard isItalic else { return true }
        // Never strip half of a `**` bold marker with a single-star command.
        return asteriskRun(backwardTo: lower) != 2 && asteriskRun(forwardFrom: upper) != 2
    }

    private func unwrapSurrounding() -> MarkdownFormatting.Result {
        let width = delimiter.count
        var result = Array(units[..<(lower - width)])
        result.append(contentsOf: units[lower..<upper])
        result.append(contentsOf: units[(upper + width)...])
        return makeResult(result, selection: (lower - width)..<(upper - width))
    }

    // MARK: Wrap

    private func wrap() -> MarkdownFormatting.Result {
        var result = Array(units[..<lower])
        result.append(contentsOf: delimiter)
        result.append(contentsOf: units[lower..<upper])
        result.append(contentsOf: delimiter)
        result.append(contentsOf: units[upper...])
        return makeResult(result, selection: (lower + delimiter.count)..<(upper + delimiter.count))
    }

    // MARK: Primitives

    private func matches(_ pattern: [UInt16], at index: Int) -> Bool {
        index >= 0
            && index + pattern.count <= units.count
            && units[index..<(index + pattern.count)].elementsEqual(pattern)
    }

    private func asteriskRun(forwardFrom index: Int) -> Int {
        var length = 0
        while index + length < units.count, units[index + length] == Unit.asterisk {
            length += 1
        }
        return length
    }

    private func asteriskRun(backwardTo index: Int) -> Int {
        var length = 0
        while index - length - 1 >= 0, units[index - length - 1] == Unit.asterisk {
            length += 1
        }
        return length
    }

    private func makeResult(_ result: [UInt16], selection: Range<Int>) -> MarkdownFormatting.Result {
        MarkdownFormatting.Result(text: String(decoding: result, as: UTF16.self), selection: selection)
    }
}

// MARK: - Line styles

private struct LineToggle {
    private let units: [UInt16]
    private let style: MarkdownFormatting.LineStyle
    private let blockStart: Int
    private let blockEnd: Int
    private let lines: [ParsedLine]

    init(text: String, selection: Range<Int>, style: MarkdownFormatting.LineStyle) {
        let units = Array(text.utf16)
        self.units = units
        self.style = style
        let bounds = MarkdownFormatting.clamped(selection, count: units.count)

        var start = bounds.lowerBound
        while start > 0, units[start - 1] != Unit.newline {
            start -= 1
        }

        // A non-empty selection ending exactly at a line start excludes that
        // trailing line; a caret always counts as its own line.
        var last = bounds.upperBound
        if bounds.lowerBound < bounds.upperBound, units[last - 1] == Unit.newline {
            last -= 1
        }
        var end = last
        while end < units.count, units[end] != Unit.newline {
            end += 1
        }

        self.blockStart = start
        self.blockEnd = end
        var lines: [ParsedLine] = []
        var lineStart = start
        for index in start..<end where units[index] == Unit.newline {
            lines.append(ParsedLine(Array(units[lineStart..<index])))
            lineStart = index + 1
        }
        lines.append(ParsedLine(Array(units[lineStart..<end])))
        self.lines = lines
    }

    func run() -> MarkdownFormatting.Result {
        var block: [UInt16] = []
        for (index, line) in transformedLines().enumerated() {
            if index > 0 { block.append(Unit.newline) }
            block.append(contentsOf: line)
        }
        var result = Array(units[..<blockStart])
        result.append(contentsOf: block)
        result.append(contentsOf: units[blockEnd...])
        return MarkdownFormatting.Result(
            text: String(decoding: result, as: UTF16.self),
            selection: blockStart..<(blockStart + block.count)
        )
    }

    private func transformedLines() -> [[UInt16]] {
        switch style {
        case .bullet: return toggleBullets()
        case .heading(let level): return toggleHeadings(level: level)
        case .ordered: return toggleOrdered()
        case .quote: return toggleQuotes()
        }
    }

    /// The toggle decision follows the first line: if it already has the
    /// level-`level` prefix, remove it from every line that has it; otherwise
    /// set level `level` on every line (replacing other heading levels).
    private func toggleHeadings(level: Int) -> [[UInt16]] {
        let clampedLevel = min(max(level, 1), 3)
        let prefix = Array(repeating: Unit.hash, count: clampedLevel) + [Unit.space]
        let removing = lines[0].headingLevel == clampedLevel
        return lines.map { line in
            if removing {
                return line.headingLevel == clampedLevel ? line.removingMarker() : line.units
            }
            if line.headingLevel == clampedLevel { return line.units }
            if line.headingLevel != nil { return line.replacingMarker(with: prefix) }
            return line.insertingPrefix(prefix)
        }
    }

    private func toggleQuotes() -> [[UInt16]] {
        let removing = allContentLines(are: \.isQuote)
        let prefix: [UInt16] = [Unit.greaterThan, Unit.space]
        return lines.map { line in
            if removing { return line.isQuote ? line.removingMarker() : line.units }
            return line.isBlank ? line.units : line.insertingPrefix(prefix)
        }
    }

    private func toggleBullets() -> [[UInt16]] {
        let removing = allContentLines(are: \.isBullet)
        let prefix: [UInt16] = [Unit.hyphen, Unit.space]
        return lines.map { line in
            if removing { return line.isBullet ? line.removingMarker() : line.units }
            if line.isBlank || line.isBullet { return line.units }
            if line.isOrdered { return line.replacingMarker(with: prefix) }
            return line.insertingPrefix(prefix)
        }
    }

    private func toggleOrdered() -> [[UInt16]] {
        if allContentLines(are: \.isOrdered) {
            return lines.map { $0.isOrdered ? $0.removingMarker() : $0.units }
        }
        var number = 0
        return lines.map { line in
            if line.isBlank { return line.units }
            number += 1
            let prefix = Array("\(number). ".utf16)
            if line.isOrdered || line.isBullet { return line.replacingMarker(with: prefix) }
            return line.insertingPrefix(prefix)
        }
    }

    /// True when every non-blank target line satisfies `predicate` and there
    /// is at least one non-blank line to decide by.
    private func allContentLines(are predicate: (ParsedLine) -> Bool) -> Bool {
        let content = lines.filter { !$0.isBlank }
        return !content.isEmpty && content.allSatisfy(predicate)
    }
}

private enum LineMarker: Equatable {
    case bullet(length: Int)
    case heading(level: Int, length: Int)
    case ordered(length: Int)
    case quote(length: Int)

    var length: Int {
        switch self {
        case .bullet(let length): return length
        case .heading(_, let length): return length
        case .ordered(let length): return length
        case .quote(let length): return length
        }
    }
}

private struct ParsedLine {
    let indent: Int
    let marker: LineMarker?
    let units: [UInt16]

    init(_ units: [UInt16]) {
        self.units = units
        var indent = 0
        while indent < min(3, units.count), units[indent] == Unit.space {
            indent += 1
        }
        self.indent = indent
        self.marker = Self.parseMarker(units, at: indent)
    }

    var isBlank: Bool {
        units.allSatisfy { $0 == Unit.space || $0 == Unit.tab }
    }

    var headingLevel: Int? {
        if case .heading(let level, _) = marker { return level }
        return nil
    }

    var isBullet: Bool {
        if case .bullet = marker { return true }
        return false
    }

    var isOrdered: Bool {
        if case .ordered = marker { return true }
        return false
    }

    var isQuote: Bool {
        if case .quote = marker { return true }
        return false
    }

    func removingMarker() -> [UInt16] {
        guard let marker else { return units }
        return Array(units[..<indent]) + Array(units[(indent + marker.length)...])
    }

    func replacingMarker(with prefix: [UInt16]) -> [UInt16] {
        let length = marker?.length ?? 0
        return Array(units[..<indent]) + prefix + Array(units[(indent + length)...])
    }

    func insertingPrefix(_ prefix: [UInt16]) -> [UInt16] {
        Array(units[..<indent]) + prefix + Array(units[indent...])
    }

    private static func parseMarker(_ units: [UInt16], at index: Int) -> LineMarker? {
        guard index < units.count else { return nil }
        switch units[index] {
        case Unit.hash:
            var end = index
            while end < units.count, units[end] == Unit.hash, end - index < 6 {
                end += 1
            }
            guard end < units.count, units[end] == Unit.space else { return nil }
            return .heading(level: end - index, length: end - index + 1)
        case Unit.greaterThan:
            let hasSpace = index + 1 < units.count && units[index + 1] == Unit.space
            return .quote(length: hasSpace ? 2 : 1)
        case Unit.hyphen, Unit.asterisk, Unit.plus:
            guard index + 1 < units.count, units[index + 1] == Unit.space else { return nil }
            return .bullet(length: 2)
        default:
            guard Unit.isDigit(units[index]) else { return nil }
            var end = index
            while end < units.count, Unit.isDigit(units[end]) {
                end += 1
            }
            guard end < units.count, units[end] == Unit.dot || units[end] == Unit.closeParen else { return nil }
            guard end + 1 < units.count, units[end + 1] == Unit.space else { return nil }
            return .ordered(length: end - index + 2)
        }
    }
}
