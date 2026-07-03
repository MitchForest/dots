public import SwiftUI

/// Dots's button taxonomy (one place to look it up):
///
/// - **Primary glass action** — a labelled `Button` with `.buttonStyle(.glassProminent)`
///   and a semantic `.tint` (top-bar Check, completion overlay "Back to sets").
/// - **Neutral glass icon button** — `DotsGlassIconButton` (this type): a square
///   icon cell, `.glass` normally and `.glassProminent` + brand tint when selected.
///   Used by the lesson control rail, top-bar back, and Home chrome.
/// - **Plain content** — `Button { } .buttonStyle(.plain)` for tappable cards and
///   provider sign-in rows.
/// - **Floating-over-shader utility** — `DotsGlassButton` (round), for controls
///   that float directly on a hero shader (login).
///
/// Square by intent — tool/utility affordances are square cells; circles are
/// reserved for rings, status dots, and check medallions.
public struct DotsGlassIconButton: View {
    private let systemImage: String
    private let label: String
    private let isSelected: Bool
    private let isEnabled: Bool
    private let width: CGFloat
    private let height: CGFloat
    private let iconSize: CGFloat
    private let action: () -> Void

    public init(
        systemImage: String,
        label: String,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        width: CGFloat = 44,
        height: CGFloat = 44,
        iconSize: CGFloat = DotsIconSize.control,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = label
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.width = width
        self.height = height
        self.iconSize = iconSize
        self.action = action
    }

    public var body: some View {
        let button = Button(action: action) {
            DotsIcon(systemName: systemImage, size: iconSize)
                .frame(width: width, height: height)
        }
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])

        if isSelected {
            button
                .tint(DotsColor.brand)
                .buttonStyle(.glassProminent)
        } else {
            button
                .buttonStyle(.glass)
        }
    }
}

#Preview {
    HStack(spacing: DotsSpacing.sm) {
        DotsGlassIconButton(systemImage: "pencil.tip", label: "Pen", isSelected: true, width: 38, height: 38) {}
        DotsGlassIconButton(systemImage: "eraser", label: "Eraser", width: 38, height: 38) {}
        DotsGlassIconButton(systemImage: "arrow.uturn.backward", label: "Undo", isEnabled: false, width: 38, height: 38) {}
        DotsGlassIconButton(systemImage: "gearshape", label: "Settings", width: 38, height: 38) {}
    }
    .padding(DotsSpacing.xl)
    .background(DotsTheme.paperBase)
}
