import DotsEngine
import Foundation
import Testing

private struct FixedGenerator: RandomNumberGenerator {
    var value: UInt64

    mutating func next() -> UInt64 { value }
}

@Suite("ULID")
struct ULIDTests {
    @Test("Deterministic inputs produce a deterministic 26-char id")
    func deterministic() {
        var generator = FixedGenerator(value: 0)
        let id = ULID.generate(timestamp: Date(timeIntervalSince1970: 0), using: &generator)

        #expect(id == "00000000000000000000000000")
        #expect(id.count == 26)
    }

    @Test("Later timestamps sort after earlier ones")
    func sortable() {
        var generator = FixedGenerator(value: 31)
        let earlier = ULID.generate(timestamp: Date(timeIntervalSince1970: 1), using: &generator)
        let later = ULID.generate(timestamp: Date(timeIntervalSince1970: 2), using: &generator)

        #expect(earlier < later)
    }
}

@Suite("Greeting")
struct GreetingTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test("Hours map to the right greeting")
    func hoursMap() {
        #expect(Greeting.text(at: Date(timeIntervalSince1970: 8 * 3600), calendar: utc) == "Good morning")
        #expect(Greeting.text(at: Date(timeIntervalSince1970: 13 * 3600), calendar: utc) == "Good afternoon")
        #expect(Greeting.text(at: Date(timeIntervalSince1970: 19 * 3600), calendar: utc) == "Good evening")
        #expect(Greeting.text(at: Date(timeIntervalSince1970: 2 * 3600), calendar: utc) == "Late night thoughts")
    }
}

@Suite("DraftTemplate")
struct DraftTemplateTests {
    @Test("Render emits the target.md frontmatter schema")
    func renderSchema() {
        let rendered = DraftTemplate.render(
            id: "01ABC",
            title: "Why we write",
            createdAt: Date(timeIntervalSince1970: 0)
        )

        #expect(rendered.hasPrefix("---\nid: 01ABC\ntitle: Why we write\ncreated_at: 1970-01-01T00:00:00Z\n"))
        #expect(rendered.contains("ideas: []"))
    }

    @Test("Slugs collapse non-alphanumerics")
    func slugs() {
        #expect(DraftTemplate.slug(fromTitle: "Why We Write!") == "why-we-write")
        #expect(DraftTemplate.slug(fromTitle: "  ").isEmpty)
    }
}

@Suite("DocumentTitle")
struct DocumentTitleTests {
    @Test("Frontmatter title wins")
    func frontmatterTitle() {
        let contents = "---\nid: 1\ntitle: The Real Title\n---\n# Heading"
        #expect(DocumentTitle.parse(contents) == "The Real Title")
    }

    @Test("Falls back to first heading")
    func headingFallback() {
        #expect(DocumentTitle.parse("\n# From Heading\nbody") == "From Heading")
    }

    @Test("Nil when no title exists")
    func nilWhenAbsent() {
        #expect(DocumentTitle.parse("just prose") == nil)
    }
}
