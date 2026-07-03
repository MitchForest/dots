import DotsDomain
import SwiftUI

/// What the current selection means for a right-clicked dot, plus the
/// selection-scoped actions. Contextual by doctrine: these never live in a
/// permanent bar.
struct DotSelectionContext {
    let isSelectionFullyConnected: Bool
    let selectedIDs: [Dot.ID]
    /// True when a draft is open beside the panel — the send verb becomes
    /// "Add to this draft" instead of "Send to a new draft".
    let sendsToOpenDraft: Bool

    let onConnectSelection: () -> Void
    let onDeleteSelection: () -> Void
    let onDisconnectSelection: () -> Void
    let onDraftFromSelection: () -> Void
    let onDraftFromDot: (Dot) -> Void
    let onSynthesizeSelection: () -> Void
}

/// Selection-aware context-menu section shared by canvas cards and list rows.
struct DotSelectionMenuItems: View {
    let dot: Dot
    let context: DotSelectionContext

    private var isInSelection: Bool {
        context.selectedIDs.contains(dot.id)
    }

    private var selectionCount: Int {
        context.selectedIDs.count
    }

    var body: some View {
        Divider()

        if isInSelection, selectionCount >= 1 {
            Button {
                context.onDraftFromSelection()
            } label: {
                Label(
                    context.sendsToOpenDraft
                        ? "Add \(selectionCount) idea\(selectionCount == 1 ? "" : "s") to this draft"
                        : "Send \(selectionCount) idea\(selectionCount == 1 ? "" : "s") to a new draft",
                    systemImage: "square.and.pencil"
                )
            }
        } else {
            Button {
                context.onDraftFromDot(dot)
            } label: {
                Label(
                    context.sendsToOpenDraft
                        ? "Add this idea to the draft"
                        : "Send this idea to a new draft",
                    systemImage: "square.and.pencil"
                )
            }
        }

        if isInSelection, selectionCount >= 2 {
            Button {
                context.onSynthesizeSelection()
            } label: {
                Label(
                    "Synthesize \(selectionCount) dots into a new idea",
                    systemImage: "arrow.triangle.merge"
                )
            }

            if context.isSelectionFullyConnected {
                Button {
                    context.onDisconnectSelection()
                } label: {
                    Label("Disconnect \(selectionCount) dots", systemImage: "point.topleft.down.curvedto.point.bottomright.up.fill")
                }
            } else {
                Button {
                    context.onConnectSelection()
                } label: {
                    Label("Connect \(selectionCount) dots", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                }
            }
        }
    }
}

/// Delete, Finder-retargeted: acts on the whole selection when the
/// right-clicked dot is part of it, otherwise on just that dot.
struct DotDeleteMenuItem: View {
    let dot: Dot
    let context: DotSelectionContext
    let onDelete: () -> Void

    var body: some View {
        let count = context.selectedIDs.count
        if context.selectedIDs.contains(dot.id), count > 1 {
            Button(role: .destructive) {
                context.onDeleteSelection()
            } label: {
                Label("Delete \(count) ideas", systemImage: "trash")
            }
        } else {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
