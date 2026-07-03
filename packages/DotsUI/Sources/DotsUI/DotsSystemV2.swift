public import SwiftUI

// MARK: - Design system v2 tokens (plan-phase3-design.md)

nonisolated extension DotsColor {
    /// The dispersion ramp. Spectrum appears in exactly two places: the
    /// mastery map's domain tinting (at low opacity) and dots moments
    /// (session complete, skill mastered). Never ambient.
    public enum Spectrum {
        public static let red = Color(red: 1.00, green: 0.27, blue: 0.23)
        public static let orange = Color(red: 1.00, green: 0.58, blue: 0.00)
        public static let yellow = Color(red: 1.00, green: 0.84, blue: 0.04)
        public static let green = Color(red: 0.20, green: 0.84, blue: 0.46)
        public static let blue = Color(red: 0.04, green: 0.52, blue: 1.00)
        public static let violet = Color(red: 0.69, green: 0.32, blue: 0.87)

        public static let ramp: [Color] = [red, orange, yellow, green, blue, violet]
    }

    /// White light — the achievement color. On ink surfaces, correct and
    /// mastered render as light, not green.
    public static let light = Color(red: 0.99, green: 0.99, blue: 0.97)
}

extension DotsTypography {
    /// Home greeting, session-complete word. Editorial, calm, enormous.
    public static let displayXL = Font.system(size: 64, weight: .bold, design: .default)
    /// Breadcrumb wordmark row.
    public static let breadcrumb = Font.system(size: 17, weight: .medium, design: .default)
    /// Tracked uppercase whisper — use through `DotsMetaLabel`.
    public static let metaLabel = Font.system(size: 11, weight: .semibold, design: .default)
}

// MARK: - DotsGridSurface

/// The graph-paper field, extended from the workspace canvas to every
/// surface. Content aligns to the 24pt cell; hairlines sit on grid lines.
public struct DotsGridSurface: View {
    public enum Intensity {
        /// Whisper-faint — page backgrounds.
        case subtle
        /// The workspace-canvas weight.
        case standard

        var minorOpacity: Double {
            switch self {
            case .subtle: 0.05
            case .standard: 0.10
            }
        }

        var majorOpacity: Double {
            switch self {
            case .subtle: 0.09
            case .standard: 0.16
            }
        }
    }

    public static let cell: CGFloat = 24

    private let intensity: Intensity
    private let lineColor: Color

    public init(intensity: Intensity = .subtle, lineColor: Color = DotsColor.Ink.primary) {
        self.intensity = intensity
        self.lineColor = lineColor
    }

    public var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let cell = Self.cell
            var minor = Path()
            var major = Path()
            var x: CGFloat = 0
            var column = 0
            while x <= size.width {
                if column % 4 == 0 {
                    major.move(to: CGPoint(x: x, y: 0))
                    major.addLine(to: CGPoint(x: x, y: size.height))
                } else {
                    minor.move(to: CGPoint(x: x, y: 0))
                    minor.addLine(to: CGPoint(x: x, y: size.height))
                }
                x += cell
                column += 1
            }
            var y: CGFloat = 0
            var row = 0
            while y <= size.height {
                if row % 4 == 0 {
                    major.move(to: CGPoint(x: 0, y: y))
                    major.addLine(to: CGPoint(x: size.width, y: y))
                } else {
                    minor.move(to: CGPoint(x: 0, y: y))
                    minor.addLine(to: CGPoint(x: size.width, y: y))
                }
                y += cell
                row += 1
            }
            context.stroke(minor, with: .color(lineColor.opacity(intensity.minorOpacity)), lineWidth: 0.5)
            context.stroke(major, with: .color(lineColor.opacity(intensity.majorOpacity)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}

// MARK: - DotsMetaLabel

/// The tracked-uppercase whisper from the reference language: card
/// corners, chrome tabs, date rows. Type is the ornament.
public struct DotsMetaLabel: View {
    private let text: String
    private let tint: Color

    public init(_ text: String, tint: Color = DotsColor.Ink.muted) {
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        Text(text.uppercased())
            .font(DotsTypography.metaLabel)
            .tracking(1.3)
            .foregroundStyle(tint)
            .lineLimit(1)
    }
}

// MARK: - DotsHairlineCard

/// The v2 card: near-flat, hairline border, title top-left, meta-label
/// pinned to the bottom, vast negative space in between. Press brightens
/// the hairline to accent and lifts 2pt.
public struct DotsHairlineCard<Content: View>: View {
    private let title: String?
    private let metaLeading: String?
    private let metaTrailing: String?
    private let minHeight: CGFloat
    private let action: (() -> Void)?
    private let content: Content

    @State private var isPressed = false

    public init(
        title: String? = nil,
        metaLeading: String? = nil,
        metaTrailing: String? = nil,
        minHeight: CGFloat = 96,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.metaLeading = metaLeading
        self.metaTrailing = metaTrailing
        self.minHeight = minHeight
        self.action = action
        self.content = content()
    }

    public var body: some View {
        let card = VStack(alignment: .leading, spacing: DotsSpacing.sm) {
            if let title {
                Text(title)
                    .font(DotsTypography.titleSmall)
                    .foregroundStyle(DotsColor.Ink.primary)
            }
            content
            Spacer(minLength: 0)
            if metaLeading != nil || metaTrailing != nil {
                HStack {
                    if let metaLeading { DotsMetaLabel(metaLeading) }
                    Spacer(minLength: DotsSpacing.sm)
                    if let metaTrailing { DotsMetaLabel(metaTrailing) }
                }
            }
        }
        .padding(DotsSpacing.md)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                .fill(DotsColor.Background.elevated.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                .strokeBorder(
                    isPressed ? AnyShapeStyle(DotsColor.brand) : AnyShapeStyle(DotsColor.Background.hairline),
                    lineWidth: 1
                )
        )
        .offset(y: isPressed ? -2 : 0)
        .animation(.spring(duration: 0.35), value: isPressed)

        if let action {
            Button(action: action) { card }
                .buttonStyle(PressTrackingButtonStyle(isPressed: $isPressed))
        } else {
            card
        }
    }
}

private struct PressTrackingButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous))
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}

