import DotsEngine
import Testing

@Suite("MarkdownLineStyler")
struct MarkdownLineStylerTests {
    @Test("Plain prose yields no spans")
    func plainProseYieldsNoSpans() {
        #expect(MarkdownLineStyler.spans(forLine: "just some ordinary words.", inCodeFence: false).isEmpty)
    }

    @Test("Heading emits dimmed marker and heading text")
    func headingEmitsMarkerAndText() {
        let spans = MarkdownLineStyler.spans(forLine: "## Title", inCodeFence: false)
        #expect(spans == [
            MarkdownSpan(kind: .syntax, range: 0..<3),
            MarkdownSpan(kind: .heading(level: 2), range: 3..<8)
        ])
    }

    @Test("Hashes without a following space are not a heading")
    func hashesWithoutSpaceAreNotHeading() {
        #expect(MarkdownLineStyler.spans(forLine: "#hashtag", inCodeFence: false).isEmpty)
    }

    @Test("Strikethrough emits delimiters and struck content")
    func strikethroughSpans() {
        let spans = MarkdownLineStyler.spans(forLine: "keep ~~cut this~~ words", inCodeFence: false)
        #expect(spans == [
            MarkdownSpan(kind: .syntax, range: 5..<7),
            MarkdownSpan(kind: .strikethrough, range: 7..<15),
            MarkdownSpan(kind: .syntax, range: 15..<17)
        ])
    }

    @Test("Single tilde and unclosed double tilde stay plain")
    func tildeNonMatches() {
        #expect(MarkdownLineStyler.spans(forLine: "approx ~5 items", inCodeFence: false).isEmpty)
        #expect(MarkdownLineStyler.spans(forLine: "open ~~never closed", inCodeFence: false).isEmpty)
    }

    @Test("Bullet marker span covers marker and space")
    func bulletMarkerSpan() {
        let spans = MarkdownLineStyler.spans(forLine: "- item", inCodeFence: false)
        #expect(spans == [MarkdownSpan(kind: .listMarker, range: 0..<2)])
    }

    @Test("Indented bullet still gets a marker span")
    func indentedBulletMarkerSpan() {
        let spans = MarkdownLineStyler.spans(forLine: "  - nested", inCodeFence: false)
        #expect(spans == [MarkdownSpan(kind: .listMarker, range: 2..<4)])
    }

    @Test("Ordered list marker covers digits, dot, and space")
    func orderedListMarkerSpan() {
        let spans = MarkdownLineStyler.spans(forLine: "12. twelfth", inCodeFence: false)
        #expect(spans == [MarkdownSpan(kind: .listMarker, range: 0..<4)])
    }

    @Test("Blockquote marker covers the angle and its space")
    func blockquoteMarkerSpan() {
        let spans = MarkdownLineStyler.spans(forLine: "> quoted", inCodeFence: false)
        #expect(spans == [MarkdownSpan(kind: .blockquoteMarker, range: 0..<2)])
    }

    @Test("Strong emphasis dims delimiters and marks content")
    func strongEmphasisSpans() {
        let spans = MarkdownLineStyler.spans(forLine: "a **bold** c", inCodeFence: false)
        #expect(spans == [
            MarkdownSpan(kind: .syntax, range: 2..<4),
            MarkdownSpan(kind: .strong, range: 4..<8),
            MarkdownSpan(kind: .syntax, range: 8..<10)
        ])
    }

    @Test("Single-asterisk emphasis spans")
    func emphasisSpans() {
        let spans = MarkdownLineStyler.spans(forLine: "an *italic* word", inCodeFence: false)
        #expect(spans == [
            MarkdownSpan(kind: .syntax, range: 3..<4),
            MarkdownSpan(kind: .emphasis, range: 4..<10),
            MarkdownSpan(kind: .syntax, range: 10..<11)
        ])
    }

    @Test("Underscore strong emphasis spans")
    func underscoreStrongSpans() {
        let spans = MarkdownLineStyler.spans(forLine: "__bold__", inCodeFence: false)
        #expect(spans == [
            MarkdownSpan(kind: .syntax, range: 0..<2),
            MarkdownSpan(kind: .strong, range: 2..<6),
            MarkdownSpan(kind: .syntax, range: 6..<8)
        ])
    }

    @Test("Underscores inside identifiers are left alone")
    func intraWordUnderscoresIgnored() {
        #expect(MarkdownLineStyler.spans(forLine: "use snake_case_names here", inCodeFence: false).isEmpty)
    }

    @Test("Lone asterisks surrounded by spaces are not emphasis")
    func spacedAsterisksAreNotEmphasis() {
        #expect(MarkdownLineStyler.spans(forLine: "2 * 3 * 4", inCodeFence: false).isEmpty)
    }

    @Test("Inline code dims backticks and marks the code span")
    func inlineCodeSpans() {
        let spans = MarkdownLineStyler.spans(forLine: "use `let` here", inCodeFence: false)
        #expect(spans == [
            MarkdownSpan(kind: .syntax, range: 4..<5),
            MarkdownSpan(kind: .codeSpan, range: 5..<8),
            MarkdownSpan(kind: .syntax, range: 8..<9)
        ])
    }

    @Test("Double-backtick delimiters match only equal-length runs")
    func doubleBacktickDelimiters() {
        let spans = MarkdownLineStyler.spans(forLine: "``a`b``", inCodeFence: false)
        #expect(spans == [
            MarkdownSpan(kind: .syntax, range: 0..<2),
            MarkdownSpan(kind: .codeSpan, range: 2..<5),
            MarkdownSpan(kind: .syntax, range: 5..<7)
        ])
    }

    @Test("Emphasis markers inside code spans are not styled")
    func emphasisInsideCodeSpanIgnored() {
        let spans = MarkdownLineStyler.spans(forLine: "`a *b* c`", inCodeFence: false)
        #expect(spans == [
            MarkdownSpan(kind: .syntax, range: 0..<1),
            MarkdownSpan(kind: .codeSpan, range: 1..<8),
            MarkdownSpan(kind: .syntax, range: 8..<9)
        ])
    }

    @Test("Links split into text, URL, and dimmed punctuation")
    func linkSpans() {
        let spans = MarkdownLineStyler.spans(forLine: "[text](url)", inCodeFence: false)
        #expect(spans == [
            MarkdownSpan(kind: .syntax, range: 0..<1),
            MarkdownSpan(kind: .linkText, range: 1..<5),
            MarkdownSpan(kind: .syntax, range: 5..<7),
            MarkdownSpan(kind: .linkURL, range: 7..<10),
            MarkdownSpan(kind: .syntax, range: 10..<11)
        ])
    }

    @Test("A fence line is one marker span over the whole line")
    func fenceLineSpans() {
        let spans = MarkdownLineStyler.spans(forLine: "```swift", inCodeFence: false)
        #expect(spans == [MarkdownSpan(kind: .codeFenceMarker, range: 0..<8)])
    }

    @Test("Lines inside an open fence get no spans")
    func insideFenceReturnsEmpty() {
        #expect(MarkdownLineStyler.spans(forLine: "# not a heading", inCodeFence: true).isEmpty)
        #expect(MarkdownLineStyler.spans(forLine: "**not bold**", inCodeFence: true).isEmpty)
    }

    @Test("Ranges are UTF-16 offsets when the line contains emoji")
    func utf16OffsetsWithEmoji() {
        // The emoji occupies two UTF-16 code units, shifting everything after it by 2.
        let spans = MarkdownLineStyler.spans(forLine: "🙂 **b**", inCodeFence: false)
        #expect(spans == [
            MarkdownSpan(kind: .syntax, range: 3..<5),
            MarkdownSpan(kind: .strong, range: 5..<6),
            MarkdownSpan(kind: .syntax, range: 6..<8)
        ])
    }

    @Test("Heading text still gets inline spans")
    func headingWithInlineBold() {
        let spans = MarkdownLineStyler.spans(forLine: "# Hi **b**", inCodeFence: false)
        #expect(spans.contains(MarkdownSpan(kind: .heading(level: 1), range: 2..<10)))
        #expect(spans.contains(MarkdownSpan(kind: .strong, range: 7..<8)))
    }

    @Test("List item content keeps emphasis spans")
    func listItemWithEmphasis() {
        let spans = MarkdownLineStyler.spans(forLine: "- *soft*", inCodeFence: false)
        #expect(spans == [
            MarkdownSpan(kind: .listMarker, range: 0..<2),
            MarkdownSpan(kind: .syntax, range: 2..<3),
            MarkdownSpan(kind: .emphasis, range: 3..<7),
            MarkdownSpan(kind: .syntax, range: 7..<8)
        ])
    }
}
