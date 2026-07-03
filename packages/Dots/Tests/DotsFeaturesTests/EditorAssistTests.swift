import Clocks
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
private nonisolated let documentURL = URL(filePath: "/mock/vault/drafts/why-we-write.md")

private nonisolated func seededClient(contents: String) -> VaultClient {
    var client = VaultClient.inMemory(location: vaultURL)
    client.readDocument = { _ in contents }
    return client
}

@MainActor
@Suite("EditorAssists")
struct EditorAssistTests {
    @Test(
        "Dictation commits finalized speech, drops the volatile tail, then cleans up",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.modelClient = .inMemory(response: "Hello world.")
            $0.speechClient = .inMemory(segments: [
                SpeechSegment(text: "hello", isFinal: false),
                SpeechSegment(text: "hello um world", isFinal: true),
                SpeechSegment(text: "trailing hypothesis", isFinal: false)
            ])
            $0.vaultClient = seededClient(contents: "Start.")
        }
    )
    func dictationFlow() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }
        await store.receive(\.contentLoaded) {
            $0.content = "Start."
            $0.savedContent = "Start."
        }

        store.send(.dictationToggled(location: 6)) {
            $0.dictation = DictationRun(start: 6, location: 6, glue: " ")
        }
        await store.receive(\.dictationSegment) {
            $0.content = "Start. hello"
            $0.dictation?.volatileLength = 6
        }
        await store.receive(\.dictationSegment) {
            $0.content = "Start. hello um world"
            $0.dictation = DictationRun(start: 6, location: 21, volatileLength: 0, glue: " ")
        }
        await store.receive(\.dictationSegment) {
            $0.content = "Start. hello um worldtrailing hypothesis"
            $0.dictation?.volatileLength = 19
        }
        // Stream ends: the volatile tail drops, the committed span cleans up.
        await store.receive(\.dictationFinished) {
            $0.content = "Start. hello um world"
            $0.dictation = nil
            $0.assist = AssistRun(
                kind: .cleanupDictation,
                location: 6,
                length: 15,
                original: " hello um world"
            )
        }
        await store.receive(\.assistProviderResolved)
        await store.receive(\.assistStreamed) {
            $0.content = "Start.Hello "
            $0.assist?.length = 6
        }
        await store.receive(\.assistStreamed) {
            $0.content = "Start.Hello world."
            $0.assist?.length = 12
        }
        await store.receive(\.assistFinished) {
            $0.assist = nil
        }
        await store.receive(\.saved) {
            $0.savedContent = "Start.Hello world."
        }
        await store.dismount()
    }

    @Test(
        "An assist streams into the selection and finishes; cancel restores",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.modelClient = .inMemory(response: "Tightened words.")
            $0.vaultClient = seededClient(contents: "Keep. REPLACE ME. Tail.")
        }
    )
    func assistStreamsAndCancels() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }
        await store.receive(\.contentLoaded) {
            $0.content = "Keep. REPLACE ME. Tail."
            $0.savedContent = "Keep. REPLACE ME. Tail."
        }

        // "REPLACE ME." spans UTF-16 range 6..<17.
        store.send(.assistRequested(.tighten, location: 6, length: 11)) {
            $0.assist = AssistRun(kind: .tighten, location: 6, length: 11, original: "REPLACE ME.")
        }
        await store.receive(\.assistProviderResolved)
        await store.receive(\.assistStreamed) {
            $0.content = "Keep. Tightene Tail."
            $0.assist?.length = 8
        }
        await store.receive(\.assistStreamed) {
            $0.content = "Keep. Tightened words. Tail."
            $0.assist?.length = 16
        }
        await store.receive(\.assistFinished) {
            $0.assist = nil
        }
        await store.receive(\.saved) {
            $0.savedContent = "Keep. Tightened words. Tail."
        }
        await store.dismount()
    }

    @Test(
        "Cancelling a stalled assist restores the original region",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.modelClient = {
                var client = ModelClient.inMemory()
                // One snapshot, then silence — the run must be cancelled.
                client.stream = { _ in
                    AsyncThrowingStream { continuation in
                        continuation.yield("Tightene")
                    }
                }
                return client
            }()
            $0.vaultClient = seededClient(contents: "Keep. REPLACE ME. Tail.")
        }
    )
    func assistCancelRestores() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }
        await store.receive(\.contentLoaded) {
            $0.content = "Keep. REPLACE ME. Tail."
            $0.savedContent = "Keep. REPLACE ME. Tail."
        }

        store.send(.assistRequested(.tighten, location: 6, length: 11)) {
            $0.assist = AssistRun(kind: .tighten, location: 6, length: 11, original: "REPLACE ME.")
        }
        await store.receive(\.assistProviderResolved)
        await store.receive(\.assistStreamed) {
            $0.content = "Keep. Tightene Tail."
            $0.assist?.length = 8
        }
        let task = store.send(.assistCancelled) {
            $0.content = "Keep. REPLACE ME. Tail."
            $0.assist = nil
        }
        await task?.value
        await store.dismount()
    }

    @Test(
        "Continue works from a caret; selection assists require a selection",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.modelClient = .inMemory(response: " And more.")
            $0.vaultClient = seededClient(contents: "The start.")
        }
    )
    func continueFromCaret() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }
        await store.receive(\.contentLoaded) {
            $0.content = "The start."
            $0.savedContent = "The start."
        }

        // A selection assist with no selection is a no-op.
        store.send(.assistRequested(.tighten, location: 10, length: 0))

        store.send(.assistRequested(.continueWriting, location: 10, length: 0)) {
            $0.assist = AssistRun(kind: .continueWriting, location: 10, length: 0, original: "")
        }
        await store.receive(\.assistProviderResolved)
        await store.receive(\.assistStreamed) {
            $0.content = "The start. And "
            $0.assist?.length = 5
        }
        await store.receive(\.assistStreamed) {
            $0.content = "The start. And more."
            $0.assist?.length = 10
        }
        await store.receive(\.assistFinished) {
            $0.assist = nil
        }
        await store.receive(\.saved) {
            $0.savedContent = "The start. And more."
        }
        await store.dismount()
    }

    @Test(
        "Ask runs the writer's instruction on the selection",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.modelClient = .inMemory(response: "- point")
            $0.vaultClient = seededClient(contents: "Keep. REPLACE ME. Tail.")
        }
    )
    func askAssist() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }
        await store.receive(\.contentLoaded) {
            $0.content = "Keep. REPLACE ME. Tail."
            $0.savedContent = "Keep. REPLACE ME. Tail."
        }

        // Empty instruction and empty selection are both no-ops.
        store.send(.promptAssistRequested("  ", location: 6, length: 11))
        store.send(.promptAssistRequested("bullets", location: 6, length: 0))

        store.send(.promptAssistRequested("turn into bullets", location: 6, length: 11)) {
            $0.assist = AssistRun(kind: .prompt, location: 6, length: 11, original: "REPLACE ME.")
        }
        await store.receive(\.assistProviderResolved)
        await store.receive(\.assistStreamed) {
            $0.content = "Keep. - p Tail."
            $0.assist?.length = 3
        }
        await store.receive(\.assistStreamed) {
            $0.content = "Keep. - point Tail."
            $0.assist?.length = 7
        }
        await store.receive(\.assistFinished) {
            $0.assist = nil
        }
        await store.receive(\.saved) {
            $0.savedContent = "Keep. - point Tail."
        }
        await store.dismount()
    }

    @Test(
        "Tab-summoned ghost streams dimmed text; Tab accepts it",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.modelClient = .inMemory(response: " And more.")
            $0.vaultClient = seededClient(contents: "The start.")
        }
    )
    func ghostAccept() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }
        await store.receive(\.contentLoaded) {
            $0.content = "The start."
            $0.savedContent = "The start."
        }

        store.send(.ghostRequested(location: 10))
        await store.receive(\.ghostProviderResolved) {
            $0.ghost = GhostRun(location: 10, length: 0, glue: " ")
        }
        await store.receive(\.ghostStreamed) {
            $0.content = "The start. And "
            $0.ghost?.length = 5
        }
        await store.receive(\.ghostStreamed) {
            $0.content = "The start. And more."
            $0.ghost?.length = 10
        }

        let task = store.send(.ghostAccepted) {
            $0.ghost = nil
        }
        await store.receive(\.saved) {
            $0.savedContent = "The start. And more."
        }
        await task?.value
        await store.dismount()
    }

    @Test(
        "Dismissing a ghost removes the dimmed text entirely",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.modelClient = {
                var client = ModelClient.inMemory()
                client.stream = { _ in
                    AsyncThrowingStream { continuation in
                        continuation.yield(" ghost words")
                    }
                }
                return client
            }()
            $0.vaultClient = seededClient(contents: "The start.")
        }
    )
    func ghostDismiss() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }
        await store.receive(\.contentLoaded) {
            $0.content = "The start."
            $0.savedContent = "The start."
        }

        store.send(.ghostRequested(location: 10))
        await store.receive(\.ghostProviderResolved) {
            $0.ghost = GhostRun(location: 10, length: 0, glue: " ")
        }
        await store.receive(\.ghostStreamed) {
            $0.content = "The start. ghost words"
            $0.ghost?.length = 12
        }

        let task = store.send(.ghostDismissed) {
            $0.content = "The start."
            $0.ghost = nil
        }
        await task?.value
        await store.dismount()
    }
}
