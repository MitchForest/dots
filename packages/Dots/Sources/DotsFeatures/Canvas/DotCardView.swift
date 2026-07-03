import AppKit
import DotsDomain
import DotsUI
import SwiftUI

/// Shared coordinate space for the canvas content: card drags and connect
/// drags measure against this stable space (measuring in the card's own
/// moving space feeds back into itself and jitters).
enum CanvasSpace {
    static let name = "dots-canvas"
}

/// One dot on the canvas. Tap selects, ⌘-tap multi-selects, drag moves,
/// double-click edits, right-click for actions, edge-port drag connects.
/// Fresh dots (`startsEditing`) open straight into the editor with their
/// placeholder selected. Model-blind — data in, callbacks out.
struct DotCardView: View {
    let dot: Dot
    let isSelected: Bool
    let selectionContext: DotSelectionContext
    let startsEditing: Bool

    let onConnectDragChanged: (CGPoint) -> Void
    let onConnectDragEnded: (CGPoint) -> Void
    let onDelete: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void
    let onEdit: (_ content: String, _ tags: [String]) -> Void
    let onTap: (_ modifier: Ideas.SelectionModifier) -> Void

    @State private var didAutoOpen = false
    @State private var isEditPresented = false
    @State private var isHovered = false

    static let cardSize = CGSize(width: 240, height: 120)

    var body: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.xs) {
            HStack(spacing: DotsSpacing.xs) {
                DotProvenanceGlyph(isExtraction: dot.isExtraction)
                DotsMetaLabel(
                    dot.capturedAt.formatted(date: .abbreviated, time: .omitted).uppercased()
                )
                Spacer(minLength: 0)
                if !dot.references.isEmpty {
                    DotsMetaLabel("\(dot.references.count) ↝", tint: DotsColor.Ink.muted)
                        .help("References \(dot.references.count) thing\(dot.references.count == 1 ? "" : "s")")
                }
            }

            Text(dot.content)
                .font(DotsTypography.body)
                .lineSpacing(3)
                .foregroundStyle(DotsColor.Ink.primary)
                .lineLimit(dot.tags.isEmpty ? 4 : 3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if !dot.tags.isEmpty {
                DotTagChipsView(tags: dot.tags)
            }
        }
        .padding(DotsSpacing.md)
        .frame(width: Self.cardSize.width, height: Self.cardSize.height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                .fill(DotsColor.Surface.canvas)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                .strokeBorder(
                    isSelected ? DotsColor.brand : DotsColor.Background.hairline,
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
        .dotsElevation(.floating)
        .scaleEffect(isHovered ? 1.015 : 1)
        .animation(.spring(duration: 0.25), value: isHovered)
        .animation(.spring(duration: 0.25), value: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous))
        .onTapGesture {
            // AppKit's click count is the ground truth on macOS: click
            // selects, double-click opens the dot for editing.
            if NSApp.currentEvent?.clickCount == 2 {
                isEditPresented = true
            } else {
                onTap(DotListRowView.selectionModifier())
            }
        }
        .contextMenu {
            Button {
                isEditPresented = true
            } label: {
                Label("Edit…", systemImage: "pencil")
            }
            DotSelectionMenuItems(dot: dot, context: selectionContext)
            Divider()
            DotDeleteMenuItem(dot: dot, context: selectionContext, onDelete: onDelete)
        }
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named(CanvasSpace.name))
                .onChanged { onDragChanged($0.translation) }
                .onEnded { onDragEnded($0.translation) }
        )
        .overlay(alignment: .trailing) {
            connectPort
                .offset(x: 7)
                .opacity(isHovered || isSelected ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isHovered || isSelected)
        }
        .onHover { isHovered = $0 }
        .popover(isPresented: $isEditPresented, arrowEdge: .bottom) {
            DotEditorView(
                dot: dot,
                onSave: { content, tags in
                    isEditPresented = false
                    onEdit(content, tags)
                },
                onCancel: { isEditPresented = false }
            )
        }
        .onAppear {
            if startsEditing, !didAutoOpen {
                didAutoOpen = true
                isEditPresented = true
            }
        }
        .help("Click to select · double-click to edit · right-click for actions · drag the edge port to connect")
    }

    /// The connection handle: drag from here onto another dot to link them.
    private var connectPort: some View {
        ZStack {
            Circle()
                .fill(DotsColor.Background.primary)
            Circle()
                .strokeBorder(DotsColor.brand, lineWidth: 1.5)
            Image(systemName: "arrow.right")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(DotsColor.brand)
        }
        .frame(width: 16, height: 16)
        // The visible handle stays small; the grabbable area meets the
        // 28pt hit-target floor.
        .contentShape(Circle().inset(by: -6))
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named(CanvasSpace.name))
                .onChanged { onConnectDragChanged($0.location) }
                .onEnded { onConnectDragEnded($0.location) }
        )
        .help("Drag to connect")
    }
}

/// Small rectangular tag chips, content-hugging. Wrapping mode flows onto
/// multiple rows; the fixed-geometry canvas cards use the truncated single
/// row instead.
struct DotTagChipsView: View {
    let tags: [String]
    var wraps = false

    var body: some View {
        if wraps {
            DotsFlowLayout {
                ForEach(tags, id: \.self) { tag in
                    chip(tag)
                }
            }
        } else {
            HStack(spacing: DotsSpacing.xs) {
                ForEach(tags.prefix(3), id: \.self) { tag in
                    chip(tag)
                }
                if tags.count > 3 {
                    Text("+\(tags.count - 3)")
                        .font(DotsTypography.caption)
                        .foregroundStyle(DotsColor.Ink.muted)
                }
            }
        }
    }

    private func chip(_ tag: String) -> some View {
        Text(tag)
            .font(DotsTypography.caption)
            .foregroundStyle(DotsColor.Ink.secondary)
            .padding(.horizontal, DotsSpacing.xs)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DotsColor.Surface.control)
            )
    }
}

/// Provenance at a glance — binary and automatic: filled brand dot = your
/// words, hollow = extracted from a source.
struct DotProvenanceGlyph: View {
    let isExtraction: Bool

    var body: some View {
        Group {
            if isExtraction {
                Circle()
                    .strokeBorder(DotsColor.brand, lineWidth: 1.2)
            } else {
                Circle()
                    .fill(DotsColor.brand)
            }
        }
        .frame(width: 7, height: 7)
        .help(isExtraction ? "Extracted — someone else's words" : "Authored — yours")
        .accessibilityLabel(isExtraction ? "Extracted from a source" : "Authored by you")
    }
}
