import ComposableArchitecture2
import Dependencies
import DependenciesTestSupport
import DotsClients
import DotsDomain
import DotsEngine
import DotsFeatures
import Foundation
import Testing

private nonisolated let vaultURL = URL(filePath: "/mock/vault", directoryHint: .isDirectory)
private nonisolated let seededDot = Dot(
    id: Dot.ID("seed-1"),
    content: "We read to collect dots.",
    capturedAt: Date(timeIntervalSince1970: 100)
)
private nonisolated let otherDot = Dot(
    id: Dot.ID("seed-2"),
    content: "We write to connect them.",
    capturedAt: Date(timeIntervalSince1970: 200)
)
private nonisolated let seededSource = Source(
    id: Source.ID("src-1"),
    title: "An Essay",
    content: "The full text of the essay.",
    capturedAt: Date(timeIntervalSince1970: 300),
    url: URL(string: "https://example.com/essay"),
    folder: "ai"
)

@MainActor
@Suite("Ideas")
struct IdeasTests {
    /// Drains the mount chain: dots → arrangement → sources → folders.
    /// Empty loads change nothing, so their receives assert no changes.
    private func receiveMountChain(
        _ store: TestStore<Ideas>,
        dots: [Dot] = [],
        sources: [Source] = [],
        folders: [String] = [],
        proposals: [IdeaProposal] = []
    ) async {
        if dots.isEmpty {
            await store.receive(\.dotsLoaded)
        } else {
            await store.receive(\.dotsLoaded) {
                $0.dots = dots
            }
        }
        await store.receive(\.arrangementLoaded)
        if sources.isEmpty {
            await store.receive(\.sourcesLoaded)
        } else {
            await store.receive(\.sourcesLoaded) {
                $0.sources = sources
            }
        }
        if folders.isEmpty {
            await store.receive(\.foldersLoaded)
        } else {
            await store.receive(\.foldersLoaded) {
                $0.folders = folders
            }
        }
        if proposals.isEmpty {
            await store.receive(\.proposalsLoaded)
        } else {
            await store.receive(\.proposalsLoaded) {
                $0.proposals = proposals
            }
        }
    }

