public import SwiftUI

/// The canonical content card surface: a filled rounded rectangle with a single
/// hairline border at the `card` radius. It is a *surface*, not a button — wrap
/// it in a `Button { } .buttonStyle(.plain)` when the whole card is tappable
/// Keeps every card in the app on one fill, one border,
/// one radius, one default padding.
public struct DotsCard<Content: View>: View {
    private let padding: CGFloat
    private let fill: Color
    private let radius: CGFloat
    private let borderColor: Color
    private let alignment: Alignment
    private let minHeight: CGFloat?
    private let fillHeight: Bool
    @ViewBuilder private let content: () -> Content

    public init(
        padding: CGFloat = DotsSpacing.lg,
        fill: Color = DotsColor.Surface.control,
        radius: CGFloat = DotsRadius.Semantic.card,
        borderColor: Color = DotsColor.Neutral.hairline,
        alignment: Alignment = .topLeading,
        minHeight: CGFloat? = nil,
        fillHeight: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.fill = fill
        self.radius = radius
        self.borderColor = borderColor
        self.alignment = alignment
        self.minHeight = minHeight
        self.fillHeight = fillHeight
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .frame(
                maxWidth: .infinity,
                minHeight: minHeight,
                maxHeight: fillHeight ? .infinity : nil,
                alignment: alignment
            )
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.75)
            )
    }
}

#Preview {
    VStack(spacing: DotsSpacing.md) {
        DotsCard {
            VStack(alignment: .leading, spacing: DotsSpacing.xs) {
                Text("Linear equations")
                    .font(DotsTypography.titleSmall)
                    .foregroundStyle(DotsColor.Neutral.inkPrimary)
                Text("Solve for the unknown by keeping both sides balanced.")
                    .font(DotsTypography.body)
                    .foregroundStyle(DotsColor.Neutral.inkSecondary)
            }
        }
    }
    .padding(DotsSpacing.xl)
    .frame(maxWidth: 360)
    .background(DotsTheme.paperBase)
}
