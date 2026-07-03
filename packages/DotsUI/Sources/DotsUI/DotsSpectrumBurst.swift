public import SwiftUI

/// The dots moment: white light disperses into the spectrum through the
/// grid. One shot, ≤1.2s; Reduce Motion gets a calm crossfade. Spectrum
/// appears ONLY here and on the mastery map — never ambient.
public struct DotsSpectrumBurst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?

    private let onFinished: (() -> Void)?
    private static let duration: TimeInterval = 1.1

    public init(onFinished: (() -> Void)? = nil) {
        self.onFinished = onFinished
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let progress = currentProgress(at: timeline.date)
            burstCanvas(progress: progress)
        }
        .allowsHitTesting(false)
        .onAppear {
            startedAt = Date()
            let delay = reduceMotion ? 0.4 : Self.duration + 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { onFinished?() }
        }
        .accessibilityHidden(true)
    }

    private func currentProgress(at date: Date) -> CGFloat {
        if reduceMotion { return 1 }
        guard let startedAt else { return 0 }
        let elapsed = date.timeIntervalSince(startedAt)
        let linear = min(1, max(0, elapsed / Self.duration))
        // ease-out
        return CGFloat(1 - pow(1 - linear, 2.2))
    }

    private func burstCanvas(progress: CGFloat) -> some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxLength = max(size.width, size.height) * 0.62

            // The incoming beam of white light.
            let beamAlpha = progress < 0.35 ? Double(progress / 0.35) : Double(max(0, 1 - (progress - 0.35) / 0.2))
            if beamAlpha > 0 {
                var beam = Path()
                beam.move(to: CGPoint(x: 0, y: center.y))
                beam.addLine(to: center)
                context.stroke(
                    beam,
                    with: .color(Color(red: 0.99, green: 0.99, blue: 0.97).opacity(beamAlpha * 0.9)),
                    lineWidth: 2.5
                )
            }

            // Dispersion: six rays fanning out, red high to violet low.
            let fanStart: CGFloat = 0.3
            guard progress > fanStart else { return }
            let fan = (progress - fanStart) / (1 - fanStart)
            let rayCount = DotsColor.Spectrum.ramp.count
            for (index, color) in DotsColor.Spectrum.ramp.enumerated() {
                let spread = (CGFloat(index) - CGFloat(rayCount - 1) / 2) / CGFloat(rayCount - 1)
                let angle = spread * 0.62  // ±0.31 rad fan
                let length = maxLength * fan
                let end = CGPoint(
                    x: center.x + cos(angle) * length,
                    y: center.y + sin(angle) * length
                )
                var ray = Path()
                ray.move(to: center)
                ray.addLine(to: end)
                let fade = Double(max(0, 1 - fan * 0.55))
                context.stroke(ray, with: .color(color.opacity(fade)), lineWidth: 2)
            }
        }
    }
}
