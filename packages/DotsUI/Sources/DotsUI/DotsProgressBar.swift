public import SwiftUI

/// The one linear progress meter. A capsule track with a capsule fill in the
/// interactive blue — capsules are sanctioned here because this is a true
/// progress indicator (see design.md). Two styles cover every call site:
///
/// - `.flat`: the track fills the frame edge-to-edge. Used on content surfaces
///   (the Home problem-set cards) where you size it with `.frame(height:)`.
/// - `.inset`: the track is horizontally inset and vertically centered inside a
///   taller frame, with its thickness derived from the frame height. Used inside
///   the lesson top bar, where the bar itself wears the glass capsule.
public struct DotsProgressBar: View {
    public enum Style: Sendable {
        case flat
        case inset
    }

    private let progress: Double
    private let style: Style
    private let trackColor: Color
    private let fillColor: Color
    private let accessibilityLabel: String

    public init(
        progress: Double,
        style: Style = .flat,
        trackColor: Color = DotsColor.Neutral.pressed.opacity(0.72),
        fillColor: Color = DotsColor.brand,
        accessibilityLabel: String = "Progress"
    ) {
        self.progress = progress
        self.style = style
        self.trackColor = trackColor
        self.fillColor = fillColor
        self.accessibilityLabel = accessibilityLabel
    }

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    public var body: some View {
        GeometryReader { geometry in
            switch style {
            case .flat:
                flatBar(in: geometry.size)
            case .inset:
                insetBar(in: geometry.size)
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(Int((clampedProgress * 100).rounded())) percent")
    }

    private func flatBar(in size: CGSize) -> some View {
        let fillWidth = size.width * clampedProgress
        return ZStack(alignment: .leading) {
            Capsule().fill(trackColor)
            Capsule()
                .fill(fillColor)
                .frame(width: max(clampedProgress > 0 ? 8 : 0, fillWidth))
        }
    }

    private func insetBar(in size: CGSize) -> some View {
        let horizontalInset = min(DotsSpacing.sm, size.width * 0.08)
        let trackWidth = max(0, size.width - horizontalInset * 2)
        let trackHeight = min(10, max(6, size.height * 0.34))
        let fillWidth = trackWidth * clampedProgress
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(trackColor)
                .frame(width: trackWidth, height: trackHeight)
            Capsule()
                .fill(fillColor)
                .frame(width: max(trackHeight, fillWidth), height: trackHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, horizontalInset)
    }
}

#Preview {
    VStack(spacing: DotsSpacing.lg) {
        DotsProgressBar(progress: 0).frame(height: 8)
        DotsProgressBar(progress: 0.4).frame(height: 8)
        DotsProgressBar(progress: 1).frame(height: 8)
        DotsProgressBar(progress: 0.6, style: .inset)
            .frame(width: 220, height: 34)
            .background(DotsColor.Surface.control, in: Capsule())
    }
    .padding(DotsSpacing.xl)
    .background(DotsTheme.paperBase)
}
