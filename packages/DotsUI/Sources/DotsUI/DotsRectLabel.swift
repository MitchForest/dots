public import SwiftUI

/// The one chip primitive. A rounded-rect label with optional leading/trailing
/// content, a hairline (or semantic) border, and optional floating elevation.
/// Two shapes of use:
///
/// - **Plain chip** (default): neutral fill, hairline border, floating shadow —
///   the XP / "ready" / status chips on Home.
/// - **Semantic chip** (`init(size:semantic:systemImage:label:)`): a status
///   medallion + label tinted from a `DotsColor.Semantic`, a tinted border, and
///   no shadow — the in-canvas feedback note. See the constrained init below.
///
/// `DotsChip` is a typealias for this type; prefer it at call sites that read
/// as chips rather than as labels.
public struct DotsRectLabel<Leading: View, Trailing: View>: View {
    private let size: DotsControlSize
    private let background: Color
    private let foreground: Color
    private let label: String
    private let borderColor: Color
    private let borderWidth: CGFloat
    private let showsShadow: Bool
    @ViewBuilder private let leading: () -> Leading
    @ViewBuilder private let trailing: () -> Trailing

    public init(
        size: DotsControlSize = .md,
        background: Color = DotsColor.Neutral.chrome,
        foreground: Color = DotsColor.Neutral.inkPrimary,
        label: String,
        borderColor: Color = DotsColor.Neutral.hairline,
        borderWidth: CGFloat = 0.5,
        showsShadow: Bool = true,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.size = size
        self.background = background
        self.foreground = foreground
        self.label = label
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.showsShadow = showsShadow
        self.leading = leading
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: DotsSpacing.xs) {
            leading()
            Text(label)
                .font(.system(size: size.labelSize, weight: .semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
            trailing()
        }
        .padding(.horizontal, size.horizontalPadding)
        .frame(height: size.height)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .modifier(ConditionalElevation(isOn: showsShadow))
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .xs: DotsRadius.xs
        case .sm: DotsRadius.sm
        case .md, .lg: DotsRadius.Semantic.chip
        }
    }
}

/// Semantic chip: a status medallion + label tinted from a `DotsColor.Semantic`.
/// No shadow; the border is the semantic foreground at low opacity.
public extension DotsRectLabel where Leading == DotsStatusMark, Trailing == EmptyView {
    init(
        size: DotsControlSize = .sm,
        semantic: DotsColor.Semantic,
        systemImage: String,
        label: String
    ) {
        self.init(
            size: size,
            background: semantic.background,
            foreground: semantic.foreground,
            label: label,
            borderColor: semantic.foreground.opacity(0.22),
            borderWidth: 1,
            showsShadow: false,
            leading: {
                DotsStatusMark(size: .md, color: semantic.medallion, systemImage: systemImage)
            }
        )
    }
}

/// The chip primitive, named for how it reads at call sites.
public typealias DotsChip = DotsRectLabel

public struct DotsStatusMark: View {
    private let size: DotsControlSize
    private let color: Color
    private let systemImage: String
    private var iconColor: Color = DotsColor.Ink.inverse

    public init(
        size: DotsControlSize,
        color: Color,
        systemImage: String,
        iconColor: Color = DotsColor.Ink.inverse
    ) {
        self.size = size
        self.color = color
        self.systemImage = systemImage
        self.iconColor = iconColor
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.medallion, style: .continuous)
                .fill(color)
            DotsIcon(systemName: systemImage, size: min(DotsIconSize.badge, size.medallionSize - 6))
                .foregroundStyle(iconColor)
        }
        .frame(width: size.medallionSize, height: size.medallionSize)
    }
}

/// Applies `.floating` elevation only when requested, so the plain chip keeps its
/// shadow while the semantic chip sits flat.
private struct ConditionalElevation: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content.dotsElevation(.floating)
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: DotsSpacing.sm) {
        HStack(spacing: DotsSpacing.sm) {
            DotsRectLabel(label: "8 XP") {
                DotsStatusMark(size: .md, color: DotsColor.brand, systemImage: "bolt.fill")
            }
            DotsRectLabel(
                size: .sm,
                background: DotsColor.solved.background,
                foreground: DotsColor.solved.foreground,
                label: "Solved"
            ) {
                DotsStatusMark(size: .sm, color: DotsColor.solved.medallion, systemImage: "checkmark")
            }
        }

        HStack(spacing: DotsSpacing.sm) {
            DotsChip(semantic: DotsColor.solved, systemImage: "checkmark", label: "Correct")
            DotsChip(semantic: DotsColor.needsWork, systemImage: "pencil", label: "Needs work")
            DotsChip(semantic: DotsColor.needsRevision, systemImage: "xmark", label: "Try again")
        }
    }
    .padding()
    .background(DotsTheme.paperBase)
}
