public import SwiftUI

/// User-selectable appearance override. Persisted via `@AppStorage` at the
/// app root and toggled from chrome (auth screen moon/sun).
public enum DotsAppearanceMode: String, CaseIterable, Sendable {
    case dark
    case light
    case system

    public var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}
