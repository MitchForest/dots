import DotsUI
import SwiftUI

/// The voice-capture popover: settled words in ink, the live hypothesis in
/// muted italic behind them, one stop button. Model-blind.
struct VoiceCaptureView: View {
    let voice: VoiceCapture?
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.sm) {
            DotsMetaLabel(voice?.isCleaning == true ? "CLEANING UP…" : "LISTENING…")

            ScrollView {
                transcript
                    .font(DotsTypography.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 320, height: 140)

            HStack {
                DotsMetaLabel("YOUR WORDS BECOME AN IDEA — FILLERS REMOVED")
                Spacer()
                Button(voice?.isCleaning == true ? "Saving…" : "Stop & save") {
                    onStop()
                }
                .buttonStyle(.plain)
                .font(DotsTypography.callout)
                .foregroundStyle(DotsColor.brand)
                .disabled(voice?.isCleaning == true)
            }
        }
        .padding(DotsSpacing.md)
    }

    /// Settled words in ink, the live hypothesis muted-italic behind them.
    private var transcript: Text {
        let committed = Text(voice?.committed ?? "")
            .foregroundStyle(DotsColor.Ink.primary)
        guard let volatile = voice?.volatile, !volatile.isEmpty else {
            return committed
        }
        let hypothesis = Text(" \(volatile)")
            .foregroundStyle(DotsColor.Ink.muted)
            .italic()
        return Text("\(committed)\(hypothesis)")
    }
}
