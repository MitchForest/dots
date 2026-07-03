import DotsDomain
import DotsUI
import SwiftUI

/// An idea row opened in place — the sidebar accordion. Full content,
/// editable inline with autosave; collapse via the chevron or by opening
/// another row. Model-blind.
struct IdeaExpandedRowView: View {
    let dot: Dot
    let folders: [String]
    let selectionContext: DotSelectionContext

    let onCollapse: () -> Void
    let onDelete: () -> Void
    let onEdit: (_ content: String, _ tags: [String]) -> Void
    let onMove: (String?) -> Void

    @State private var content = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var tagsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.sm) {
            HStack(spacing: DotsSpacing.xs) {
                DotProvenanceGlyph(isExtraction: dot.isExtraction)
                DotsMetaLabel(
                    dot.capturedAt.formatted(date: .abbreviated, time: .omitted).uppercased()
                )
                Spacer(minLength: 0)
                Button(action: collapse) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DotsColor.Ink.muted)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Collapse (esc)")
            }

            TextEditor(text: $content)
                .font(DotsTypography.body)
                .lineSpacing(3)
                .foregroundStyle(DotsColor.Ink.primary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90, maxHeight: 220)
                .fixedSize(horizontal: false, vertical: true)

            TextField("tags, comma separated", text: $tagsText)
                .textFieldStyle(.plain)
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.Ink.secondary)
                .onSubmit(saveNow)
        }
        .padding(DotsSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                .fill(DotsColor.Surface.canvas)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                .strokeBorder(DotsColor.brand, lineWidth: 1.5)
        )
        .contextMenu {
            MoveToFolderMenu(current: dot.folder, folders: folders, onMove: onMove)
            DotSelectionMenuItems(dot: dot, context: selectionContext)
            Divider()
            DotDeleteMenuItem(dot: dot, context: selectionContext, onDelete: onDelete)
        }
        .onChange(of: dot.id, initial: true) {
            saveTask?.cancel()
            content = dot.content
            tagsText = dot.tags.joined(separator: ", ")
        }
        .onChange(of: content) {
            scheduleSave()
        }
        .onDisappear {
            saveTask?.cancel()
            saveNow()
        }
    }

    private func collapse() {
        saveTask?.cancel()
        saveNow()
        onCollapse()
    }

    private func scheduleSave() {
        guard content != dot.content else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    private func saveNow() {
        var seen = Set<String>()
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        guard content != dot.content || tags != dot.tags else { return }
        onEdit(content, tags)
    }
}
