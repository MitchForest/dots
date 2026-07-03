public import SwiftUI

/// The Dots mark: three equal circles in a row. Composition follows the
/// measured Noun Project principle: shapes are laid out by their CENTERS,
/// not their edges — a common horizontal center axis and even
/// center-to-center spacing. All three circles share one size so the mark
/// reads as a steady, rhythmic ellipsis: dot · dot · dot.
public struct DotsLogoMark: View {
    private let tint: Color
    /// The base unit: each circle's diameter.
    private let unit: CGFloat

    public init(tint: Color = DotsColor.Ink.primary, height: CGFloat = 22) {
        self.tint = tint
        self.unit = height
    }

    // Proportions (in units). Every circle is 1.0; spacing is the
    // center-to-center pitch, proportional to the height.
    private var pitch: CGFloat { unit * 1.44 }

    private var frameWidth: CGFloat { unit + pitch * 2 }
    private var frameHeight: CGFloat { unit }

    public var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let cxFirst = unit / 2

            for index in 0..<3 {
                let cx = cxFirst + pitch * CGFloat(index)
                context.fill(
                    Path(ellipseIn: CGRect(x: cx - unit / 2, y: midY - unit / 2, width: unit, height: unit)),
                    with: .color(tint)
                )
            }
        }
        .frame(width: frameWidth, height: frameHeight)
        .accessibilityElement()
        .accessibilityLabel("Dots")
    }
}

/// The Dots wordmark: the product name set in the display typography token.
/// Pairs with `DotsLogoMark` on entry and marketing surfaces.
public struct DotsWordmark: View {
    private let tint: Color

    public init(tint: Color = DotsColor.Ink.primary) {
        self.tint = tint
    }

    public var body: some View {
        Text("Dots")
            .font(DotsTypography.display)
            .foregroundStyle(tint)
            .accessibilityLabel("Dots")
    }
}

#Preview("Logo Mark") {
    VStack(spacing: DotsSpacing.xl) {
        DotsLogoMark()
        DotsLogoMark(tint: DotsColor.brand, height: 40)
        DotsLogoMark(tint: .white, height: 28)
            .padding(DotsSpacing.lg)
            .background(DotsColor.brand)
        DotsWordmark()
    }
    .padding(DotsSpacing.xxl)
    .background(DotsColor.Background.primary)
}
