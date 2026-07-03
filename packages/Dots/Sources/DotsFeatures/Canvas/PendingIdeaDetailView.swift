import DotsDomain
import DotsUI
import SwiftUI

/// The detail pane for a pending drafted idea: the full text with its
/// provenance-to-be, and the verdict — accept it into the vault or discard
/// it. Deliberately read-only: editing happens after the idea is real.
/// Model-blind.
struct PendingIdeaDetailView: View {
    let pending: Ideas.PendingIdea
    let onAccept: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DotsSpacing.sm) {
                DotsMetaLabel("PROPOSED", tint: DotsColor.brand)
                if let source = pending.source {
                    DotsMetaLabel("FROM \(source.title.uppercased())", tint: DotsColor.Ink.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DotsSpacing.xl)
            .padding(.vertical, DotsSpacing.md)

            ScrollView {
                Text(pending.idea.text)
                    .font(DotsTypography.body)
                    .lineSpacing(4)
                    .foregroundStyle(DotsColor.Ink.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DotsSpacing.xl)
            }

            HStack(spacing: DotsSpacing.sm) {
                Button(action: onAccept) {
                    Label("Accept", systemImage: "checkmark")
                        .font(DotsTypography.footnote)
                }
                .buttonStyle(.borderedProminent)
                .tint(DotsColor.brand)
                .help("Save as an idea from this source")

                Button(action: onDiscard) {
                    Label("Discard", systemImage: "xmark")
                        .font(DotsTypography.footnote)
                }
                .buttonStyle(.bordered)
                .help("Discard this draft")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DotsSpacing.xl)
            .padding(.vertical, DotsSpacing.md)
        }
        .background(DotsColor.Background.primary)
    }
}

#Preview {
    PendingIdeaDetailView(
        pending: Ideas.PendingIdea(
            idea: ProposedIdea(
                id: 1,
                text: "Attention is the scarcest resource in modern work, and calendars systematically misprice it."
            ),
            proposalId: IdeaProposal.ID("01PROPOSAL"),
            source: Source(
                id: Source.ID("01SOURCE"),
                title: "Maker's Schedule, Manager's Schedule",
                content: "…",
                capturedAt: .now
            )
        ),
        onAccept: {},
        onDiscard: {}
    )
    .frame(width: 420, height: 320)
}
