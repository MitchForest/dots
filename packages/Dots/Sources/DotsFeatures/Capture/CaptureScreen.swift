public import ComposableArchitecture2
public import SwiftUI
import DotsUI

/// The quick-capture panel body: one field, a mic, and a whisper of status.
/// Type a thought, paste a link, or speak — Return captures, esc dismisses.
public struct CaptureScreen: View {
    @Bindable private var store: StoreOf<Capture>
    private let onDismiss: () -> Void

    @FocusState private var isFieldFocused: Bool

    public init(store: StoreOf<Capture>, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.sm) {
            HStack(spacing: DotsSpacing.sm) {
                Circle()
                    .fill(DotsColor.brand)
                    .frame(width: 8, height: 8)

                TextField("Capture a thought or paste a link…", text: $store.draft)
                    .textFieldStyle(.plain)
                    .font(DotsTypography.headline)
                    .foregroundStyle(DotsColor.Ink.primary)
                    .focused($isFieldFocused)
                    .onSubmit {
                        store.send(.submitted)
                    }
                    .onKeyPress(.escape) {
                        store.send(.dismissed)
                        onDismiss()
                        return .handled
                    }

                Button {
                    store.send(.voiceCaptureToggled)
                } label: {
                    Image(systemName: store.voice != nil ? "mic.fill" : "mic")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(store.voice != nil ? DotsColor.brand : DotsColor.Ink.muted)
                }
                .buttonStyle(.plain)
                .help(store.voice != nil ? "Stop and use the words" : "Speak instead")
            }

            if let voice = store.voice {
                Text(voice.committed + (voice.volatile.isEmpty ? "" : " \(voice.volatile)"))
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.muted)
                    .lineLimit(3)
            }

            statusLine
        }
        .padding(DotsSpacing.lg)
        .frame(width: 480)
        .background(DotsColor.Background.primary)
        .onAppear {
            isFieldFocused = true
            store.send(.panelOpened)
        }
        .onChange(of: store.status) { _, status in
            // Captured: linger just long enough to read the ripple, then go.
            if case .captured = status {
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    store.send(.reset)
                    onDismiss()
                }
            }
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch store.status {
        case .idle:
            DotsMetaLabel(
                store.voice != nil
                    ? "LISTENING… MIC TO STOP"
                    : "↩ CAPTURE · ESC DISMISS"
            )
        case .working:
            DotsMetaLabel("CAPTURING…")
        case .captured(let kind):
            DotsMetaLabel(kind.uppercased(), tint: DotsColor.Accent.green)
        case .failed(let message):
            DotsMetaLabel(message.uppercased(), tint: DotsColor.Accent.orange)
        }
    }
}
