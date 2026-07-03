import ComposableArchitecture2
import Dependencies
import DependenciesTestSupport
import DotsClients
import DotsDomain
import DotsFeatures
import Foundation
import Testing

private nonisolated let vaultURL = URL(filePath: "/mock/vault", directoryHint: .isDirectory)
private nonisolated let documentURL = URL(filePath: "/mock/vault/drafts/why-we-write.md")
private nonisolated let seededDot = Dot(
    id: Dot.ID("seed-1"),
    content: "We read to collect dots.",
    capturedAt: Date(timeIntervalSince1970: 100)
)

@MainActor
@Suite("Workspace")
struct WorkspaceTests {
    @Test(
        "Start draft from selection seeds an editor",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            $0.vaultClient = .inMemory(location: vaultURL, dots: [seededDot])
        }
    )
    func startDraftSeedsEditor() async {
        await TestExhaustivity.$current.withValue(.off) {
            var state = Workspace.State(vault: vaultURL)
            state.ideas.selection = [seededDot.id]
            let store = TestStore(initialState: state) {
                Workspace()
            }

            await store.receive(\.ideas.dotsLoaded)

            let task = store.send(.startDraftButtonTapped)
            await store.receive(\.draftSeeded)

            #expect(store.state.editor?.vault == vaultURL)
            await store.dismount()
            await task?.value
        }
    }

    @Test(
        "Sending with a draft open attaches references instead of creating",
        .dependencies {
            $0.continuousClock = ImmediateClock()
            var client = VaultClient.inMemory(location: vaultURL, dots: [seededDot])
            client.readDocument = { _ in "---\nid: 01ABC\ntitle: T\nideas: []\n---\n\nBody." }
            $0.vaultClient = client
        }
    )
    func sendAttachesToOpenDraft() async {
        await TestExhaustivity.$current.withValue(.off) {
            var state = Workspace.State(vault: vaultURL, documentURL: documentURL)
            state.ideas.selection = [seededDot.id]
            let store = TestStore(initialState: state) {
                Workspace()
            }

            await store.receive(\.editor.contentLoaded)
            await store.receive(\.ideas.dotsLoaded)

            let task = store.send(.ideas(.draftFromSelectionTapped))
            await store.receive(\.editor.ideasAttached)

            #expect(store.state.editor?.frontmatter.contains("ideas: [seed-1]") == true)
            await store.dismount()
            await task?.value
        }
    }
}
