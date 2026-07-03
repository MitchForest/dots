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

private nonisolated let secondSource = Source(
    id: Source.ID("src-2"),
    title: "Another Essay",
    content: "More full text.",
    capturedAt: Date(timeIntervalSince1970: 250)
)

@MainActor
@Suite("IdeasCapture")
struct IdeasCaptureTests {
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
        "Pasted text becomes a saved source in the current folder and opens the reader",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL)
        }
    )
    func pastedTextCapture() async {
        var state = Ideas.State(vault: vaultURL)
        state.folderSelection = .folder("ai")
        let store = TestStore(initialState: state) {
            Ideas()
        }
        await receiveMountChain(store)

        store.send(.sourceTextSubmitted(title: "  Essay  ", text: "Full text.\n")) {
            $0.isCapturingSource = true
        }
        let captured = Source(
            id: Source.ID("mocksource-000"),
            title: "Essay",
            content: "Full text.",
            capturedAt: Date(timeIntervalSince1970: 0),
            folder: "ai"
        )
        await store.receive(\.sourceCaptured) {
            $0.isCapturingSource = false
            $0.sources = [captured]
            $0.tab = .sources
            $0.openSourceID = captured.id
        }
        await store.dismount()
    }

    @Test(
        "Empty pasted text and junk URLs are rejected without a save",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL)
        }
    )
    func captureRejections() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store)

        store.send(.sourceTextSubmitted(title: "Essay", text: "   \n")) {
            $0.captureError = "Nothing to save — paste the text first."
        }
        store.send(.sourceURLSubmitted("not a link")) {
            $0.captureError = "That doesn't look like a link."
        }
        await store.dismount()
    }

    @Test(
        "Extracting a selection captures an extraction anchored to the source",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL, sources: [seededSource])
        }
    )
    func extractSelection() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store, sources: [seededSource])

        store.send(.extractSelectionTapped(seededSource, excerpt: "  Their exact words.  "))
        await store.receive(\.dotCaptured) {
            $0.dots = [
                Dot(
                    id: Dot.ID("mockdot-000"),
                    content: "Their exact words.",
                    capturedAt: Date(timeIntervalSince1970: 0),
                    source: DotSource(kind: .quote, url: seededSource.url, ref: seededSource.id),
                    folder: seededSource.folder
                )
            ]
        }
        #expect(store.state.dots.first?.isExtraction == true)
        await store.dismount()
    }

    @Test(
        "Distilling writes an authored idea referencing the source",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL, sources: [seededSource])
        }
    )
    func distill() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store, sources: [seededSource])

        store.send(.distillSubmitted(seededSource, content: "My take on it.", tags: ["ai"]))
        await store.receive(\.dotCaptured) {
            $0.dots = [
                Dot(
                    id: Dot.ID("mockdot-000"),
                    content: "My take on it.",
                    capturedAt: Date(timeIntervalSince1970: 0),
                    references: [Reference(seededSource.id)],
                    tags: ["ai"],
                    folder: seededSource.folder
                )
            ]
        }
        #expect(store.state.dots.first?.isExtraction == false)
        await store.dismount()
    }

    @Test(
        "Make this mine clears the source and keeps it as a reference",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL, dots: [
                Dot(
                    id: Dot.ID("extract-1"),
                    content: "Rewritten into my own thinking.",
                    capturedAt: Date(timeIntervalSince1970: 100),
                    source: DotSource(kind: .quote, ref: Source.ID("src-1"))
                )
            ])
        }
    )
    func makeMine() async {
        let extraction = Dot(
            id: Dot.ID("extract-1"),
            content: "Rewritten into my own thinking.",
            capturedAt: Date(timeIntervalSince1970: 100),
            source: DotSource(kind: .quote, ref: Source.ID("src-1"))
        )
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store, dots: [extraction])

        let task = store.send(.makeMineTapped(extraction.id)) {
            var mine = extraction
            mine.source = nil
            mine.references = [Reference(Source.ID("src-1"))]
            $0.dots = [mine]
        }
        await task?.value
        #expect(store.state.dots.first?.isExtraction == false)
        await store.dismount()
    }

    @Test(
        "Voice capture accumulates speech and lands a cleaned idea",
        .dependencies {
            $0.modelClient = .inMemory(response: "A clean thought.")
            $0.speechClient = .inMemory(segments: [
                SpeechSegment(text: "a clean", isFinal: false),
                SpeechSegment(text: "a clean um thought", isFinal: true)
            ])
            $0.vaultClient = .inMemory(location: vaultURL)
        }
    )
    func voiceCapture() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store)

        store.send(.voiceCaptureToggled) {
            $0.voice = VoiceCapture()
        }
        await store.receive(\.voiceSegment) {
            $0.voice?.volatile = "a clean"
        }
        await store.receive(\.voiceSegment) {
            $0.voice?.committed = "a clean um thought"
            $0.voice?.volatile = ""
        }
        // Real timeouts: these arrive across stream-finish and model-call
        // suspensions, which the zero-timeout pump can miss under parallel
        // suite load. Receive still returns the moment the action lands.
        await store.receive(\.voiceCaptureEnded, timeout: .seconds(2)) {
            $0.voice?.isCleaning = true
        }
        await store.receive(\.voiceCleaned, timeout: .seconds(2)) {
            $0.voice = nil
        }
        await store.receive(\.dotCaptured, timeout: .seconds(2)) {
            $0.dots = [
                Dot(
                    id: Dot.ID("mockdot-000"),
                    content: "A clean thought.",
                    capturedAt: Date(timeIntervalSince1970: 0)
                )
            ]
        }
        await store.dismount()
    }

    @Test(
        "With an idea focused, cleaned speech lands in it as a fresh paragraph",
        .dependencies {
            $0.modelClient = .inMemory(response: "A clean addition.")
            $0.speechClient = .inMemory(segments: [
                SpeechSegment(text: "a clean um addition", isFinal: true)
            ])
            $0.vaultClient = .inMemory(
                location: vaultURL,
                dots: [
                    Dot(
                        id: Dot.ID("idea-1"),
                        content: "The seed thought.",
                        capturedAt: Date(timeIntervalSince1970: 100)
                    )
                ]
            )
        }
    )
    func voiceDictatesIntoFocusedIdea() async {
        let seeded = Dot(
            id: Dot.ID("idea-1"),
            content: "The seed thought.",
            capturedAt: Date(timeIntervalSince1970: 100)
        )
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store, dots: [seeded])

        store.send(.dotTapped(seeded.id, modifier: .none)) {
            $0.selection = [seeded.id]
        }
        store.send(.voiceCaptureToggled) {
            $0.voice = VoiceCapture()
            $0.voiceTargetID = seeded.id
        }
        await store.receive(\.voiceSegment, timeout: .seconds(2)) {
            $0.voice?.committed = "a clean um addition"
        }
        await store.receive(\.voiceCaptureEnded, timeout: .seconds(2)) {
            $0.voice?.isCleaning = true
        }
        await store.receive(\.voiceCleaned, timeout: .seconds(2)) {
            var grown = seeded
            grown.content = "The seed thought.\n\nA clean addition."
            $0.dots = [grown]
            $0.voice = nil
            $0.voiceTargetID = nil
        }
        #expect(store.state.dots.count == 1)
        await store.dismount()
    }

    @Test(
        "Shift-range across sources deletes them as one gesture",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL, sources: [seededSource, secondSource])
        }
    )
    func rangeSelectSourcesThenDeleteAll() async {
        let store = TestStore(initialState: Ideas.State(vault: vaultURL)) {
            Ideas()
        }
        await receiveMountChain(store, sources: [seededSource, secondSource])

        store.send(.sourceTapped(seededSource.id, modifier: .none)) {
            $0.openSourceID = seededSource.id
            $0.sourceSelection = [seededSource.id]
        }
        store.send(.sourceTapped(secondSource.id, modifier: .range)) {
            $0.sourceSelection = [seededSource.id, secondSource.id]
        }
        let task = store.send(.deleteSourceSelectionTapped) {
            $0.openSourceID = nil
            $0.sourceSelection = []
            $0.sources = []
        }
        await task?.value
        await store.dismount()
    }

    @Test(
        "Deleting a source closes its reader",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL, sources: [seededSource])
        }
    )
    func deleteSourceClosesReader() async {
        var state = Ideas.State(vault: vaultURL)
        state.openSourceID = seededSource.id
        let store = TestStore(initialState: state) {
            Ideas()
        }
        await receiveMountChain(store, sources: [seededSource])

        let task = store.send(.deleteSourceTapped(seededSource.id)) {
            $0.openSourceID = nil
            $0.sources = []
        }
        await task?.value
        await store.dismount()
    }
}
