import ComposableArchitecture2
import Dependencies
import DependenciesTestSupport
import DotsClients
import DotsDomain
import DotsFeatures
import Foundation
import Testing

@MainActor
@Suite("AppRoot")
struct AppRootTests {
    @Test(
        "No stored token routes to the entry gate",
        .dependencies {
            $0.authClient = .unavailable
        }
    )
    func signedOutShowsAuth() async {
        let store = TestStore(initialState: AppRoot.State()) {
            AppRoot()
        }

        await store.receive(\.sessionRestored) {
            $0.auth = Auth.State().testSnapshot
            $0.isRestoringSession = false
        }
    }

    @Test(
        "A valid stored session routes straight to Home",
        .dependencies {
            $0.authClient = .preview(user: GitHubUser(login: "mitchforest"))
            $0.calendar = Calendar(identifier: .gregorian)
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.vaultClient = .inMemory()
        }
    )
    func storedSessionShowsHome() async {
        await TestExhaustivity.$current.withValue(.off) {
            let store = TestStore(initialState: AppRoot.State()) {
                AppRoot()
            }

            await store.receive(\.sessionRestored)

            #expect(store.state.isRestoringSession == false)
            #expect(store.state.auth == nil)
            #expect(store.state.home?.user == GitHubUser(login: "mitchforest"))
        }
    }
}