// MARK: - DotsBreadcrumbBar

/// Logomark · context path · optional close. The only header chrome.
public struct DotsBreadcrumbBar: View {
    private let path: [String]
    private let onClose: (() -> Void)?

    public init(path: [String], onClose: (() -> Void)? = nil) {
        self.path = path
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: DotsSpacing.sm) {
            DotsLogoMark(height: 18)
            ForEach(Array(path.enumerated()), id: \.offset) { index, element in
                if index > 0 || path.isEmpty == false {
                    Text("/")
                        .font(DotsTypography.breadcrumb)
                        .foregroundStyle(DotsColor.Ink.muted)
                }
                Text(element)
                    .font(DotsTypography.breadcrumb)
                    .foregroundStyle(index == path.count - 1 ? DotsColor.Ink.primary : DotsColor.Ink.secondary)
            }
            if let onClose {
                Button(action: onClose) {
                    DotsIcon(systemName: "xmark", size: 13)
                        .foregroundStyle(DotsColor.Ink.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - DotsXPRing

/// Thin-stroke daily-goal ring; fills with white light.
public struct DotsXPRing: View {
    private let earned: Int
    private let goal: Int
    private let diameter: CGFloat

    public init(earned: Int, goal: Int, diameter: CGFloat = 72) {
        self.earned = max(0, earned)
        self.goal = max(1, goal)
        self.diameter = diameter
    }

    private var progress: Double {
        min(1, Double(earned) / Double(goal))
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(DotsColor.Background.hairline, lineWidth: 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progress >= 1 ? DotsColor.light : DotsColor.brand,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(earned)")
                    .font(DotsTypography.Metric.countCompact)
                    .foregroundStyle(DotsColor.Ink.primary)
                DotsMetaLabel("of \(goal)")
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeOut(duration: 0.6), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(earned) of \(goal) XP today")
    }
}

// MARK: - Previews

#Preview("System v2 — Ink") {
    ZStack {
        DotsColor.Background.primary.ignoresSafeArea()
        DotsGridSurface()
        VStack(alignment: .leading, spacing: 24) {
            DotsBreadcrumbBar(path: ["today"])
            Text("Good morning, Mia.")
                .font(DotsTypography.displayXL)
                .foregroundStyle(DotsColor.Ink.primary)
            DotsMetaLabel("Tuesday · June 10 · Streak 6")
            HStack(spacing: 16) {
                DotsHairlineCard(title: "Today's session", metaLeading: "2 reviews · 1 lesson", metaTrailing: "~18 min", minHeight: 140, action: {})
                VStack(spacing: 16) {
                    DotsXPRing(earned: 120, goal: 150)
                    DotsHairlineCard(title: "Map", metaLeading: "14 of 27", minHeight: 64, action: {})
                }
                .frame(width: 160)
            }
        }
        .padding(48)
    }
    .preferredColorScheme(.dark)
}
