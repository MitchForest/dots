import DotsUI
import SwiftUI

/// The doorway to Ideas from Home: a slim full-width strip — a destination
/// presented as a place, with a live count. Model-blind.
struct IdeasStripView: View {
    let dotCount: Int
    let onOpen: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: DotsSpacing.sm) {
                Circle()
                    .fill(DotsColor.brand)
                    .frame(width: 6, height: 6)

                DotsMetaLabel("IDEAS", tint: DotsColor.Ink.secondary)

                Text("\(dotCount) dot\(dotCount == 1 ? "" : "s")")
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.muted)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovered ? DotsColor.brand : DotsColor.Ink.muted)
            }
            .padding(.horizontal, DotsSpacing.md)
            .padding(.vertical, DotsSpacing.sm)
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
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .keyboardShortcut("k", modifiers: .command)
        .help("Open your ideas (⌘K)")
        .accessibilityLabel("Open ideas — \(dotCount) dots")
    }
}
