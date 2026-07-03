public import ComposableArchitecture2
public import DotsDomain
import Dependencies
import DotsClients

/// Top-level routing: restore the GitHub session on launch, then hand off to
/// Home; otherwise show the entry gate. Children report back via events.
@Feature
public struct AppRoot {
    public struct State: Equatable {
        public var auth: Auth.State?
        public var home: Home.State?
        public var isRestoringSession = true

        public init() {}
    }

    public enum Action {
        case auth(Auth.Action)
        case home(Home.Action)
        case localSessionRestored
        case sessionRestored(GitHubUser?)
        case signOutSelected
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.vaultClient) var vaultClient

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .auth, .home:
                break

            case .sessionRestored(let user):
                state.isRestoringSession = false
                if let user {
                    state.home = Home.State(user: user)
                } else {
                    state.auth = Auth.State()
                }

            case .localSessionRestored:
                state.isRestoringSession = false
                state.home = Home.State()

            case .signOutSelected:
                state.home = nil
                state.auth = Auth.State()
                store.addTask {
                    await authClient.clearToken()
                }
            }
        }
        .onMount { _ in
            store.addTask {
                if let user = await Self.restoreSession(authClient) {
                    try store.send(.sessionRestored(user))
                } else if await vaultClient.storedVaultLocation() != nil {
                    // A vault with no GitHub session = an onboarded local-only
                    // writer. Never re-gate them behind the auth screen.
                    try store.send(.localSessionRestored)
                } else {
                    try store.send(.sessionRestored(nil))
                }
            }
        }
        .ifLet(\.auth, action: \.auth) {
            Auth()
        }
        .ifLet(\.home, action: \.home) {
            Home()
        }
        .onEvent(AuthCompleted.self) { user, state in
            state.auth = nil
            state.home = Home.State(user: user)
        }
    }

    /// Stored token → user; on failure try one refresh; else signed out.
    private static func restoreSession(_ authClient: AuthClient) async -> GitHubUser? {
        guard let token = await authClient.storedToken() else { return nil }
        if let user = try? await authClient.fetchUser(token) {
            return user
        }
        guard let refreshed = try? await authClient.refreshToken(token),
              (try? await authClient.storeToken(refreshed)) != nil,
              let user = try? await authClient.fetchUser(refreshed)
        else {
            await authClient.clearToken()
            return nil
        }
        return user
    }
}
