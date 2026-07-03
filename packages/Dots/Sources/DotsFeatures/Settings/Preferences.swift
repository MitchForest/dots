public import ComposableArchitecture2
public import DotsDomain
public import Foundation
import Dependencies
import DotsClients

/// The Settings window: vault, AI (provider + the intake toggle), and the
/// writing goal. Deliberately small — Dots is opinionated, and everything
/// here has a reason to be a choice. Vault-scoped values persist to
/// `.dots/settings.json` and announce themselves so the main window (and
/// other devices) follow along.
@Feature
public struct Preferences {
    public struct State: Equatable {
        public var isIntakeEnabled = true
        public var model = ModelSettings.State()
        public var streakGoal = StreakGoal()
        public var vault: URL?

        public init() {}
    }

    public enum Action {
        case goalChanged(StreakGoal)
        case goalLoaded(StreakGoal)
        case intakeLoaded(isEnabled: Bool)
        case intakeToggled(Bool)
        case model(ModelSettings.Action)
        case revealVaultTapped
        case vaultChosen(URL)
        case vaultLoaded(URL?)
    }

    @Dependency(\.vaultClient) var vaultClient

    public init() {}

    public var body: some Feature {
        Features {
            Scope(\.model, action: \.model) {
                ModelSettings()
            }

            updates
        }
    }

    private var updates: some Feature {
        Update { state, action in
            switch action {
            case .goalChanged(let goal):
                state.streakGoal = goal
                guard let vault = state.vault else { break }
                store.addTask {
                    try await vaultClient.writeStreakGoal(vault, goal)
                }

            case .goalLoaded(let goal):
                state.streakGoal = goal
                guard let vault = state.vault else { break }
                store.addTask {
                    try store.send(.intakeLoaded(isEnabled: await vaultClient.readIntakeEnabled(vault)))
                }

            case .intakeLoaded(let isEnabled):
                state.isIntakeEnabled = isEnabled

            case .intakeToggled(let isEnabled):
                state.isIntakeEnabled = isEnabled
                guard let vault = state.vault else { break }
                store.addTask {
                    try await vaultClient.writeIntakeEnabled(vault, isEnabled)
                }

            case .model:
                break

            case .revealVaultTapped:
                guard let vault = state.vault else { break }
                store.addTask {
                    await vaultClient.revealDocument(vault)
                }

            case .vaultChosen(let location):
                store.addTask {
                    try await vaultClient.openVault(location)
                    try store.send(.vaultLoaded(location))
                }

            case .vaultLoaded(let vault):
                state.vault = vault
                guard let vault else { break }
                store.addTask {
                    let goal = (try? await vaultClient.readStreakGoal(vault)) ?? StreakGoal()
                    try store.send(.goalLoaded(goal))
                }
            }
        }
        .onMount { _ in
            store.addTask {
                try store.send(.vaultLoaded(await vaultClient.storedVaultLocation()))
            }
        }
    }
}
