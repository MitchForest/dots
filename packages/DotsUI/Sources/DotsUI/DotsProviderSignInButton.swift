public import SwiftUI

/// A full-width sign-in control. Apple uses an ink-filled button; Google uses a
/// neutral elevated surface with a hairline so the multicolor mark carries the
/// color.
public struct DotsProviderSignInButton: View {
    public enum Mark: Sendable {
        case apple
        case google
        case symbol(String)
    }

    public enum Style: Sendable {
        case filled
        case elevated
    }

    private let title: String
    private let accessibilityLabel: String
    private let mark: Mark?
    private let style: Style
    private let action: () -> Void

    public init(
        title: String,
        accessibilityLabel: String,
        mark: Mark? = nil,
        style: Style,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.mark = mark
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DotsSpacing.sm) {
                if mark != nil {
                    glyph
                        .frame(width: 20, height: 20)
                }
                Text(title)
                    .font(DotsTypography.headline)
                    .foregroundStyle(foreground)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous))
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder private var glyph: some View {
        switch mark {
        case .none:
            EmptyView()
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(foreground)
                .accessibilityHidden(true)
        case .google:
            DotsGoogleGlyph()
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(foreground)
                .accessibilityHidden(true)
        }
    }

    private var background: Color {
        switch style {
        case .filled: DotsColor.Ink.primary
        case .elevated: DotsColor.Background.elevated
        }
    }

    private var foreground: Color {
        switch style {
        case .filled: DotsColor.Ink.inverse
        case .elevated: DotsColor.Ink.primary
        }
    }

    private var borderColor: Color {
        switch style {
        case .filled: .clear
        case .elevated: DotsColor.Background.hairline
        }
    }
}

#Preview("Provider Buttons") {
    VStack(spacing: DotsSpacing.md) {
        DotsProviderSignInButton(
            title: "Continue with Apple",
            accessibilityLabel: "Sign in with Apple",
            mark: .apple,
            style: .filled
        ) {}
        DotsProviderSignInButton(
            title: "Continue with Google",
            accessibilityLabel: "Sign in with Google",
            mark: .google,
            style: .elevated
        ) {}
    }
    .padding(DotsSpacing.xxl)
    .background(DotsColor.Background.primary)
}
