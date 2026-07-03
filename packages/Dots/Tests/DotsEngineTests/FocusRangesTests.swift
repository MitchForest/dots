import DotsEngine
import Testing

@Suite("FocusRanges")
struct FocusRangesTests {
    // Line offsets: "alpha one" 0..<9, "alpha two" 10..<19, blank 20..<20,
    // "beta one" 21..<29, "   " 30..<33, "gamma" 34..<39.
    private let blocks = "alpha one\nalpha two\n\nbeta one\n   \ngamma"

    @Test("A multi-line block spans all its lines from either line")
    func multiLineBlock() {
        #expect(FocusRanges.paragraph(around: 3, in: blocks) == 0..<19)
        #expect(FocusRanges.paragraph(around: 12, in: blocks) == 0..<19)
    }

    @Test("A single-line block between blank lines is just that line")
    func singleLineBlockBetweenBlanks() {
        #expect(FocusRanges.paragraph(around: 25, in: blocks) == 21..<29)
    }

    @Test("An offset on a blank line returns that blank line's range")
    func offsetOnBlankLine() {
        #expect(FocusRanges.paragraph(around: 20, in: blocks) == 20..<20)
        // A whitespace-only line is blank too.
        #expect(FocusRanges.paragraph(around: 31, in: blocks) == 30..<33)
    }

    @Test("Blocks at the document edges are bounded by the text")
    func documentEdges() {
        #expect(FocusRanges.paragraph(around: 0, in: blocks) == 0..<19)
        #expect(FocusRanges.paragraph(around: 36, in: blocks) == 34..<39)
        #expect(FocusRanges.paragraph(around: 39, in: blocks) == 34..<39)
    }

    @Test("A single-line document is one paragraph")
    func singleLineDocument() {
        #expect(FocusRanges.paragraph(around: 2, in: "hello") == 0..<5)
    }

    @Test("The trailing newline of the last line is excluded")
    func trailingNewlineExcluded() {
        #expect(FocusRanges.paragraph(around: 1, in: "ab\n") == 0..<2)
    }

    @Test("An offset on a newline belongs to the line it ends")
    func offsetOnNewline() {
        // "ab" and "cd" are consecutive non-blank lines: one paragraph.
        #expect(FocusRanges.paragraph(around: 2, in: "ab\ncd") == 0..<5)
    }

    @Test("Empty text yields an empty paragraph")
    func emptyTextParagraph() {
        #expect(FocusRanges.paragraph(around: 0, in: "") == 0..<0)
    }

    @Test("Out-of-bounds offsets are clamped")
    func paragraphOffsetIsClamped() {
        #expect(FocusRanges.paragraph(around: 999, in: blocks) == 34..<39)
        #expect(FocusRanges.paragraph(around: -1, in: blocks) == 0..<19)
    }
}
