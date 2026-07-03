import AppKit
import DotsDomain
import DotsUI
import SwiftUI

/// The reading room: a saved source rendered full-pane. Select text and
/// extract it as a verbatim dot, or distill the idea in your own words —
/// both stay anchored to the source. Model-blind.
struct SourceReaderView: View {
    let source: Source
    /// Dots already extracted or distilled from this source.
    let extractedCount: Int
    let onClose: () -> Void
    let onDelete: () -> Void
    let onDistill: (_ content: String, _ tags: [String]) -> Void
    let onExtract: (_ excerpt: String) -> Void

    @State private var isDistillPresented = false
    @State private var selectedText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .overlay(DotsColor.Background.hairline)
            SelectableTextView(text: source.content, selectedText: $selectedText)
            Divider()
                .overlay(DotsColor.Background.hairline)
            actionBar
        }
        .background(DotsColor.Background.primary)
    }

    private var header: some View {
        HStack(spacing: DotsSpacing.md) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DotsColor.Ink.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Back to ideas (esc)")

            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                    .font(DotsTypography.headline)
                    .foregroundStyle(DotsColor.Ink.primary)
                    .lineLimit(1)
                DotsMetaLabel(headerMeta)
            }

            Spacer()

            if let url = source.url {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DotsColor.Ink.muted)
                }
                .help("Open the original")
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DotsColor.Ink.muted)
            }
            .buttonStyle(.plain)
            .help("Delete this source (extracted dots stay)")
        }
        .padding(.horizontal, DotsSpacing.lg)
        .padding(.vertical, DotsSpacing.md)
    }

    private var headerMeta: String {
        var parts: [String] = []
        if let author = source.author {
            parts.append(author.uppercased())
        }
        if let site = source.site {
            parts.append(site.uppercased())
        }
        parts.append(
            source.capturedAt.formatted(date: .abbreviated, time: .omitted).uppercased()
        )
        return parts.joined(separator: " · ")
    }

    /// Pane chrome by doctrine: the extraction verbs float with the reading,
    /// not in the window titlebar.
    private var actionBar: some View {
        HStack(spacing: DotsSpacing.lg) {
            DotsMetaLabel(
                extractedCount == 0
                    ? "SELECT TEXT TO EXTRACT"
                    : "\(extractedCount) DOT\(extractedCount == 1 ? "" : "S") FROM THIS SOURCE"
            )

            Spacer()

            Button {
                onExtract(selectedText)
            } label: {
                Label("Extract dot", systemImage: "quote.opening")
                    .font(DotsTypography.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                selectedText.isEmpty ? DotsColor.Ink.muted : DotsColor.brand
            )
            .disabled(selectedText.isEmpty)
            .help("Save the selection as a verbatim dot")

            Button {
                isDistillPresented = true
            } label: {
                Label("Distill…", systemImage: "circle.lefthalf.filled")
                    .font(DotsTypography.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DotsColor.brand)
            .help("Write the idea in your own words")
            .popover(isPresented: $isDistillPresented, arrowEdge: .top) {
                DotEditorView(
                    dot: Dot(
                        id: Dot.ID("distill-draft"),
                        content: "",
                        capturedAt: source.capturedAt
                    ),
                    onSave: { content, tags in
                        isDistillPresented = false
                        onDistill(content, tags)
                    },
                    onCancel: { isDistillPresented = false }
                )
            }
        }
        .padding(.horizontal, DotsSpacing.lg)
        .padding(.vertical, DotsSpacing.sm)
    }
}

/// Read-only, selectable text — an NSTextView so the selection is actually
/// reachable (SwiftUI's `.textSelection` offers no programmatic access).
struct SelectableTextView: NSViewRepresentable {
    let text: String
    @Binding var selectedText: String

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedText: $selectedText)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.autoresizingMask = [.width]
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isRichText = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 48, height: 28)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        apply(text: text, to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              textView.string != text
        else { return }
        apply(text: text, to: textView)
    }

    private func apply(text: String, to textView: NSTextView) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        paragraph.paragraphSpacing = 10
        textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: text,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 14),
                    .foregroundColor: NSColor.textColor,
                    .paragraphStyle: paragraph
                ]
            )
        )
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let selectedText: Binding<String>

        init(selectedText: Binding<String>) {
            self.selectedText = selectedText
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            let text = textView.string as NSString
            let selection = range.length > 0 ? text.substring(with: range) : ""
            if selectedText.wrappedValue != selection {
                selectedText.wrappedValue = selection
            }
        }
    }
}

/// One saved source as a list row: title · site · date. Click to read,
/// right-click for actions.
struct SourceRowView: View {
    let source: Source
    let folders: [String]
    let isSelected: Bool
    let onDelete: () -> Void
    let onDeleteSelection: () -> Void
    let onMove: (String?) -> Void
    let onOpen: () -> Void
    /// How many rows the selection holds when this row is part of it;
    /// 0 or 1 means delete acts on this row alone.
    let selectionCount: Int

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: DotsSpacing.md) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DotsColor.Ink.muted)

                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(DotsTypography.body)
                        .foregroundStyle(DotsColor.Ink.primary)
                        .lineLimit(1)
                    DotsMetaLabel(
                        [
                            source.site?.uppercased(),
                            source.capturedAt.formatted(date: .abbreviated, time: .omitted)
                                .uppercased()
                        ]
                        .compactMap(\.self)
                        .joined(separator: " · ")
                    )
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DotsColor.Ink.muted)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(DotsSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                    .fill(isHovered ? DotsColor.Surface.pressed : DotsColor.Surface.canvas)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                    .strokeBorder(
                        isSelected ? DotsColor.brand : DotsColor.Background.hairline,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            MoveToFolderMenu(current: source.folder, folders: folders, onMove: onMove)
            Divider()
            if selectionCount > 1 {
                Button(role: .destructive) {
                    onDeleteSelection()
                } label: {
                    Label("Delete \(selectionCount) sources", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onHover { isHovered = $0 }
    }
}
