import AppKit
import DotsDomain
import DotsUI
import SwiftUI

/// Recents row: a hairline card that opens a contextual popover on
/// double-click — rename, reveal, delete. Model-blind: data in, callbacks out.
struct DraftCardView: View {
    let document: VaultDocument
    let onDelete: () -> Void
    let onOpen: () -> Void
    let onRename: (String) -> Void
    let onReveal: () -> Void

    @State private var isRenamePresented = false
    @State private var renameText = ""

    var body: some View {
        DotsHairlineCard(
            title: document.title,
            metaLeading: document.modifiedAt.formatted(.relative(presentation: .named)).uppercased(),
            minHeight: 64
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
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

#Preview {
    DraftCardView(
        document: VaultDocument(
            url: URL(filePath: "/mock/drafts/why-we-write.md"),
            title: "Why we write",
            modifiedAt: Date(timeIntervalSince1970: 0)
        ),
        onDelete: {},
        onOpen: {},
        onRename: { _ in },
        onReveal: {}
    )
    .padding(DotsSpacing.xxl)
    .background(DotsColor.Background.primary)
}
