import ComposableArchitecture2
import Dependencies
import DependenciesTestSupport
import DotsClients
import DotsDomain
import DotsFeatures
import Foundation
import Testing

private nonisolated let grant = DeviceCodeGrant(
    deviceCode: "device-1",
    userCode: "ABCD-1234",
    verificationURL: URL(string: "https://github.com/login/device")!,
    expiresIn: 900,
    interval: 5
)

@MainActor
@Suite("Auth")
struct AuthTests {
    @Test(
        "Device flow surfaces the user code, then completes",
        .dependencies {
            $0.authClient = AuthClient(
                clearToken: {},
                fetchUser: { _ in GitHubUser(login: "mitchforest") },
                refreshToken: { $0 },
                requestDeviceCode: { grant },
                storeToken: { _ in },
                storedToken: { nil },
                waitForToken: { _ in AuthToken(accessToken: "token") }
            )
        }
    )
    func deviceFlowCompletes() async {
        let store = TestStore(initialState: Auth.State()) {
            Auth()
        }

        let task = store.send(.signInButtonTapped) {
            $0.isWorking = true
        }
        await store.receive(\.deviceCodeResponse) {
            $0.grant = grant
        }
        await task?.value
    }

    @Test(
        "Request failure lands a friendly error",
        .dependencies {
            $0.authClient = .unavailable
        }
    )
    func requestFailureShowsError() async {
        let store = TestStore(initialState: Auth.State()) {
            Auth()
        }

        let task = store.send(.signInButtonTapped) {
            $0.isWorking = true
        }
        await store.receive(\.authFailed) {
            $0.errorMessage = "Something went wrong signing in. Try again."
            $0.isWorking = false
        }
        await task?.value
    }
}
