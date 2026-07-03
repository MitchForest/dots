import DotsUI
import SwiftUI

/// Capture popover: paste a link and the full article text is fetched and
/// saved as a source; paywalled or offline material comes in as pasted text.
/// Model-blind — values in, callbacks out.
struct SourceCaptureView: View {
    let error: String?
    let isCapturing: Bool
    let onSubmitText: (_ title: String, _ text: String) -> Void
    let onSubmitURL: (String) -> Void

    @State private var isPastingText = false
    @State private var pastedText = ""
    @State private var titleDraft = ""
    @State private var urlDraft = ""

    @FocusState private var isURLFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.sm) {
            DotsMetaLabel("SAVE A SOURCE")

            if isPastingText {
                pasteFields
            } else {
                urlField
            }

            if let error {
                Text(error)
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Accent.orange)
            }

            HStack {
                Button(isPastingText ? "Paste a link instead" : "Paste text instead") {
                    isPastingText.toggle()
                }
                .buttonStyle(.plain)
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.Ink.muted)

                Spacer()

                if isCapturing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Save", action: submit)
                        .buttonStyle(.plain)
                        .font(DotsTypography.callout)
                        .foregroundStyle(DotsColor.brand)
                }
            }
        }
        .padding(DotsSpacing.md)
        .frame(width: 340)
        .onAppear { isURLFocused = true }
    }

    private var urlField: some View {
        TextField("https://…", text: $urlDraft)
            .textFieldStyle(.plain)
            .font(DotsTypography.body)
            .foregroundStyle(DotsColor.Ink.primary)
            .focused($isURLFocused)
            .onSubmit(submit)
            .padding(DotsSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DotsRadius.Semantic.control, style: .continuous)
                    .fill(DotsColor.Surface.control)
            )
    }

    private var pasteFields: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.xs) {
            TextField("Title", text: $titleDraft)
                .textFieldStyle(.plain)
                .font(DotsTypography.body)
                .foregroundStyle(DotsColor.Ink.primary)

            TextEditor(text: $pastedText)
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.Ink.secondary)
                .scrollContentBackground(.hidden)
                .frame(height: 140)
                .padding(DotsSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: DotsRadius.Semantic.control, style: .continuous)
                        .fill(DotsColor.Surface.control)
                )
        }
    }

    private func submit() {
        if isPastingText {
            onSubmitText(titleDraft, pastedText)
        } else {
            onSubmitURL(urlDraft)
        }
    }
}
