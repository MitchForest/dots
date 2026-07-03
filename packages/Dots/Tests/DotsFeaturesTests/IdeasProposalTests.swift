import ComposableArchitecture2
import Dependencies
import DependenciesTestSupport
import DotsClients
import DotsDomain
import DotsFeatures
import Foundation
import Testing

private nonisolated let vaultURL = URL(filePath: "/mock/vault", directoryHint: .isDirectory)

private nonisolated let article = Source(
    id: Source.ID("src-1"),
    title: "Maker's Schedule",
    content: "Meetings cost makers half a day.",
    capturedAt: Date(timeIntervalSince1970: 100),
    url: URL(string: "https://example.com/makers"),
    folder: "essays"
)

private nonisolated let proposal = IdeaProposal(
    id: IdeaProposal.ID("prop-1"),
    sourceId: article.id,
    ideas: [
        ProposedIdea(id: 1, text: "Attention is scarce."),
        ProposedIdea(id: 2, text: "Calendars misprice it.")
    ],
    createdAt: Date(timeIntervalSince1970: 150)
)

@MainActor
@Suite("IdeasProposals")
struct IdeasProposalTests {
    private func receiveMountChain(_ store: TestStore<Ideas>) async {
        await store.receive(\.dotsLoaded)
        await store.receive(\.arrangementLoaded)
        await store.receive(\.sourcesLoaded) {
            $0.sources = [article]
        }
        await store.receive(\.foldersLoaded) {
            $0.folders = ["essays"]
        }
        await store.receive(\.proposalsLoaded) {
            $0.proposals = [proposal]
        }
    }

