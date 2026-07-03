public import SwiftUI

/// GitHub's contribution grammar in the Dots design system: a woven
/// field of rounded cells, one per day, oldest to newest in 7-day
/// columns. Color follows the two-layer law — green is earned (depth =
/// xp toward the goal, full green = goal hit), empty days are hairline
/// ghosts, a freeze-protected day is a hollow blue ring (Dots
/// protecting, not judging), and today wears a quiet ink outline. No
/// axis labels, no legend: texture, not a chart.
public struct DotsContributionGraph: View {
    public struct Day: Equatable {
        /// xp / dailyGoal; >= 1 means the goal was hit.
        public let intensity: Double
        public let isFreeze: Bool
        public let isToday: Bool

        public init(intensity: Double, isFreeze: Bool = false, isToday: Bool = false) {
            self.intensity = intensity
            self.isFreeze = isFreeze
            self.isToday = isToday
        }
    }

    private let days: [Day]

    /// `days` is ordered oldest → newest; the newest day lands in the
    /// bottom-right cell.
    public init(days: [Day]) {
        self.days = days
    }

    private static let rows = 7
    private static let gap: CGFloat = 3

    public var body: some View {
        let columns = max(Int((Double(days.count) / Double(Self.rows)).rounded(.up)), 1)
        return Canvas { context, size in
            // Reserve a margin so today's outline (drawn 2pt outside its
            // cell) never clips at the canvas edge.
            let inset: CGFloat = 2.5
            let cell = min(
                (size.width - inset * 2 - Self.gap * CGFloat(columns - 1)) / CGFloat(columns),
                (size.height - inset * 2 - Self.gap * CGFloat(Self.rows - 1)) / CGFloat(Self.rows)
            )
            guard cell > 1 else { return }

            // Center the field both ways — the weave sits in the middle
            // of whatever frame hosts it.
            let fieldWidth = CGFloat(columns) * cell + CGFloat(columns - 1) * Self.gap
            let fieldHeight = CGFloat(Self.rows) * cell + CGFloat(Self.rows - 1) * Self.gap
            let originX = (size.width - fieldWidth) / 2
            let originY = (size.height - fieldHeight) / 2

            for (index, day) in days.enumerated() {
                // Fill bottom-right backwards: the last element is the
                // newest day in the last column's last row.
                let slot = columns * Self.rows - days.count + index
                let column = slot / Self.rows
                let row = slot % Self.rows
                let rect = CGRect(
                    x: originX + CGFloat(column) * (cell + Self.gap),
                    y: originY + CGFloat(row) * (cell + Self.gap),
                    width: cell,
                    height: cell
                )
                let shape = Path(roundedRect: rect, cornerRadius: cell * 0.28)

                if day.isFreeze {
                    context.stroke(shape, with: .color(DotsColor.brand.opacity(0.7)), lineWidth: 1.2)
                } else if day.intensity <= 0 {
                    context.fill(shape, with: .color(DotsColor.Background.hairline.opacity(0.55)))
                } else {
                    context.fill(shape, with: .color(DotsColor.Accent.green.opacity(level(for: day.intensity))))
                }

                if day.isToday {
                    context.stroke(
                        Path(roundedRect: rect.insetBy(dx: -1.5, dy: -1.5), cornerRadius: cell * 0.32),
                        with: .color(DotsColor.Ink.primary.opacity(0.45)),
                        lineWidth: 1
                    )
                }
            }
        }
        .accessibilityLabel(accessibilitySummary)
    }

    /// Quantized depth: visible even for a little work, full only when
    /// the goal is hit.
    private func level(for intensity: Double) -> Double {
        if intensity >= 1 { return 1.0 }
        if intensity >= 0.5 { return 0.65 }
        if intensity >= 0.25 { return 0.4 }
        return 0.22
    }

    private var accessibilitySummary: String {
        let goalDays = days.filter { $0.intensity >= 1 }.count
        return "Practice history: \(goalDays) goal days in the last \(days.count) days"
    }
}

private func previewDays() -> [DotsContributionGraph.Day] {
    var days: [DotsContributionGraph.Day] = []
    for index in 0..<84 {
        let bucket: Int = (index * 37) % 5
        let intensity: Double = Double(bucket) / 3.0
        let isFreeze: Bool = index > 0 && index % 19 == 0
        let isToday: Bool = index == 83
        days.append(DotsContributionGraph.Day(
            intensity: intensity, isFreeze: isFreeze, isToday: isToday
        ))
    }
    return days
}

#Preview("Contribution graph") {
    DotsContributionGraph(days: previewDays())
        .frame(width: 220, height: 110)
        .padding()
}
