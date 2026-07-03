import DotsDomain
import DotsEngine
import Foundation
import Testing

@Suite("DotFile")
struct DotFileTests {
    private let capturedAt = Date(timeIntervalSince1970: 1_782_034_200)

    @Test("Render emits the target.md idea schema")
    func renderSchema() {
        let dot = Dot(
            id: Dot.ID("01J0KQJ8ZR"),
            content: "The idea content itself.",
            capturedAt: Date(timeIntervalSince1970: 0),
            source: DotSource(kind: .quote, url: URL(string: "https://example.com/a"), ref: Source.ID("01J1SRC")),
            references: [Reference("01J0AAAA"), Reference("01J0BBBB")],
            tags: ["reading", "focus"]
        )

        let expected = """
        ---
        id: 01J0KQJ8ZR
        captured_at: 1970-01-01T00:00:00Z
        source:
          kind: quote
          url: https://example.com/a
          ref: 01J1SRC
        references: [01J0AAAA, 01J0BBBB]
        tags: [reading, focus]
        ---
        The idea content itself.
        """
        #expect(DotFile.render(dot) == expected)
    }

    @Test("Round-trips an extraction, emoji body included")
    func roundTripExtraction() {
        let dot = Dot(
            id: Dot.ID("01J0KQJ8ZR3M"),
            content: "Thoughts ✨ on 🧠 attention.\n\nSecond paragraph.",
            capturedAt: capturedAt,
            source: DotSource(kind: .quote, url: URL(string: "https://example.com/essay"), ref: Source.ID("01J1SRC")),
            references: [Reference("01J0AAAA")],
            tags: ["reading", "focus"]
        )

        #expect(DotFile.parse(DotFile.render(dot)) == dot)
    }

    @Test("Round-trips an authored idea with no source and empty lists")
    func roundTripAuthored() {
        let dot = Dot(
            id: Dot.ID("01J0MINIMAL"),
            content: "Just a thought.",
            capturedAt: capturedAt
        )

        let rendered = DotFile.render(dot)
        #expect(!rendered.contains("source:"))
        #expect(rendered.contains("references: []"))
        #expect(rendered.contains("tags: []"))
        let parsed = DotFile.parse(rendered)
        #expect(parsed == dot)
        #expect(parsed?.isExtraction == false)
    }

    @Test("Round-trips synthesis references to multiple ideas")
    func roundTripSynthesis() {
        let dot = Dot(
            id: Dot.ID("01J0SYNTH"),
            content: "A higher-level insight.",
            capturedAt: capturedAt,
            references: [Reference("01J0AAAA"), Reference("01J0BBBB")]
        )

        #expect(DotFile.parse(DotFile.render(dot)) == dot)
    }

    @Test("Round-trips an empty body and a body with a leading blank line")
    func roundTripBodyEdges() {
        let empty = Dot(id: Dot.ID("01J0EMPTY"), content: "", capturedAt: capturedAt)
        #expect(DotFile.parse(DotFile.render(empty)) == empty)

        let leading = Dot(id: Dot.ID("01J0LEADING"), content: "\nStarts after a blank line.", capturedAt: capturedAt)
        #expect(DotFile.parse(DotFile.render(leading)) == leading)
    }

    @Test("Legacy links and parents merge into references")
    func legacyLinksAndParents() {
        let contents = """
        ---
        id: 01J0LEGACY
        captured_at: 2026-07-01T09:30:00Z
        parents: [01J0PARENT]
        tags: [one]
        links: [01J0LINKED]
        ---
        Old idea.
        """

        let dot = DotFile.parse(contents)
        #expect(dot?.references == [Reference("01J0PARENT"), Reference("01J0LINKED")])
        #expect(dot?.source == nil)
        #expect(dot?.tags == ["one"])
    }

    @Test("Legacy distilled origin moves the source ref into references")
    func legacyDistilledMapsToReference() {
        let contents = """
        ---
        id: 01J0DISTILL
        origin: distilled
        source:
          kind: text
          url: https://example.com/essay
          ref: 01J1SRC
        tags: []
        links: []
        ---
        My own words about their idea.
        """

        let dot = DotFile.parse(contents)
        #expect(dot?.source == nil)
        #expect(dot?.isExtraction == false)
        #expect(dot?.references == [Reference("01J1SRC")])
    }

    @Test("Legacy verbatim origin stays an extraction")
    func legacyVerbatimStaysExtraction() {
        let contents = """
        ---
        id: 01J0VERB
        origin: verbatim
        source:
          kind: quote
          ref: 01J1SRC
        ---
        Their exact words.
        """

        let dot = DotFile.parse(contents)
        #expect(dot?.isExtraction == true)
        #expect(dot?.source == DotSource(kind: .quote, ref: Source.ID("01J1SRC")))
        #expect(dot?.references.isEmpty == true)
    }

    @Test("Unknown keys are skipped, top-level and inside source")
    func unknownKeysTolerated() {
        let contents = """
        ---
        id: 01J0UNKNOWN
        captured_at: 2026-07-01T09:30:00Z
        mystery: value
        source:
          kind: url
          flavor: grape
        tags: [one]
        future_list: [a, b]
        references: []
        ---
        Body.
        """

        let dot = DotFile.parse(contents)
        #expect(dot?.id == Dot.ID("01J0UNKNOWN"))
        #expect(dot?.source == DotSource(kind: .url))
        #expect(dot?.tags == ["one"])
        #expect(dot?.content == "Body.")
    }

    @Test("Missing optional fields fall back to defaults")
    func missingOptionalFields() {
        let dot = DotFile.parse("---\nid: 01J0SPARSE\n---\nBody only.")

        #expect(dot?.id == Dot.ID("01J0SPARSE"))
        #expect(dot?.capturedAt == Date(timeIntervalSince1970: 0))
        #expect(dot?.source == nil)
        #expect(dot?.references.isEmpty == true)
        #expect(dot?.tags.isEmpty == true)
        #expect(dot?.content == "Body only.")
    }

    @Test("Returns nil without frontmatter, without an id, or with an unclosed fence")
    func parseRejections() {
        #expect(DotFile.parse("just prose, no frontmatter") == nil)
        #expect(DotFile.parse("") == nil)
        #expect(DotFile.parse("---\ncaptured_at: 2026-07-01T09:30:00Z\n---\nno id") == nil)
        #expect(DotFile.parse("---\nid: 01J0OPEN\nnever closed") == nil)
    }

    @Test("A horizontal rule in the body does not confuse the parser")
    func bodyRuleUntouched() {
        let dot = Dot(id: Dot.ID("01J0RULE"), content: "Above.\n---\nBelow.", capturedAt: capturedAt)

        #expect(DotFile.parse(DotFile.render(dot)) == dot)
    }
}

@Suite("DotPreview")
struct DotPreviewTests {
    @Test("Title is the first non-empty line, markdown lead stripped")
    func titleFromFirstLine() {
        #expect(DotPreview.title("# Attention is scarce\n\nMore text.") == "Attention is scarce")
        #expect(DotPreview.title("\n\n> quoted thought\nrest") == "quoted thought")
        #expect(DotPreview.title("- a list item first") == "a list item first")
        #expect(DotPreview.title("plain thought") == "plain thought")
        #expect(DotPreview.title("   \n\n") == "New idea")
    }

    @Test("Snippet is the next non-empty line after the title")
    func snippetFollowsTitle() {
        #expect(DotPreview.snippet("Title line\n\nSecond thought here.") == "Second thought here.")
        #expect(DotPreview.snippet("Only one line").isEmpty)
        #expect(DotPreview.snippet("# Title\n> quoted body") == "quoted body")
    }
}
