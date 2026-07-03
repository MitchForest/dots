import ComposableArchitecture2
import Dependencies
import DependenciesTestSupport
import DotsClients
import DotsDomain
import DotsFeatures
import Foundation
import Testing

private nonisolated let vaultURL = URL(filePath: "/mock/vault", directoryHint: .isDirectory)

// Dedicated per-test clients: the trait closure needs a stable handle the
// test body can interrogate afterwards.
private nonisolated let loadClient = VaultClient.inMemory(location: vaultURL)
private nonisolated let toggleClient = VaultClient.inMemory(location: vaultURL)
private nonisolated let goalClient = VaultClient.inMemory(location: vaultURL)

/// Non-exhaustive: the ModelSettings child loads its own chain alongside the
/// parent's, and the interleave isn't part of the contract — these tests
/// follow only the preferences actions.
@MainActor
@Suite("Preferences")
struct PreferencesTests {
    @Test(
        "Mount restores the vault path, goal, and intake flag",
        .dependencies {
            $0.modelClient = .inMemory()
            $0.vaultClient = loadClient
        }
    )
    func mountLoadsEverything() async {
        await TestExhaustivity.$current.withValue(.off) {
            try? await loadClient.writeIntakeEnabled(vaultURL, false)
            try? await loadClient.writeStreakGoal(vaultURL, StreakGoal(mode: .words(target: 500)))
            let store = TestStore(initialState: Preferences.State()) {
                Preferences()
            }

            await store.receive(\.vaultLoaded)
            await store.receive(\.goalLoaded)
            await store.receive(\.intakeLoaded)

            #expect(store.state.vault == vaultURL)
            #expect(store.state.streakGoal == StreakGoal(mode: .words(target: 500)))
            #expect(store.state.isIntakeEnabled == false)
            await store.dismount()
        }
    }

    @Test(
        "The intake toggle persists to the vault",
        .dependencies {
            $0.modelClient = .inMemory()
            $0.vaultClient = toggleClient
        }
    )
    func intakeTogglePersists() async {
        await TestExhaustivity.$current.withValue(.off) {
            let store = TestStore(initialState: Preferences.State()) {
                Preferences()
            }
            await store.receive(\.vaultLoaded)
            await store.receive(\.goalLoaded)
            await store.receive(\.intakeLoaded)

            let task = store.send(.intakeToggled(false)) {
                $0.isIntakeEnabled = false
            }
            await task?.value
            #expect(await toggleClient.readIntakeEnabled(vaultURL) == false)

            let again = store.send(.intakeToggled(true)) {
                $0.isIntakeEnabled = true
            }
            await again?.value
            #expect(await toggleClient.readIntakeEnabled(vaultURL) == true)
            await store.dismount()
        }
    }

    @Test(
        "Saving the writing goal persists to the vault",
        .dependencies {
            $0.modelClient = .inMemory()
            $0.vaultClient = goalClient
        }
    )
    func goalPersists() async {
        await TestExhaustivity.$current.withValue(.off) {
            let store = TestStore(initialState: Preferences.State()) {
                Preferences()
            }
            await store.receive(\.vaultLoaded)
            await store.receive(\.goalLoaded)
            await store.receive(\.intakeLoaded)

            let goal = StreakGoal(mode: .words(target: 750), goalDays: [2, 3, 4, 5, 6])
            let task = store.send(.goalChanged(goal)) {
                $0.streakGoal = goal
            }
            await task?.value
            #expect((try? await goalClient.readStreakGoal(vaultURL)) == goal)
            await store.dismount()
        }
    }
}
