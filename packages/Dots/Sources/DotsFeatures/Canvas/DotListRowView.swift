import AppKit
import DotsDomain
import DotsEngine
import DotsUI
import SwiftUI

/// One idea as a list row: title (first line) · snippet · meta. Click
/// selects (the detail pane shows it), ⌘-click multi-selects, right-click
/// for actions. Model-blind.
struct DotListRowView: View {
    static func selectionModifier() -> Ideas.SelectionModifier {
        if NSEvent.modifierFlags.contains(.shift) { return .range }
        if NSEvent.modifierFlags.contains(.command) { return .toggle }
        return .none
    }

    let dot: Dot
    let folders: [String]
    let isConnectedToSelection: Bool
    let isSelected: Bool
    let selectionContext: DotSelectionContext
    let onDelete: () -> Void
    let onMove: (String?) -> Void
    let onTap: (_ modifier: Ideas.SelectionModifier) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DotsSpacing.md) {
            DotProvenanceGlyph(isExtraction: dot.isExtraction)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(DotPreview.title(dot.content))
                    .font(DotsTypography.headline)
                    .foregroundStyle(DotsColor.Ink.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)

                let snippet = DotPreview.snippet(dot.content)
                if !snippet.isEmpty {
                    Text(snippet)
                        .font(DotsTypography.footnote)
                        .foregroundStyle(DotsColor.Ink.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: DotsSpacing.sm) {
                    DotsMetaLabel(
                        dot.capturedAt.formatted(date: .abbreviated, time: .omitted).uppercased()
                    )
                    if !dot.references.isEmpty {
                        DotsMetaLabel("\(dot.references.count) ↝", tint: DotsColor.Ink.muted)
                    }
                }

                if !dot.tags.isEmpty {
                    DotTagChipsView(tags: dot.tags, wraps: true)
                }
            }

            Spacer(minLength: 0)
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
        .overlay(alignment: .leading) {
            // Connectivity accent: rows referenced by / referencing the
            // selection carry the brand edge — the list's answer to the
            // canvas's beziers.
            if isConnectedToSelection {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DotsColor.brand)
                    .frame(width: 3)
                    .padding(.vertical, DotsSpacing.xs)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous))
        .onTapGesture {
            onTap(Self.selectionModifier())
        }
        .contextMenu {
            MoveToFolderMenu(current: dot.folder, folders: folders, onMove: onMove)
            DotSelectionMenuItems(dot: dot, context: selectionContext)
            Divider()
            DotDeleteMenuItem(dot: dot, context: selectionContext, onDelete: onDelete)
        }
        .onHover { isHovered = $0 }
    }
}

/// Shared "Move to folder" submenu for ideas and sources.
struct MoveToFolderMenu: View {
    let current: String?
    let folders: [String]
    let onMove: (String?) -> Void

    var body: some View {
        Menu {
            Button {
                onMove(nil)
            } label: {
                if current == nil {
                    Label("Inbox", systemImage: "checkmark")
                } else {
                    Text("Inbox")
                }
            }
            ForEach(folders, id: \.self) { folder in
                Button {
                    onMove(folder)
                } label: {
                    if current == folder {
                        Label(folder, systemImage: "checkmark")
                    } else {
                        Text(folder)
                    }
                }
            }
        } label: {
            Label("Move to", systemImage: "folder")
        }
    }
}
