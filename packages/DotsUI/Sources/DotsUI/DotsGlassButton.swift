public import SwiftUI

/// A small, almost-transparent glass control for use over rich backdrops (e.g.
/// the hero shader). Adopts Liquid Glass. Round by intent — a floating utility
/// affordance, not a content button.
public struct DotsGlassButton: View {
    private let systemName: String
    private let diameter: CGFloat
    private let accessibilityLabel: String
    private let action: () -> Void

    public init(
        systemName: String,
        diameter: CGFloat = 44,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.diameter = diameter
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: diameter * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(glass)
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var glass: some View {
        Circle().fill(.clear).glassEffect(.regular, in: .circle)
    }
}

#Preview("Glass Button") {
    ZStack {
        DotsHeroShaderView(.halftone).ignoresSafeArea()
        DotsGlassButton(systemName: "arrow.right", accessibilityLabel: "Next") {}
    }
}
