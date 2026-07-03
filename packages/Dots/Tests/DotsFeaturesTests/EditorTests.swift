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
@Suite("Editor")
struct EditorTests {
    @Test(
        "Mount loads the document",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.vaultClient = seededClient(contents: "# Why we write\n\nBody.")
        }
    )
    func mountLoadsDocument() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }

        await store.receive(\.contentLoaded) {
            $0.content = "# Why we write\n\nBody."
            $0.savedContent = "# Why we write\n\nBody."
        }
        await store.dismount()
    }

    @Test(
        "Edits autosave and clear the dirty flag",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.vaultClient = seededClient(contents: "start")
        }
    )
    func editsAutosave() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }

        await store.receive(\.contentLoaded) {
            $0.content = "start"
            $0.savedContent = "start"
        }

        await store.modify {
            $0.content = "start plus more"
        }
        await store.receive(\.saved) {
            $0.savedContent = "start plus more"
        }
        await store.dismount()
    }

    @Test(
        "External changes are ignored while dirty",
        .dependencies {
            $0.continuousClock = TestClock()
            $0.vaultClient = seededClient(contents: "start")
        }
    )
    func externalChangesIgnoredWhileDirty() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }

        await store.receive(\.contentLoaded) {
            $0.content = "start"
            $0.savedContent = "start"
        }

        await store.modify {
            $0.content = "unsaved words"
        }
        store.send(.externalChangeDetected("outside edit"))
        await store.dismount()
    }

    @Test(
        "External changes apply while clean",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.vaultClient = seededClient(contents: "start")
        }
    )
    func externalChangesApplyWhileClean() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }

        await store.receive(\.contentLoaded) {
            $0.content = "start"
            $0.savedContent = "start"
        }

        store.send(.externalChangeDetected("outside edit")) {
            $0.content = "outside edit"
            $0.savedContent = "outside edit"
        }
        await store.dismount()
    }

    @Test(
        "Sent ideas attach as frontmatter references and resolve for the strip",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            var client = VaultClient.inMemory(
                location: vaultURL,
                dots: [
                    Dot(
                        id: Dot.ID("idea-1"),
                        content: "A sent idea.",
                        capturedAt: Date(timeIntervalSince1970: 100)
                    )
                ]
            )
            client.readDocument = { _ in "---\nid: 01ABC\ntitle: T\nideas: []\n---\n\nBody." }
            $0.vaultClient = client
        }
    )
    func ideasAttachAndDetach() async {
        let idea = Dot(
            id: Dot.ID("idea-1"),
            content: "A sent idea.",
            capturedAt: Date(timeIntervalSince1970: 100)
        )
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }

        await store.receive(\.contentLoaded) {
            $0.content = "Body."
            $0.frontmatter = "---\nid: 01ABC\ntitle: T\nideas: []\n---\n\n"
            $0.savedContent = "Body."
        }

        store.send(.ideasAttached([idea.id])) {
            $0.frontmatter = "---\nid: 01ABC\ntitle: T\nideas: [idea-1]\n---\n\n"
        }
        await store.receive(\.referencedIdeasLoaded) {
            $0.referencedIdeas = [idea]
        }

        let task = store.send(.ideaDetached(idea.id)) {
            $0.frontmatter = "---\nid: 01ABC\ntitle: T\nideas: []\n---\n\n"
            $0.referencedIdeas = []
        }
        await task?.value
        await store.dismount()
    }

    @Test(
        "Presentation toggles between rich (default) and markdown",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.vaultClient = seededClient(contents: "")
        }
    )
    func presentationToggles() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }

        await store.receive(\.contentLoaded)

        #expect(store.state.isMarkdownMode == false)
        store.send(.presentationToggled) {
            $0.isMarkdownMode = true
        }
        store.send(.presentationToggled) {
            $0.isMarkdownMode = false
        }
        await store.dismount()
    }

    @Test(
        "Focus and typewriter toggle",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.vaultClient = seededClient(contents: "")
        }
    )
    func focusAndTypewriter() async {
        let store = TestStore(initialState: Editor.State(vault: vaultURL, documentURL: documentURL)) {
            Editor()
        }

        await store.receive(\.contentLoaded)

        store.send(.focusToggled) {
            $0.isFocusEnabled = true
        }
        store.send(.focusToggled) {
            $0.isFocusEnabled = false
        }
        store.send(.typewriterToggled) {
            $0.isTypewriterEnabled = true
        }
        await store.dismount()
    }
}