    @Test(
        "Pending drafted ideas surface in the list, scoped to the source's folder",
        .dependencies {
            $0.vaultClient = .inMemory(
                location: vaultURL,
                sources: [article],
                folders: ["essays"],
                proposals: [proposal]
            )
        }
    )
    func pendingIdeasSurface() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store)

        #expect(store.state.visiblePendingIdeas.map(\.idea.text) == [
            "Attention is scarce.",
            "Calendars misprice it."
        ])
        #expect(store.state.visiblePendingIdeas.allSatisfy { $0.source == article })

        await store.modify {
            $0.folderSelection = .folder("essays")
        }
        #expect(store.state.visiblePendingIdeas.count == 2)

        await store.modify {
            $0.folderSelection = .inbox
        }
        #expect(store.state.visiblePendingIdeas.isEmpty)
        await store.dismount()
    }

    @Test(
        "Tapping a pending row focuses it for the detail pane; a dot tap or its own verdict releases it",
        .dependencies {
            $0.vaultClient = .inMemory(
                location: vaultURL,
                sources: [article],
                folders: ["essays"],
                proposals: [proposal]
            )
        }
    )
    func tappingFocusesPendingIdea() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store)

        store.send(.pendingIdeaTapped("prop-1-1", modifier: .none)) {
            $0.pendingSelection = ["prop-1-1"]
        }
        #expect(store.state.focusedPendingIdea?.idea.text == "Attention is scarce.")

        store.send(.dotTapped(Dot.ID("nonexistent"), modifier: .none)) {
            $0.pendingSelection = []
            $0.selection = [Dot.ID("nonexistent")]
        }
        #expect(store.state.focusedPendingIdea == nil)

        store.send(.pendingIdeaTapped("prop-1-2", modifier: .none)) {
            $0.pendingSelection = ["prop-1-2"]
            $0.selection = []
        }
        store.send(.proposedIdeaDiscarded(proposal.id, 2)) {
            var reviewed = proposal
            reviewed.ideas[1].status = .discarded
            $0.pendingSelection = []
            $0.proposals = [reviewed]
        }
        await store.dismount()
    }

    @Test(
        "Shift extends the pending selection; one gesture reviews them all",
        .dependencies {
            $0.vaultClient = .inMemory(
                location: vaultURL,
                sources: [article],
                folders: ["essays"],
                proposals: [proposal]
            )
        }
    )
    func rangeSelectAndBulkAccept() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store)

        store.send(.pendingIdeaTapped("prop-1-1", modifier: .none)) {
            $0.pendingSelection = ["prop-1-1"]
        }
        store.send(.pendingIdeaTapped("prop-1-2", modifier: .range)) {
            $0.pendingSelection = ["prop-1-1", "prop-1-2"]
        }

        store.send(.pendingSelectionAccepted) {
            var reviewed = proposal
            reviewed.ideas[0].status = .accepted
            reviewed.ideas[1].status = .accepted
            reviewed.status = .applied
            $0.pendingSelection = []
            $0.proposals = [reviewed]
        }
        await store.receive(\.dotCaptured, timeout: .seconds(2)) {
            $0.dots = [
                Dot(
                    id: Dot.ID("mockdot-000"),
                    content: "Attention is scarce.",
                    capturedAt: Date(timeIntervalSince1970: 0),
                    source: DotSource(kind: .text, url: article.url, ref: article.id),
                    folder: "essays"
                )
            ]
        }
        await store.receive(\.dotCaptured, timeout: .seconds(2)) {
            $0.dots = [
                Dot(
                    id: Dot.ID("mockdot-001"),
                    content: "Calendars misprice it.",
                    capturedAt: Date(timeIntervalSince1970: 1),
                    source: DotSource(kind: .text, url: article.url, ref: article.id),
                    folder: "essays"
                ),
                Dot(
                    id: Dot.ID("mockdot-000"),
                    content: "Attention is scarce.",
                    capturedAt: Date(timeIntervalSince1970: 0),
                    source: DotSource(kind: .text, url: article.url, ref: article.id),
                    folder: "essays"
                )
            ]
        }
        #expect(store.state.visiblePendingIdeas.isEmpty)
        await store.dismount()
    }

    @Test("Shift-click composes a contiguous range over the visible order")
    func rangeGrammar() {
        let order = ["a", "b", "c", "d", "e"]
        #expect(Ideas.composedSelection(tapped: "d", modifier: .range, current: ["b"], order: order) == ["b", "c", "d"])
        #expect(Ideas.composedSelection(tapped: "a", modifier: .range, current: ["c"], order: order) == ["a", "b", "c"].reversed())
        #expect(Ideas.composedSelection(tapped: "d", modifier: .range, current: [], order: order) == ["d"])
        #expect(Ideas.composedSelection(tapped: "b", modifier: .toggle, current: ["a"], order: order) == ["a", "b"])
        #expect(Ideas.composedSelection(tapped: "a", modifier: .toggle, current: ["a", "b"], order: order) == ["b"])
        #expect(Ideas.composedSelection(tapped: "c", modifier: .none, current: ["a", "b"], order: order) == ["c"])
    }

    @Test(
        "Accepting mints an extraction idea in the source's folder; discarding just records — the reviewed proposal closes",
        .dependencies {
            $0.vaultClient = .inMemory(
                location: vaultURL,
                sources: [article],
                folders: ["essays"],
                proposals: [proposal]
            )
        }
    )
    func acceptAndDiscard() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store)

        store.send(.proposedIdeaAccepted(proposal.id, 1)) {
            var reviewed = proposal
            reviewed.ideas[0].status = .accepted
            $0.proposals = [reviewed]
        }
        await store.receive(\.dotCaptured) {
            $0.dots = [
                Dot(
                    id: Dot.ID("mockdot-000"),
                    content: "Attention is scarce.",
                    capturedAt: Date(timeIntervalSince1970: 0),
                    source: DotSource(
                        kind: .text,
                        url: article.url,
                        ref: article.id
                    ),
                    folder: "essays"
                )
            ]
        }
        #expect(store.state.visiblePendingIdeas.map(\.idea.text) == ["Calendars misprice it."])

        let task = store.send(.proposedIdeaDiscarded(proposal.id, 2)) {
            var reviewed = proposal
            reviewed.ideas[0].status = .accepted
            reviewed.ideas[1].status = .discarded
            reviewed.status = .applied
            $0.proposals = [reviewed]
        }
        await task?.value
        #expect(store.state.visiblePendingIdeas.isEmpty)
        #expect(store.state.dots.count == 1)
        await store.dismount()
    }
}
