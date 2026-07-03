import ComposableArchitecture2
import Dependencies
import DependenciesTestSupport
import DotsClients
import DotsDomain
import DotsFeatures
import Foundation
import Testing

private nonisolated let vaultURL = URL(filePath: "/mock/vault", directoryHint: .isDirectory)
private nonisolated let seededDocument = VaultDocument(
    url: URL(filePath: "/mock/vault/drafts/why-we-write.md"),
    title: "Why we write",
    modifiedAt: Date(timeIntervalSince1970: 100)
)

private nonisolated func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

@MainActor
@Suite("Home")
struct HomeTests {
    @Test(
        "Mount greets and restores the stored vault with its recents",
        .dependencies {
            $0.calendar = utcCalendar()
            $0.date.now = Date(timeIntervalSince1970: 8 * 3600)
            $0.vaultClient = .inMemory(location: vaultURL, documents: [seededDocument])
        }
    )
    func mountRestoresVault() async throws {
        // Non-exhaustive: the intake child restores the vault in parallel
        // with Home's own chain, and the interleave isn't part of Home's
        // contract — follow only Home's actions.
        await TestExhaustivity.$current.withValue(.off) {
            let store = TestStore(initialState: Home.State()) {
                Home()
            }

            await store.receive(\.vaultLoaded)
            await store.receive(\.settingsLoaded)
            await store.receive(\.documentsLoaded)
            await store.receive(\.statsLoaded)

            #expect(store.state.greeting == "Good morning")
            #expect(store.state.vault == vaultURL)
            #expect(store.state.documents == [seededDocument])
            #expect(store.state.draftCount == 1)
            #expect(store.state.contributionIntensities == Array(repeating: 0, count: 84))
            await store.dismount()
        }
    }

    @Test(
        "New draft refreshes the recents list",
        .dependencies {
            $0.calendar = utcCalendar()
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.vaultClient = .inMemory(location: vaultURL)
        }
    )
    func newDraftRefreshesRecents() async throws {
        await TestExhaustivity.$current.withValue(.off) {
            var state = Home.State()
            state.vault = vaultURL
            let store = TestStore(initialState: state) {
                Home()
            }

            await store.receive(\.vaultLoaded)
            await store.receive(\.settingsLoaded)
            await store.receive(\.documentsLoaded)
            await store.receive(\.statsLoaded)

            let task = store.send(.newDraftButtonTapped)
            await store.receive(\.draftCreated)

            #expect(store.state.workspace != nil)
            #expect(
                store.state.workspace?.editor?.documentURL
                    == URL(filePath: "/mock/drafts/untitled.md")
            )
            await store.dismount()
            await task?.value
        }
    }
}
