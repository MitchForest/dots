import DotsEngine
import Testing

@Suite("TextMetrics")
struct TextMetricsTests {
    @Test("Empty text has zero words")
    func emptyTextHasZeroWords() {
        #expect(TextMetrics.wordCount(in: "") == 0)
    }

    @Test("Words split across whitespace and newlines")
    func wordsSplitAcrossWhitespaceAndNewlines() {
        #expect(TextMetrics.wordCount(in: "we read to collect dots\nwe write to connect them") == 10)
    }

    @Test("Markdown syntax does not count as words")
    func markdownSyntaxDoesNotCount() {
        #expect(TextMetrics.wordCount(in: "> a quote") == 2)
        #expect(TextMetrics.wordCount(in: "# Heading") == 1)
        #expect(TextMetrics.wordCount(in: "- item\n---\n* next") == 2)
        #expect(TextMetrics.wordCount(in: "**bold** text [link](https://example.com/page)") == 3)
        #expect(TextMetrics.wordCount(in: "```\ncode here\n```") == 2)
    }
}
