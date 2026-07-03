/// Editor-side markdown line scanner: produces styled overlay spans for the markdown
/// syntax visible on a single line (headings, emphasis, inline code, links, list and
/// blockquote markers). Ranges are UTF-16 code-unit offsets within the line, matching
/// what `NSAttributedString` expects.

public struct MarkdownSpan: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case blockquoteMarker
        case codeFenceMarker
        case codeSpan
        case emphasis
        case heading(level: Int)
        case linkText
        case linkURL
        case listMarker
        case strikethrough
        case strong
        case syntax
    }

    public let kind: Kind
    public let range: Range<Int>

    public init(kind: Kind, range: Range<Int>) {
        self.kind = kind
        self.range = range
    }
}

public enum MarkdownLineStyler {
    /// Spans for one line. `inCodeFence` = the line sits inside an open ``` block
    /// (caller tracks fence state across lines); fence-interior lines get no spans
    /// (rendered as code by the caller).
    public static func spans(forLine line: String, inCodeFence: Bool) -> [MarkdownSpan] {
        if inCodeFence { return [] }
        var scanner = LineScanner(line: line)
        return scanner.scan()
    }
}

private enum Unit {
    static let asterisk: UInt16 = 0x2A
    static let backtick: UInt16 = 0x60
    static let closeBracket: UInt16 = 0x5D
    static let closeParen: UInt16 = 0x29
    static let greaterThan: UInt16 = 0x3E
    static let hash: UInt16 = 0x23
    static let hyphen: UInt16 = 0x2D
    static let openBracket: UInt16 = 0x5B
    static let openParen: UInt16 = 0x28
    static let plus: UInt16 = 0x2B
    static let space: UInt16 = 0x20
    static let tab: UInt16 = 0x09
    static let tilde: UInt16 = 0x7E
    static let underscore: UInt16 = 0x5F
    static let digitZero: UInt16 = 0x30
    static let digitNine: UInt16 = 0x39
}

private struct LineScanner {
    private let units: [UInt16]
    private var spans: [MarkdownSpan] = []

    init(line: String) {
        self.units = Array(line.utf16)
    }

    mutating func scan() -> [MarkdownSpan] {
        if isCodeFenceLine() {
            append(.codeFenceMarker, range: 0..<units.count)
            return spans
        }
        appendPrefixSpans()
        appendInlineSpans()
        return spans
    }

    // MARK: - Line prefixes

    private func isCodeFenceLine() -> Bool {
        var index = 0
        while index < units.count, units[index] == Unit.space || units[index] == Unit.tab {
            index += 1
        }
        return index + 2 < units.count
            && units[index] == Unit.backtick
            && units[index + 1] == Unit.backtick
            && units[index + 2] == Unit.backtick
    }

    private mutating func appendPrefixSpans() {
        let prefixIndex = indentationPrefixLength()
        guard prefixIndex < units.count else { return }

        let unit = units[prefixIndex]
        if appendHeading(at: prefixIndex, unit: unit) { return }
        if appendBlockquoteMarker(at: prefixIndex, unit: unit) { return }
        if appendUnorderedListMarker(at: prefixIndex, unit: unit) { return }
        appendOrderedListMarker(at: prefixIndex, unit: unit)
    }

    private func indentationPrefixLength() -> Int {
        var prefixIndex = 0
        while prefixIndex < units.count,
              prefixIndex < 3,
              units[prefixIndex] == Unit.space {
            prefixIndex += 1
        }
        return prefixIndex
    }

    private mutating func appendHeading(at prefixIndex: Int, unit: UInt16) -> Bool {
        guard unit == Unit.hash else { return false }

        var markerEnd = prefixIndex
        while markerEnd < units.count,
              units[markerEnd] == Unit.hash,
              markerEnd - prefixIndex < 6 {
            markerEnd += 1
        }

        guard markerEnd < units.count, units[markerEnd] == Unit.space else { return false }

        append(.syntax, range: prefixIndex..<(markerEnd + 1))
        append(.heading(level: markerEnd - prefixIndex), range: (markerEnd + 1)..<units.count)
        return true
    }

    private mutating func appendBlockquoteMarker(at prefixIndex: Int, unit: UInt16) -> Bool {
        guard unit == Unit.greaterThan else { return false }

        var markerEnd = prefixIndex + 1
        if markerEnd < units.count, units[markerEnd] == Unit.space {
            markerEnd += 1
        }
        append(.blockquoteMarker, range: prefixIndex..<markerEnd)
        return true
    }

    private mutating func appendUnorderedListMarker(at prefixIndex: Int, unit: UInt16) -> Bool {
        guard unit == Unit.hyphen || unit == Unit.plus || unit == Unit.asterisk else { return false }
        guard prefixIndex + 1 < units.count, units[prefixIndex + 1] == Unit.space else { return false }

        append(.listMarker, range: prefixIndex..<(prefixIndex + 2))
        return true
    }

    private mutating func appendOrderedListMarker(at prefixIndex: Int, unit: UInt16) {
        guard isDigit(unit) else { return }

        var numberEnd = prefixIndex
        while numberEnd < units.count, isDigit(units[numberEnd]) {
            numberEnd += 1
        }

        guard numberEnd < units.count else { return }
        let marker = units[numberEnd]
        guard marker == 0x2E || marker == Unit.closeParen else { return }
        guard numberEnd + 1 < units.count, units[numberEnd + 1] == Unit.space else { return }

        append(.listMarker, range: prefixIndex..<(numberEnd + 2))
    }

    // MARK: - Inline runs

