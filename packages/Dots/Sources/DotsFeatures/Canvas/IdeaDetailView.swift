import DotsDomain
import DotsUI
import SwiftUI

/// The detail pane for an idea: a calm, full-size editor with provenance,
/// tags, and the reference graph (references + computed backlinks) as a
/// quiet footer. Model-blind — data in, callbacks out.
struct IdeaDetailView: View {
    /// A resolved reference, ready to render: what it points at and how to
    /// label it.
    struct ReferenceItem: Identifiable {
        let reference: Reference
        let title: String
        let isSource: Bool

        var id: String { reference.rawValue }
    }

    let dot: Dot
    let backlinks: [ReferenceItem]
    let references: [ReferenceItem]
    let sourceTitle: String?

    let onEdit: (_ content: String, _ tags: [String]) -> Void
    let onMakeMine: () -> Void
    let onOpen: (ReferenceItem) -> Void
    let onRemoveReference: (Reference) -> Void

    @State private var content = ""
    @State private var lastAdopted = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var tagsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            provenanceBar
                .padding(.horizontal, DotsSpacing.xl)
                .padding(.vertical, DotsSpacing.md)

            TextEditor(text: $content)
                .font(DotsTypography.body)
                .lineSpacing(4)
                .foregroundStyle(DotsColor.Ink.primary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, DotsSpacing.lg)

            footer
        }
        .background(DotsColor.Background.primary)
        .onChange(of: dot.id, initial: true) {
            saveTask?.cancel()
            content = dot.content
            lastAdopted = dot.content
            tagsText = dot.tags.joined(separator: ", ")
        }
        .onChange(of: dot.content) { previous, latest in
            // An outside write to the same idea (dictation, another
            // window): adopt it only while the editor is clean — it
            // matches what the idea just was — so typing never gets
            // clobbered, and never clobbers the outside write back.
            guard content == previous || content == lastAdopted, content != latest else { return }
            saveTask?.cancel()
            content = latest
            lastAdopted = latest
        }
        .onChange(of: content) {
            scheduleSave()
        }
        .onDisappear {
            saveTask?.cancel()
            saveNow()
        }
    }

    // MARK: Provenance

    @ViewBuilder private var provenanceBar: some View {
        HStack(spacing: DotsSpacing.sm) {
            DotProvenanceGlyph(isExtraction: dot.isExtraction)
            if dot.isExtraction {
                DotsMetaLabel(
                    "EXTRACTED\(sourceTitle.map { " FROM \($0.uppercased())" } ?? "")"
                )
                Button("Make this mine") {
                    onMakeMine()
                }
                .buttonStyle(.plain)
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.brand)
                .help("You've rewritten it in your own words — reclassify as authored; the source stays as a reference")
            } else {
                DotsMetaLabel(
                    "YOURS · \(dot.capturedAt.formatted(date: .abbreviated, time: .omitted).uppercased())"
                )
            }
            Spacer()
        }
    }

    // MARK: Footer — tags + graph

    private var footer: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.sm) {
            Divider()
                .overlay(DotsColor.Background.hairline)

            TextField("tags, comma separated", text: $tagsText)
                .textFieldStyle(.plain)
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.Ink.secondary)
                .onSubmit(saveNow)

            if !references.isEmpty {
                DotsMetaLabel("REFERENCES")
                referenceRows(references, removable: true)
            }

            if !backlinks.isEmpty {
                DotsMetaLabel("REFERENCED BY")
                referenceRows(backlinks, removable: false)
            }
        }
        .padding(.horizontal, DotsSpacing.xl)
        // The window's bottom-right corner belongs to the mic FAB; the
        // footer ends before it.
        .padding(.trailing, 40)
        .padding(.vertical, DotsSpacing.md)
    }

    private func referenceRows(_ items: [ReferenceItem], removable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                HStack(spacing: DotsSpacing.xs) {
                    Button {
                        onOpen(item)
                    } label: {
                        HStack(spacing: DotsSpacing.xs) {
                            Image(systemName: item.isSource ? "doc.text" : "circle.fill")
                                .font(.system(size: item.isSource ? 10 : 6))
                                .foregroundStyle(DotsColor.Ink.muted)
                            Text(item.title)
                                .font(DotsTypography.footnote)
                                .foregroundStyle(DotsColor.Ink.secondary)
                                .lineLimit(1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Open")

                    if removable {
                        Button {
                            onRemoveReference(item.reference)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(DotsColor.Ink.muted)
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Remove reference")
                    }
                }
            }
        }
    }

    // MARK: Saving

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
        let trimmed = content
        guard trimmed != dot.content || tags != dot.tags else { return }
        onEdit(trimmed, tags)
    }
}
