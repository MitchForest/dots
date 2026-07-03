public import CoreGraphics

/// The viewport transform for an infinite pan/zoom canvas.
///
/// `contentOffset` is the canvas-space point currently sitting at the
/// viewport's top-left corner; `zoomScale` is the screen-points-per-canvas-
/// point magnification, clamped to `[minimumZoomScale, maximumZoomScale]`
/// by the gesture layer. A canvas point `p` renders on screen at
/// `(p - contentOffset) * zoomScale`.
nonisolated public struct CanvasViewportState: Equatable, Sendable {
    /// Hard lower bound for `zoomScale`.
    public static let minimumZoomScale: CGFloat = 0.25
    /// Hard upper bound for `zoomScale`.
    public static let maximumZoomScale: CGFloat = 2.5

    /// Canvas-space point at the viewport's top-left.
    public var contentOffset: CGPoint
    /// Screen points per canvas point, clamped to `[0.25, 2.5]`.
    public var zoomScale: CGFloat

    public init(contentOffset: CGPoint = .zero, zoomScale: CGFloat = 1) {
        self.contentOffset = contentOffset
        self.zoomScale = zoomScale
    }

    /// Returns the viewport to zoom 1 at the canvas origin. Callers own
    /// animation: wrap the mutation in `withAnimation` to glide home.
    public mutating func recenter() {
        contentOffset = .zero
        zoomScale = 1
    }

    /// Frames `bounds` (canvas space) inside a viewport of `size`, padded,
    /// zoom clamped to the hard bounds and capped at 1 so sparse content
    /// never blows up. Content centers in the viewport. Callers own
    /// animation.
    public mutating func fit(bounds: CGRect, in size: CGSize, padding: CGFloat = 80) {
        guard size.width > 0, size.height > 0, !bounds.isEmpty else {
            recenter()
            return
        }
        let padded = bounds.insetBy(dx: -padding, dy: -padding)
        let rawZoom = min(size.width / padded.width, size.height / padded.height)
        let zoom = min(1, max(Self.minimumZoomScale, min(Self.maximumZoomScale, rawZoom)))
        zoomScale = zoom
        contentOffset = CGPoint(
            x: padded.midX - (size.width / zoom) / 2,
            y: padded.midY - (size.height / zoom) / 2
        )
    }

    /// Inverse of the viewport transform (scale at top-leading, then offset):
    /// `canvas = viewport / zoom + contentOffset`.
    public func canvasPoint(fromViewportPoint point: CGPoint) -> CGPoint {
        let zoom = max(zoomScale, 0.01)
        return CGPoint(
            x: point.x / zoom + contentOffset.x,
            y: point.y / zoom + contentOffset.y
        )
    }
}