    private mutating func appendInlineSpans() {
        var index = 0
        while index < units.count {
            switch units[index] {
            case Unit.backtick:
                index = consumeCodeSpan(at: index)
            case Unit.openBracket:
                index = consumeLink(at: index)
            case Unit.asterisk, Unit.underscore:
                index = consumeEmphasis(at: index)
            case Unit.tilde:
                index = consumeStrikethrough(at: index)
            default:
                index += 1
            }
        }
    }

    private mutating func consumeCodeSpan(at start: Int) -> Int {
        let delimiterLength = runLength(of: Unit.backtick, at: start)
        guard let closingStart = matchingRunStart(
            of: Unit.backtick,
            length: delimiterLength,
            from: start + delimiterLength
        ) else {
            return start + delimiterLength
        }

        append(.syntax, range: start..<(start + delimiterLength))
        append(.codeSpan, range: (start + delimiterLength)..<closingStart)
        append(.syntax, range: closingStart..<(closingStart + delimiterLength))
        return closingStart + delimiterLength
    }

    private mutating func consumeStrikethrough(at start: Int) -> Int {
        let delimiterLength = runLength(of: Unit.tilde, at: start)
        guard delimiterLength == 2 else { return start + delimiterLength }
        let contentStart = start + delimiterLength
        guard contentStart < units.count, units[contentStart] != Unit.space,
              let closingStart = matchingRunStart(
                  of: Unit.tilde,
                  length: delimiterLength,
                  from: contentStart
              ),
              units[closingStart - 1] != Unit.space
        else { return contentStart }

        append(.syntax, range: start..<contentStart)
        append(.strikethrough, range: contentStart..<closingStart)
        append(.syntax, range: closingStart..<(closingStart + delimiterLength))
        return closingStart + delimiterLength
    }

    private mutating func consumeLink(at start: Int) -> Int {
        guard let closeBracket = firstIndex(of: Unit.closeBracket, from: start + 1),
              closeBracket + 1 < units.count,
              units[closeBracket + 1] == Unit.openParen,
              let closeParen = firstIndex(of: Unit.closeParen, from: closeBracket + 2) else {
            return start + 1
        }

        append(.syntax, range: start..<(start + 1))
        append(.linkText, range: (start + 1)..<closeBracket)
        append(.syntax, range: closeBracket..<(closeBracket + 2))
        append(.linkURL, range: (closeBracket + 2)..<closeParen)
        append(.syntax, range: closeParen..<(closeParen + 1))
        return closeParen + 1
    }

    private mutating func consumeEmphasis(at start: Int) -> Int {
        let unit = units[start]
        let delimiterLength = runLength(of: unit, at: start)
        let contentStart = start + delimiterLength

        guard canOpenEmphasis(unit: unit, runStart: start, contentStart: contentStart),
              let closingStart = emphasisClosingStart(of: unit, length: delimiterLength, from: contentStart) else {
            return contentStart
        }

        let kind: MarkdownSpan.Kind = delimiterLength >= 2 ? .strong : .emphasis
        append(.syntax, range: start..<contentStart)
        append(kind, range: contentStart..<closingStart)
        append(.syntax, range: closingStart..<(closingStart + delimiterLength))
        return closingStart + delimiterLength
    }

    private func canOpenEmphasis(unit: UInt16, runStart: Int, contentStart: Int) -> Bool {
        guard contentStart < units.count, units[contentStart] != Unit.space else { return false }
        if unit == Unit.underscore, runStart > 0, isASCIIAlphanumeric(units[runStart - 1]) {
            return false
        }
        return true
    }

    private func emphasisClosingStart(of unit: UInt16, length: Int, from startIndex: Int) -> Int? {
        var searchIndex = startIndex
        while searchIndex < units.count {
            guard units[searchIndex] == unit else {
                searchIndex += 1
                continue
            }

            let candidateLength = runLength(of: unit, at: searchIndex)
            if candidateLength == length, canCloseEmphasis(unit: unit, runStart: searchIndex, runEnd: searchIndex + candidateLength) {
                return searchIndex
            }
            searchIndex += max(candidateLength, 1)
        }
        return nil
    }

    private func canCloseEmphasis(unit: UInt16, runStart: Int, runEnd: Int) -> Bool {
        guard runStart > 0, units[runStart - 1] != Unit.space else { return false }
        if unit == Unit.underscore, runEnd < units.count, isASCIIAlphanumeric(units[runEnd]) {
            return false
        }
        return true
    }

    // MARK: - Scanning primitives

    private func runLength(of unit: UInt16, at index: Int) -> Int {
        var count = 0
        while index + count < units.count, units[index + count] == unit {
            count += 1
        }
        return count
    }

    private func matchingRunStart(of unit: UInt16, length: Int, from startIndex: Int) -> Int? {
        var searchIndex = startIndex
        while searchIndex < units.count {
            guard units[searchIndex] == unit else {
                searchIndex += 1
                continue
            }

            let candidateLength = runLength(of: unit, at: searchIndex)
            if candidateLength == length {
                return searchIndex
            }
            searchIndex += max(candidateLength, 1)
        }
        return nil
    }

    private func firstIndex(of unit: UInt16, from startIndex: Int) -> Int? {
        var index = startIndex
        while index < units.count {
            if units[index] == unit { return index }
            index += 1
        }
        return nil
    }

    private func isDigit(_ unit: UInt16) -> Bool {
        unit >= Unit.digitZero && unit <= Unit.digitNine
    }

    private func isASCIIAlphanumeric(_ unit: UInt16) -> Bool {
        isDigit(unit) || (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A)
    }

    private mutating func append(_ kind: MarkdownSpan.Kind, range: Range<Int>) {
        guard range.lowerBound < range.upperBound else { return }
        spans.append(MarkdownSpan(kind: kind, range: range))
    }
}
