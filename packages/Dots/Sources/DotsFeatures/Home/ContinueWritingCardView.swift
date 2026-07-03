import DotsDomain
import DotsUI
import SwiftUI

/// Home's primary object: the most recent draft, calm and inviting — with
/// the same contextual menu every other draft row has, so even the last
/// remaining draft can be renamed, revealed, or deleted. Model-blind.
struct ContinueWritingCardView: View {
    let document: VaultDocument
    let onDelete: () -> Void
    let onOpen: () -> Void
    let onRename: (String) -> Void
    let onReveal: () -> Void

    @State private var isHovered = false
    @State private var isRenamePresented = false
    @State private var renameText = ""

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: DotsSpacing.xs) {
                DotsMetaLabel("CONTINUE WRITING", tint: DotsColor.Ink.muted)
                    .padding(.bottom, DotsSpacing.xs)

                Text(document.title)
                    .font(DotsTypography.title)
                    .foregroundStyle(DotsColor.Ink.primary)
                    .lineLimit(1)

                Text(document.modifiedAt.formatted(.relative(presentation: .named)))
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.muted)
            }
            .padding(DotsSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                    .fill(DotsColor.Surface.canvas)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                    .strokeBorder(
                        isHovered ? DotsColor.brand : DotsColor.Background.hairline,
                        lineWidth: isHovered ? 1 : 0.5
                    )
            )
            .dotsElevation(.floating)
            .scaleEffect(isHovered ? 1.004 : 1)
            .animation(.spring(duration: 0.3), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                renameText = document.title
                isRenamePresented = true
            } label: {
                Label("Rename…", systemImage: "pencil")
            }
            Button {
                onReveal()
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .popover(isPresented: $isRenamePresented, arrowEdge: .bottom) {
            renameField
        }
        .accessibilityLabel("Continue writing \(document.title)")
    }

    private var renameField: some View {
        HStack(spacing: DotsSpacing.sm) {
            TextField("Title", text: $renameText)
                .textFieldStyle(.plain)
                .font(DotsTypography.body)
                .foregroundStyle(DotsColor.Ink.primary)
                .frame(width: 220)
                .onSubmit(submitRename)
            Button("Save", action: submitRename)
                .buttonStyle(.plain)
                .font(DotsTypography.callout)
                .foregroundStyle(DotsColor.brand)
        }
        .padding(DotsSpacing.md)
    }

    private func submitRename() {
        let title = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        isRenamePresented = false
        guard !title.isEmpty, title != document.title else { return }
        onRename(title)
    }
}
