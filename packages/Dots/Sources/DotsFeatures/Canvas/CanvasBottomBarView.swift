import DotsUI
import SwiftUI

/// Canvas pane chrome, per the placement doctrine: a quiet zoom capsule
/// bottom-left (count · lock · zoom · fit) and the one prominent thing —
/// the glass + CTA — bottom-right. Model-blind.
struct CanvasBottomBarView: View {
    let dotCount: Int
    let showsViewportControls: Bool
    @Binding var isLocked: Bool
    let zoomPercent: Int

    let onFit: () -> Void
    let onNewDot: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                zoomCapsule
                Spacer()
                DotsGlassButton(
                    systemName: "plus",
                    accessibilityLabel: "New dot",
                    action: onNewDot
                )
                .keyboardShortcut("d", modifiers: .command)
                .help("New dot (⌘D) — or double-click the canvas")
            }
            .padding(DotsSpacing.md)
        }
    }

    private var zoomCapsule: some View {
        HStack(spacing: DotsSpacing.sm) {
            DotsMetaLabel("\(dotCount)")

            if showsViewportControls {
                capsuleDivider

                capsuleButton(
                    systemName: isLocked ? "lock.fill" : "lock.open",
                    label: isLocked ? "Unlock canvas" : "Lock canvas",
                    isActive: isLocked
                ) {
                    isLocked.toggle()
                }
                .help(isLocked ? "Unlock panning and zooming" : "Lock panning and zooming")

                capsuleDivider

                capsuleButton(systemName: "minus", label: "Zoom out", isActive: false, action: onZoomOut)
                    .keyboardShortcut("-", modifiers: .command)
                    .help("Zoom out (⌘−)")

                Text("\(zoomPercent)%")
                    .font(DotsTypography.Metric.countCompact)
                    .foregroundStyle(DotsColor.Ink.secondary)
                    .frame(minWidth: 40)

                capsuleButton(systemName: "plus", label: "Zoom in", isActive: false, action: onZoomIn)
                    .keyboardShortcut("=", modifiers: .command)
                    .help("Zoom in (⌘+)")

                capsuleDivider

                capsuleButton(systemName: "scope", label: "Fit all dots", isActive: false, action: onFit)
                    .keyboardShortcut("0", modifiers: .command)
                    .help("Fit all dots (⌘0)")
            }
        }
        .padding(.horizontal, DotsSpacing.md)
        .padding(.vertical, DotsSpacing.xs)
        .background(Capsule().fill(.regularMaterial))
    }

    private var capsuleDivider: some View {
        Rectangle()
            .fill(DotsColor.Background.hairline)
            .frame(width: 0.5, height: 14)
    }

    private func capsuleButton(
        systemName: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? DotsColor.brand : DotsColor.Ink.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
