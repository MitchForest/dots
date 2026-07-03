import DotsDomain
import DotsEngine
import Foundation
import Testing

private nonisolated func draft(_ title: String, _ content: String) -> (document: VaultDocument, content: String) {
    (
        VaultDocument(
            url: URL(filePath: "/vault/drafts/\(title).md"),
            title: title,
            modifiedAt: Date(timeIntervalSince1970: 0)
        ),
        content
    )
}

private nonisolated func idea(_ id: String, _ content: String) -> Dot {
    Dot(id: Dot.ID(id), content: content, capturedAt: Date(timeIntervalSince1970: 0))
}

private nonisolated func source(_ id: String, _ title: String, _ content: String) -> Source {
    Source(id: Source.ID(id), title: title, content: content, capturedAt: Date(timeIntervalSince1970: 0))
}

@Suite("VaultSearch")
struct VaultSearchTests {
    @Test("Title matches outrank content matches; prefix beats substring")
    func titleBeatsContent() {
        let hits = VaultSearch.rank(
            query: "focus",
            drafts: [
                draft("Deep work", "Attention and focus are the same muscle."),
                draft("Focus is a practice", "Morning pages."),
                draft("On unfocus", "Rest matters.")
            ],
            dots: [],
            sources: []
        )

        #expect(hits.map(\.title) == ["Focus is a practice", "On unfocus", "Deep work"])
    }

    @Test("All three kinds match; an idea leading with the query outranks content-only hits; drafts beat sources on ties")
    func allKindsMatch() {
        let hits = VaultSearch.rank(
            query: "meetings",
            drafts: [draft("Untitled", "Why meetings sprawl.")],
            dots: [idea("i1", "Meetings cost makers half a day.")],
            sources: [source("s1", "Maker's Schedule", "Meetings are a disaster for makers.")]
        )

        #expect(hits.count == 3)
        // The idea's first line IS its title, and it starts with the query.
        if case .idea = hits[0] {} else { Issue.record("expected the idea first") }
        if case .draft = hits[1] {} else { Issue.record("expected the draft to beat the source on the tie") }
        if case .source = hits[2] {} else { Issue.record("expected the source last") }
    }

    @Test("The snippet is the matched line, trimmed around a long hit")
    func snippetShowsTheMatch() {
        let long = "Line one.\n" + String(repeating: "pad ", count: 60) + "the needle sits here" + String(repeating: " pad", count: 30)
        let hits = VaultSearch.rank(query: "needle", drafts: [draft("A", long)], dots: [], sources: [])

        #expect(hits.count == 1)
        #expect(hits[0].snippet.localizedCaseInsensitiveContains("needle"))
        #expect(hits[0].snippet.count <= 130)
    }

    @Test("Case and diacritics don't matter; no match means no hit; results cap")
    func matchingRules() {
        #expect(VaultSearch.rank(
            query: "CAFÉ",
            drafts: [draft("Notes", "the cafe on the corner")],
            dots: [],
            sources: []
        ).count == 1)

        #expect(VaultSearch.rank(query: "zebra", drafts: [draft("A", "nothing here")], dots: [], sources: []).isEmpty)

        let many = (0..<40).map { idea("i\($0)", "repetition repetition") }
        #expect(VaultSearch.rank(query: "repetition", drafts: [], dots: many, sources: []).count == VaultSearch.maxHits)
    }

    @Test("A title-only match falls back to the first content line as snippet")
    func titleOnlySnippet() {
        let hits = VaultSearch.rank(
            query: "schedule",
            drafts: [draft("Maker's Schedule", "Programmers hate meetings.\nMore text.")],
            dots: [],
            sources: []
        )

        #expect(hits.count == 1)
        #expect(hits[0].snippet == "Programmers hate meetings.")
    }
}
