import DotsDomain
import DotsUI
import SwiftUI

/// Screen-space connection layer: every reference renders as a directional
/// bezier flowing from the referenced idea into the one that derived from it
/// (arrowhead at the derived end); brand when an endpoint is selected. The
/// live dashed connect-drag draft rides on top. Positions come in
/// display-adjusted (drag offsets applied). Model-blind.
struct CanvasConnectionsView: View {
    let dots: [Dot]
    let displayPositions: [Dot.ID: CGPoint]
    let selection: [Dot.ID]
    let linkDraft: (source: Dot.ID, point: CGPoint)?
    let viewport: CanvasViewportState

    var body: some View {
        SwiftUI.Canvas { context, _ in
            drawReferences(in: &context)
            drawDraft(in: &context)
        }
    }

    private func drawReferences(in context: inout GraphicsContext) {
        for dot in dots {
            guard let derivedCenter = displayPositions[dot.id] else { continue }
            for reference in dot.references {
                let origin = Dot.ID(reference.rawValue)
                guard let originCenter = displayPositions[origin] else { continue }
                let from = Self.cardEdgePoint(center: originCenter, toward: derivedCenter)
                let to = Self.cardEdgePoint(center: derivedCenter, toward: originCenter)
                let isHighlighted = selection.contains(dot.id) || selection.contains(origin)
                let screenFrom = Self.screenPoint(from, viewport: viewport)
                let screenTo = Self.screenPoint(to, viewport: viewport)
                let color = isHighlighted
                    ? DotsColor.brand
                    : DotsColor.Ink.muted.opacity(0.7)
                context.stroke(
                    Self.bezier(from: screenFrom, to: screenTo, zoom: viewport.zoomScale),
                    with: .color(color),
                    lineWidth: 2
                )
                context.fill(
                    Self.arrowhead(at: screenTo, from: screenFrom, zoom: viewport.zoomScale),
                    with: .color(color)
                )
            }
        }
    }

    private func drawDraft(in context: inout GraphicsContext) {
        guard let linkDraft, let fromCenter = displayPositions[linkDraft.source] else { return }
        let from = Self.cardEdgePoint(center: fromCenter, toward: linkDraft.point)
        context.stroke(
            Self.bezier(
                from: Self.screenPoint(from, viewport: viewport),
                to: Self.screenPoint(linkDraft.point, viewport: viewport),
                zoom: viewport.zoomScale
            ),
            with: .color(DotsColor.brand),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 5])
        )
    }

    static func screenPoint(_ canvasPoint: CGPoint, viewport: CanvasViewportState) -> CGPoint {
        CGPoint(
            x: (canvasPoint.x - viewport.contentOffset.x) * viewport.zoomScale,
            y: (canvasPoint.y - viewport.contentOffset.y) * viewport.zoomScale
        )
    }

    /// The point on the card's boundary along the line toward `toward` — so
    /// connections attach to card edges instead of vanishing under them.
    static func cardEdgePoint(center: CGPoint, toward: CGPoint) -> CGPoint {
        let dx = toward.x - center.x
        let dy = toward.y - center.y
        guard dx != 0 || dy != 0 else { return center }
        let halfWidth = DotCardView.cardSize.width / 2 + 4
        let halfHeight = DotCardView.cardSize.height / 2 + 4
        let scaleX = dx == 0 ? .infinity : halfWidth / abs(dx)
        let scaleY = dy == 0 ? .infinity : halfHeight / abs(dy)
        let scale = min(scaleX, scaleY)
        guard scale < 1 else { return center }
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }

    static func bezier(from: CGPoint, to: CGPoint, zoom: CGFloat) -> Path {
        var path = Path()
        let lead = max(28 * zoom, abs(to.x - from.x) * 0.4)
        path.move(to: from)
        path.addCurve(
            to: to,
            control1: CGPoint(x: from.x + lead, y: from.y),
            control2: CGPoint(x: to.x - lead, y: to.y)
        )
        return path
    }

    /// A small triangle pointing along `from → at`, marking edge direction.
    static func arrowhead(at tip: CGPoint, from: CGPoint, zoom: CGFloat) -> Path {
        let angle = atan2(tip.y - from.y, tip.x - from.x)
        let length = max(7, 9 * zoom)
        let spread: CGFloat = 0.5
        var path = Path()
        path.move(to: tip)
        path.addLine(
            to: CGPoint(
                x: tip.x - length * cos(angle - spread),
                y: tip.y - length * sin(angle - spread)
            )
        )
        path.addLine(
            to: CGPoint(
                x: tip.x - length * cos(angle + spread),
                y: tip.y - length * sin(angle + spread)
            )
        )
        path.closeSubpath()
        return path
    }
}
