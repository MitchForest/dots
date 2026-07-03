/// Focus-mode ranges: the paragraph around an offset. Offsets and ranges
/// are UTF-16 code units. Pure and deliberately simple — a boundary
/// heuristic, not a linguistic model.
public enum FocusRanges {
    /// The paragraph around `offset`: the run of consecutive non-blank lines
    /// containing it, from the start of the first line to the end of the last
    /// (excluding its trailing newline). A blank line (empty or
    /// whitespace-only) is its own — empty-content — paragraph.
    public static func paragraph(around offset: Int, in text: String) -> Range<Int> {
        let units = Array(text.utf16)
        let clamped = min(max(offset, 0), units.count)
        let line = lineRange(units, containing: clamped)
        if isBlank(units, line) { return line }
        var start = line.lowerBound
        while start > 0 {
            let previous = lineRange(units, containing: start - 1)
            if isBlank(units, previous) { break }
            start = previous.lowerBound
        }
        var end = line.upperBound
        while end < units.count {
            let next = lineRange(units, containing: end + 1)
            if isBlank(units, next) { break }
            end = next.upperBound
        }
        return start..<end
    }

    /// The line containing `offset`, excluding its trailing newline. An
    /// offset sitting on a newline belongs to the line that newline ends.
    private static func lineRange(_ units: [UInt16], containing offset: Int) -> Range<Int> {
        var start = offset
        while start > 0, units[start - 1] != Unit.newline {
            start -= 1
        }
        var end = offset
        while end < units.count, units[end] != Unit.newline {
            end += 1
        }
        return start..<end
    }

    private static func isBlank(_ units: [UInt16], _ line: Range<Int>) -> Bool {
        units[line].allSatisfy { $0 == Unit.space || $0 == Unit.tab }
    }
}

private enum Unit {
    static let newline: UInt16 = 0x0A
    static let space: UInt16 = 0x20
    static let tab: UInt16 = 0x09
}
