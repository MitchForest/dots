import DotsDomain
import DotsUI
import SwiftUI

/// One AI-drafted idea awaiting review, inline in the ideas list but
/// visibly provisional — brand-tinted fill, dashed edge: not a vault file
/// until the writer accepts it. Model-blind.
struct PendingIdeaRowView: View {
    let pending: Ideas.PendingIdea
    let isSelected: Bool
    let onAccept: () -> Void
    let onDiscard: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DotsSpacing.md) {
            // The row body opens the detail pane; the verdict buttons stay
            // their own targets.
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pending.idea.text)
                        .font(DotsTypography.body)
                        .foregroundStyle(DotsColor.Ink.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: DotsSpacing.sm) {
                        DotsMetaLabel("PROPOSED", tint: DotsColor.brand)
                        if let source = pending.source {
                            DotsMetaLabel(source.title.uppercased(), tint: DotsColor.Ink.muted)
                                .lineLimit(1)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            HStack(spacing: DotsSpacing.xs) {
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DotsColor.brand)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(DotsColor.brand.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("Accept — save as an idea from this source")

                Button(action: onDiscard) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DotsColor.Ink.muted)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(DotsColor.Surface.control))
                }
                .buttonStyle(.plain)
                .help("Discard this draft")
            }
        }
        .padding(DotsSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                .fill(DotsColor.brand.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                .strokeBorder(
                    DotsColor.brand.opacity(isSelected ? 1 : 0.45),
                    style: StrokeStyle(lineWidth: isSelected ? 1.5 : 1, dash: [4, 3])
                )
        )
    }
}

#Preview {
    VStack(spacing: DotsSpacing.xs) {
        PendingIdeaRowView(
            pending: Ideas.PendingIdea(
                idea: ProposedIdea(id: 1, text: "Attention is the scarcest resource in modern work, and calendars systematically misprice it."),
                proposalId: IdeaProposal.ID("01PROPOSAL"),
                source: Source(
                    id: Source.ID("01SOURCE"),
                    title: "Maker's Schedule, Manager's Schedule",
                    content: "…",
                    capturedAt: .now
                )
            ),
            isSelected: true,
            onAccept: {},
            onDiscard: {},
            onTap: {}
        )
        PendingIdeaRowView(
            pending: Ideas.PendingIdea(
                idea: ProposedIdea(id: 2, text: "Meetings cost makers half a day, not half an hour."),
                proposalId: IdeaProposal.ID("01PROPOSAL"),
                source: nil
            ),
            isSelected: false,
            onAccept: {},
            onDiscard: {},
            onTap: {}
        )
    }
    .padding()
    .frame(width: 360)
}
