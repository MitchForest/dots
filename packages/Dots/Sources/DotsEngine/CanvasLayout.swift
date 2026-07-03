public import DotsDomain
public import Foundation

/// Deterministic default canvas layout for unpinned dots.
public enum CanvasLayout {
    private static let columns = 4
    private static let cellWidth: CGFloat = 300
    private static let cellHeight: CGFloat = 180
    private static let origin = CGPoint(x: 80, y: 80)

    /// Canvas position for each dot: pinned positions win; unpinned dots are
    /// placed deterministically (sorted by capturedAt then id, laid on a
    /// loose grid: 4 columns, cell 300x180, origin (80,80), newest first).
    public static func positions(
        for dots: [Dot],
        arrangement: CanvasArrangement
    ) -> [Dot.ID: CGPoint] {
        var result: [Dot.ID: CGPoint] = [:]
        var unpinned: [Dot] = []
        for dot in dots {
            if let position = arrangement.positions[dot.id.rawValue], position.pinned {
                result[dot.id] = CGPoint(x: position.x, y: position.y)
            } else {
                unpinned.append(dot)
            }
        }
        let ordered = unpinned.sorted { lhs, rhs in
            if lhs.capturedAt != rhs.capturedAt {
                return lhs.capturedAt > rhs.capturedAt
            }
            return lhs.id.rawValue > rhs.id.rawValue
        }
        for (index, dot) in ordered.enumerated() {
            result[dot.id] = CGPoint(
                x: origin.x + CGFloat(index % columns) * cellWidth,
                y: origin.y + CGFloat(index / columns) * cellHeight
            )
        }
        return result
    }
}
