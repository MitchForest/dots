import ComposableArchitecture2
import DotsFeatures
public import SwiftUI

/// The Settings window's content — vault, AI, and the writing goal. One
/// static store: macOS may recreate the scene, the state survives.
public struct DotsSettingsScreen: View {
    private static let store = Store(initialState: Preferences.State()) {
        Preferences()
    }

    public init() {}

    public var body: some View {
        PreferencesScreen(store: Self.store)
    }
}
