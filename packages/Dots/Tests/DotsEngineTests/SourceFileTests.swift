import DotsDomain
import DotsEngine
import Foundation
import Testing

@Suite("SourceFile")
struct SourceFileTests {
    private let capturedAt = Date(timeIntervalSince1970: 1_782_034_200)

    @Test("Render emits the target.md source schema")
    func renderSchema() {
        let source = Source(
            id: Source.ID("01J1ABCDEF"),
            title: "The Article Title",
            content: "The full extracted text.",
            capturedAt: Date(timeIntervalSince1970: 0),
            url: URL(string: "https://example.com/post"),
            author: "Jane Doe",
            site: "example.com"
        )

        let expected = """
        ---
        id: 01J1ABCDEF
        title: The Article Title
        url: https://example.com/post
        author: Jane Doe
        site: example.com
        captured_at: 1970-01-01T00:00:00Z
        ---
        The full extracted text.
        """
        #expect(SourceFile.render(source) == expected)
    }

    @Test("Round-trips a fully populated source, emoji body included")
    func roundTripFull() {
        let source = Source(
            id: Source.ID("01J1FULL"),
            title: "Deep Work, Revisited",
            content: "Full text ✨ with paragraphs.\n\nSecond paragraph.",
            capturedAt: capturedAt,
            url: URL(string: "https://example.com/essay"),
            author: "Jane Doe",
            site: "example.com"
        )

        #expect(SourceFile.parse(SourceFile.render(source)) == source)
    }

    @Test("Round-trips without url, author, or site")
    func roundTripMinimal() {
        let source = Source(
            id: Source.ID("01J1MINIMAL"),
            title: "Pasted Text",
            content: "Just the text.",
            capturedAt: capturedAt
        )

        let rendered = SourceFile.render(source)
        #expect(!rendered.contains("url:"))
        #expect(!rendered.contains("author:"))
        #expect(!rendered.contains("site:"))
        #expect(SourceFile.parse(rendered) == source)
    }

    @Test("Missing or empty title falls back to Untitled")
    func titleDefault() {
        let absent = SourceFile.parse("---\nid: 01J1NOTITLE\n---\nBody.")
        #expect(absent?.title == "Untitled")

        let empty = SourceFile.parse("---\nid: 01J1EMPTYTITLE\ntitle:\n---\nBody.")
        #expect(empty?.title == "Untitled")
    }

    @Test("Missing optional fields fall back to defaults")
    func missingOptionalFields() {
        let source = SourceFile.parse("---\nid: 01J1SPARSE\n---\nBody only.")

        #expect(source?.id == Source.ID("01J1SPARSE"))
        #expect(source?.capturedAt == Date(timeIntervalSince1970: 0))
        #expect(source?.url == nil)
        #expect(source?.author == nil)
        #expect(source?.site == nil)
        #expect(source?.content == "Body only.")
    }

    @Test("Returns nil without frontmatter, without an id, or with an unclosed fence")
    func parseRejections() {
        #expect(SourceFile.parse("just prose, no frontmatter") == nil)
        #expect(SourceFile.parse("") == nil)
        #expect(SourceFile.parse("---\ntitle: No ID\n---\nbody") == nil)
        #expect(SourceFile.parse("---\nid: 01J1OPEN\nnever closed") == nil)
    }

    @Test("Parses fractional-seconds timestamps")
    func fractionalSecondsDate() throws {
        let whole = try #require(SourceFile.parse("---\nid: 01J1WHOLE\ncaptured_at: 2026-07-01T09:30:00Z\n---\n"))
        let fractional = try #require(SourceFile.parse("---\nid: 01J1FRACT\ncaptured_at: 2026-07-01T09:30:00.500Z\n---\n"))

        let delta = fractional.capturedAt.timeIntervalSince(whole.capturedAt)
        #expect(abs(delta - 0.5) < 0.001)
    }
}
