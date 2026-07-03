import DotsDomain
import DotsEngine
import Testing

@Suite("DraftIdeas")
struct DraftIdeasTests {
    private let draft = """
    ---
    id: 01ABC
    title: Why we write
    ideas: [01AAA, 01BBB]
    ---

    Body text stays untouched.
    """

    @Test("Reads the ideas list, including the legacy dots key")
    func readsIDs() {
        #expect(DraftIdeas.ids(in: draft) == [Dot.ID("01AAA"), Dot.ID("01BBB")])
        #expect(DraftIdeas.ids(in: "---\nid: x\ndots: [01OLD]\n---\nBody") == [Dot.ID("01OLD")])
        #expect(DraftIdeas.ids(in: "no frontmatter").isEmpty)
        #expect(DraftIdeas.ids(in: "---\nid: x\n---\nBody").isEmpty)
    }

    @Test("Adding appends once and never touches the body")
    func adding() {
        let added = DraftIdeas.adding(Dot.ID("01CCC"), to: draft)
        #expect(DraftIdeas.ids(in: added) == [Dot.ID("01AAA"), Dot.ID("01BBB"), Dot.ID("01CCC")])
        #expect(added.contains("Body text stays untouched."))
        #expect(DraftIdeas.adding(Dot.ID("01AAA"), to: draft) == draft)
    }

    @Test("Adding to a draft without an ideas line inserts one before the fence")
    func addingInsertsLine() {
        let bare = "---\nid: 01ABC\ntitle: T\n---\nBody"
        let added = DraftIdeas.adding(Dot.ID("01AAA"), to: bare)
        #expect(DraftIdeas.ids(in: added) == [Dot.ID("01AAA")])
        #expect(added.contains("title: T"))
        #expect(added.hasSuffix("---\nBody"))
    }

    @Test("Adding rewrites a legacy dots line as ideas")
    func addingMigratesLegacyKey() {
        let legacy = "---\nid: x\ndots: [01OLD]\n---\nBody"
        let added = DraftIdeas.adding(Dot.ID("01NEW"), to: legacy)
        #expect(added.contains("ideas: [01OLD, 01NEW]"))
        #expect(!added.contains("dots: ["))
    }

    @Test("Removing deletes the id and tolerates absent ids")
    func removing() {
        let removed = DraftIdeas.removing(Dot.ID("01AAA"), from: draft)
        #expect(DraftIdeas.ids(in: removed) == [Dot.ID("01BBB")])
        #expect(DraftIdeas.removing(Dot.ID("01ZZZ"), from: draft) == draft)
    }
}
