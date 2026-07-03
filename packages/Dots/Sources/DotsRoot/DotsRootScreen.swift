import ComposableArchitecture2
import DotsFeatures
import DotsUI
public import SwiftUI

/// Root composition screen: owns the root store, applies the persisted
/// appearance override, and routes to the current top-level surface.
public struct DotsRootScreen: View {
    private static let store = Store(initialState: AppRoot.State()) {
        AppRoot()
    }

    @AppStorage("blog.dots.appearanceMode") private var appearanceRaw = DotsAppearanceMode.system.rawValue

    public init() {}

    /// Menu-bar entry point ("Dots → Sign Out…"): returns to the entry gate
    /// and clears any stored GitHub session. The vault is untouched.
    public static func signOut() {
        store.send(.signOutSelected)
    }

    public var body: some View {
        AppRootScreen(store: Self.store)
            .preferredColorScheme(DotsAppearanceMode(rawValue: appearanceRaw)?.colorScheme)
    }
}
