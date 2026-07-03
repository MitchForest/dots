public import ComposableArchitecture2
import DotsUI
public import SwiftUI

public struct AppRootScreen: View {
    private let store: StoreOf<AppRoot>

    public init(store: StoreOf<AppRoot>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if let homeStore = store.scope(\.home, action: \.home) {
                HomeScreen(store: homeStore)
            } else if let authStore = store.scope(\.auth, action: \.auth) {
                AuthScreen(store: authStore)
            } else {
                DotsColor.Background.primary
                    .ignoresSafeArea()
            }
        }
    }
}
