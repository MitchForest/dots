import ComposableArchitecture2
import DotsFeatures
public import SwiftUI

/// The quick-capture panel's content — one static store, so drafts survive
/// a dismissed panel and the vault resolves once per open.
public struct DotsCaptureScreen: View {
    private static let store = Store(initialState: Capture.State()) {
        Capture()
    }

    private let onDismiss: () -> Void

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        CaptureScreen(store: Self.store, onDismiss: onDismiss)
    }
}
