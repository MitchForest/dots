import ComposableArchitecture2
import Dependencies
import DependenciesTestSupport
import DotsClients
import DotsDomain
import DotsFeatures
import Foundation
import Testing

private nonisolated let vaultURL = URL(filePath: "/mock/vault", directoryHint: .isDirectory)

private nonisolated func source(_ id: String) -> Source {
    Source(
        id: Source.ID(id),
        title: "Maker's Schedule",
        content: "Meetings cost makers half a day.",
        capturedAt: Date(timeIntervalSince1970: 100)
    )
}

// One dedicated client per test: the trait closure needs a stable handle the
// test body can interrogate afterwards, and in-memory state must not leak
// between tests.
private nonisolated let mountClient = VaultClient.inMemory(
    location: vaultURL,
    sources: [source("src-1")]
)
private nonisolated let skipClient = VaultClient.inMemory(
    location: vaultURL,
    sources: [source("src-1")],
    proposals: [dismissedProposal]
)
private nonisolated let garbageClient = VaultClient.inMemory(
    location: vaultURL,
    sources: [source("src-1")]
)
private nonisolated let dismissedProposal = IdeaProposal(
    id: IdeaProposal.ID("prop-1"),
    sourceId: Source.ID("src-1"),
    ideas: [ProposedIdea(id: 1, text: "Old draft.")],
    createdAt: Date(timeIntervalSince1970: 50),
    status: .dismissed
)

private nonisolated let disabledClient = VaultClient.inMemory(
    location: vaultURL,
    sources: [source("src-1")]
)

@MainActor
@Suite("Intake")
struct IntakeTests {
    @Test(
        "With intake off, captures stay plain sources — no proposals",
        .dependencies {
            $0.modelClient = .inMemory(response: "1. Should never be asked for.")
            $0.vaultClient = disabledClient
        }
    )
    func disabledIntakeWritesNothing() async {
        try? await disabledClient.writeIntakeEnabled(vaultURL, false)
        let store = TestStore(initialState: Intake.State()) {
            Intake()
        }

        await store.receive(\.vaultLoaded) {
            $0.vault = vaultURL
        }
        await store.receive(\.extractionLoaded)
        await store.dismount()

        let proposals = try? await disabledClient.listProposals(vaultURL)
        #expect(proposals?.isEmpty == true)
    }

    @Test(
        "Mount distills the unproposed source and writes its proposal",
        .dependencies {
            $0.modelClient = .inMemory(response: "1. Attention is scarce.\n2. Calendars misprice it.")
            $0.vaultClient = mountClient
        }
    )
    func mountWritesProposal() async {
        let store = TestStore(initialState: Intake.State()) {
            Intake()
        }

        await store.receive(\.vaultLoaded) {
            $0.vault = vaultURL
        }
        await store.receive(\.extractionLoaded)
        await store.receive(\.sourcesLoaded) {
            $0.sources = [source("src-1")]
        }
        await store.receive(\.proposalsLoaded) {
            $0.queue = [source("src-1")]
        }
        await store.receive(\.providerResolved)
        await store.receive(\.drafted) {
            $0.queue = []
        }
        await store.receive(\.proposalWritten)
        await store.dismount()

        let proposals = try? await mountClient.listProposals(vaultURL)
        #expect(proposals?.count == 1)
        #expect(proposals?.first?.sourceId == Source.ID("src-1"))
        #expect(proposals?.first?.ideas.map(\.text) == [
            "Attention is scarce.",
            "Calendars misprice it."
        ])
        #expect(proposals?.first?.ideas.allSatisfy { $0.status == .pending } == true)
    }

    @Test(
        "Already-proposed sources are skipped — dismissed counts as reviewed",
        .dependencies {
            $0.modelClient = .inMemory(response: "1. Should never be asked for.")
            $0.vaultClient = skipClient
        }
    )
    func proposedSourcesAreSkipped() async {
        let store = TestStore(initialState: Intake.State()) {
            Intake()
        }

        await store.receive(\.vaultLoaded) {
            $0.vault = vaultURL
        }
        await store.receive(\.extractionLoaded)
        await store.receive(\.sourcesLoaded) {
            $0.sources = [source("src-1")]
        }
        await store.receive(\.proposalsLoaded)
        await store.dismount()

        let proposals = try? await skipClient.listProposals(vaultURL)
        #expect(proposals == [dismissedProposal])
    }

    @Test(
        "An unparseable model response writes nothing and stays quiet",
        .dependencies {
            $0.modelClient = .inMemory(response: "I could not read this article, sorry.")
            $0.vaultClient = garbageClient
        }
    )
    func garbageResponseWritesNothing() async {
        let store = TestStore(initialState: Intake.State()) {
            Intake()
        }

        await store.receive(\.vaultLoaded) {
            $0.vault = vaultURL
        }
        await store.receive(\.extractionLoaded)
        await store.receive(\.sourcesLoaded) {
            $0.sources = [source("src-1")]
        }
        await store.receive(\.proposalsLoaded) {
            $0.queue = [source("src-1")]
        }
        await store.receive(\.providerResolved)
        await store.receive(\.drafted) {
            $0.queue = []
        }
        await store.dismount()

        let proposals = try? await garbageClient.listProposals(vaultURL)
        #expect(proposals?.isEmpty == true)
    }
}