    @Test(
        "Mount loads ideas, arrangement, sources, and folders",
        .dependencies {
            $0.vaultClient = .inMemory(
                location: vaultURL,
                dots: [seededDot],
                sources: [seededSource],
                folders: ["ai", "travel"]
            )
        }
    )
    func mountLoads() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }

        await receiveMountChain(
            store,
            dots: [seededDot],
            sources: [seededSource],
            folders: ["ai", "travel"]
        )
        await store.dismount()
    }

    @Test(
        "Shift-range selection deletes as one gesture",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL, dots: [seededDot, otherDot])
        }
    )
    func rangeSelectThenDeleteAll() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store, dots: [seededDot, otherDot])

        store.send(.dotTapped(seededDot.id, modifier: .none)) {
            $0.selection = [seededDot.id]
        }
        store.send(.dotTapped(otherDot.id, modifier: .range)) {
            $0.selection = [seededDot.id, otherDot.id]
        }
        let task = store.send(.deleteSelectionTapped) {
            $0.dots = []
            $0.selection = []
        }
        await task?.value
        await store.dismount()
    }

    @Test("Folder selection filters ideas and sources")
    func folderFiltering() {
        let filed = Dot(
            id: Dot.ID("filed-1"),
            content: "Filed thought.",
            capturedAt: Date(timeIntervalSince1970: 150),
            folder: "ai"
        )
        var state = Ideas.State(vault: vaultURL)
        state.dots = [seededDot, filed]
        state.sources = [seededSource]

        #expect(state.visibleDots.count == 2)
        state.folderSelection = .folder("ai")
        #expect(state.visibleDots == [filed])
        #expect(state.visibleSources == [seededSource])
        state.folderSelection = .inbox
        #expect(state.visibleDots == [seededDot])
        #expect(state.visibleSources.isEmpty)
    }

    @Test(
        "Connect records references on the anchor and persists",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL, dots: [seededDot, otherDot])
        }
    )
    func connectSelection() async {
        var state = Ideas.State(vault: vaultURL)
        state.selection = [seededDot.id, otherDot.id]
        let store = TestStore(initialState: state) {
            Ideas()
        }
        await receiveMountChain(store, dots: [seededDot, otherDot])

        let task = store.send(.connectSelectionTapped) {
            var anchor = seededDot
            anchor.references = [Reference(otherDot.id)]
            $0.dots = [anchor, otherDot]
        }
        await task?.value
        #expect(store.state.isSelectionFullyConnected)
        await store.dismount()
    }

    @Test(
        "Disconnect removes references among the selection pairwise",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL, dots: {
                var anchor = seededDot
                anchor.references = [Reference(otherDot.id)]
                return [anchor, otherDot]
            }())
        }
    )
    func disconnectSelection() async {
        var state = Ideas.State(vault: vaultURL)
        state.selection = [seededDot.id, otherDot.id]
        let store = TestStore(initialState: state) {
            Ideas()
        }
        var anchor = seededDot
        anchor.references = [Reference(otherDot.id)]
        await receiveMountChain(store, dots: [anchor, otherDot])

        #expect(store.state.isSelectionFullyConnected)

        let task = store.send(.disconnectSelectionTapped) {
            $0.dots = [seededDot, otherDot]
        }
        await task?.value
        #expect(!store.state.isSelectionFullyConnected)
        await store.dismount()
    }

    @Test(
        "Editing updates content and tags",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL, dots: [seededDot])
        }
    )
    func editUpdatesContentAndTags() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store, dots: [seededDot])

        let task = store.send(.dotEdited(seededDot.id, content: "Rewritten.", tags: ["reading"])) {
            var edited = seededDot
            edited.content = "Rewritten."
            edited.tags = ["reading"]
            $0.dots = [edited]
        }
        await task?.value
        await store.dismount()
    }

    @Test(
        "Synthesis births a child referencing its parents, above their centroid",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL, dots: [seededDot, otherDot])
        }
    )
    func synthesizeSelection() async {
        var state = Ideas.State(vault: vaultURL)
        state.selection = [seededDot.id, otherDot.id]
        let store = TestStore(initialState: state) {
            Ideas()
        }
        await receiveMountChain(store, dots: [seededDot, otherDot])

        // Pin both parents so the child's landing point is known.
        var task = store.send(.dotDragEnded(seededDot.id, CGPoint(x: 100, y: 300))) {
            $0.arrangement.positions[seededDot.id.rawValue] = CanvasArrangement.Position(x: 100, y: 300)
        }
        await task?.value
        task = store.send(.dotDragEnded(otherDot.id, CGPoint(x: 300, y: 300))) {
            $0.arrangement.positions[otherDot.id.rawValue] = CanvasArrangement.Position(x: 300, y: 300)
        }
        await task?.value

        store.send(.synthesizeSelectionTapped)
        // The in-memory vault mints ids from the dot count: two seeds → -002.
        let child = Dot(
            id: Dot.ID("mockdot-002"),
            content: "New insight",
            capturedAt: Date(timeIntervalSince1970: 2),
            references: [Reference(seededDot.id), Reference(otherDot.id)]
        )
        await store.receive(\.dotCreated) {
            $0.dots = [child, seededDot, otherDot]
            $0.arrangement.positions[child.id.rawValue] = CanvasArrangement.Position(x: 200, y: 100)
            $0.freshDotID = child.id
            $0.selection = [child.id]
        }
        #expect(store.state.backlinks(of: seededDot.id) == [child])
        await store.dismount()
    }

    @Test(
        "Creating a folder selects it; moving an idea refiles it",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL, dots: [seededDot])
        }
    )
    func foldersAndMoves() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store, dots: [seededDot])

        var task = store.send(.createFolderSubmitted("  travel ")) {
            $0.folders = ["travel"]
            $0.folderSelection = .folder("travel")
        }
        await task?.value

        task = store.send(.dotMoved(seededDot.id, folder: "travel")) {
            var moved = seededDot
            moved.folder = "travel"
            $0.dots = [moved]
        }
        await task?.value
        #expect(store.state.visibleDots.count == 1)
        await store.dismount()
    }
}
