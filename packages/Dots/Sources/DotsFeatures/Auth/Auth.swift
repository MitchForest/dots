public import ComposableArchitecture2
public import DotsDomain
import Dependencies
import DotsClients

/// Posted when the entry gate resolves: a GitHub user after device-flow
/// sign-in, or `nil` when the writer chooses to stay local.
enum AuthCompleted: FeatureEventKey {
    typealias Value = GitHubUser?
}

@Feature
public struct Auth {
    public struct State: Equatable {
        public var errorMessage: String?
        public var grant: DeviceCodeGrant?
        public var isWorking = false

        public init() {}
    }

    public enum Action {
        case authFailed(String)
        case deviceCodeResponse(DeviceCodeGrant)
        case signInButtonTapped
        case useLocallyButtonTapped
    }

    @Dependency(\.authClient) var authClient

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .authFailed(let message):
                state.errorMessage = message
                state.grant = nil
                state.isWorking = false

            case .deviceCodeResponse(let grant):
                state.grant = grant

            case .signInButtonTapped:
                state.errorMessage = nil
                state.isWorking = true
                store.addTask {
                    do {
                        let grant = try await authClient.requestDeviceCode()
                        try store.send(.deviceCodeResponse(grant))
                        let token = try await authClient.waitForToken(grant)
                        try await authClient.storeToken(token)
                        let user = try await authClient.fetchUser(token)
                        try store.post(key: AuthCompleted.self, value: user)
                    } catch {
                        try store.send(.authFailed(Self.message(for: error)))
                    }
                }

            case .useLocallyButtonTapped:
                store.addTask {
                    try store.post(key: AuthCompleted.self, value: nil)
                }
            }
        }
    }

    private static func message(for error: any Error) -> String {
        switch error {
        case AuthClientError.accessDenied:
            "Sign-in was declined on GitHub."
        case AuthClientError.codeExpired:
            "That code expired. Try again."
        case AuthClientError.httpFailure:
            "GitHub is unreachable right now. Try again in a moment."
        default:
            "Something went wrong signing in. Try again."
        }
    }
}
