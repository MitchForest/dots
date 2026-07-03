#if os(macOS)
import AppKit
import SwiftUI

/// The macOS gesture layer for `ZoomPanCanvas`: an event-catching `NSView`
/// placed UNDER the SwiftUI content (as a `.background`). Content keeps its
/// own click/drag gestures; scroll-wheel pans, trackpad pinch zooms around
/// the cursor, and double-click on empty canvas reports the canvas point.
struct CanvasEventSurface: NSViewRepresentable {
    @Binding var viewport: CanvasViewportState
    let isLocked: Bool
    let onDoubleClick: ((CGPoint) -> Void)?

    func makeNSView(context: Context) -> CanvasEventCatcher {
        CanvasEventCatcher()
    }

    func updateNSView(_ nsView: CanvasEventCatcher, context: Context) {
        let viewport = $viewport
        nsView.isLocked = isLocked
        nsView.onPan = { delta in
            var state = viewport.wrappedValue
            let zoom = max(state.zoomScale, 0.01)
            state.contentOffset.x -= delta.width / zoom
            state.contentOffset.y -= delta.height / zoom
            viewport.wrappedValue = state
        }
        nsView.onMagnify = { magnification, location in
            viewport.wrappedValue = Self.magnified(
                viewport.wrappedValue,
                by: magnification,
                around: location
            )
        }
        nsView.onMagnifyEnded = { location in
            let settled = Self.settled(viewport.wrappedValue, around: location)
            guard settled != viewport.wrappedValue else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                viewport.wrappedValue = settled
            }
        }
        let onDoubleClick = onDoubleClick
        nsView.onDoubleClick = { location in
            onDoubleClick?(viewport.wrappedValue.canvasPoint(fromViewportPoint: location))
        }
    }

    // MARK: Zoom math

    /// Zoom toward the cursor: the canvas point under `viewportPoint` stays
    /// fixed on screen while the scale changes.
    static func magnified(
        _ state: CanvasViewportState,
        by magnification: CGFloat,
        around viewportPoint: CGPoint
    ) -> CanvasViewportState {
        rescaled(state, to: softenedZoom(state.zoomScale * (1 + magnification)), around: viewportPoint)
    }

    /// Snap an over-rubber-banded zoom back inside the hard range, keeping
    /// the point under the cursor fixed. Caller animates the write.
    static func settled(_ state: CanvasViewportState, around viewportPoint: CGPoint) -> CanvasViewportState {
        let clamped = min(
            max(state.zoomScale, CanvasViewportState.minimumZoomScale),
            CanvasViewportState.maximumZoomScale
        )
        guard clamped != state.zoomScale else { return state }
        return rescaled(state, to: clamped, around: viewportPoint)
    }

    /// Soft clamp: past the hard bounds the gesture "gives" — overshoot is
    /// compressed to a quarter and capped, then `settled` springs it back.
    static func softenedZoom(_ proposed: CGFloat) -> CGFloat {
        let minZoom = CanvasViewportState.minimumZoomScale
        let maxZoom = CanvasViewportState.maximumZoomScale
        if proposed > maxZoom {
            return min(maxZoom + (proposed - maxZoom) * 0.25, maxZoom * 1.12)
        }
        if proposed < minZoom {
            return max(minZoom - (minZoom - proposed) * 0.25, minZoom * 0.88)
        }
        return proposed
    }

    private static func rescaled(
        _ state: CanvasViewportState,
        to zoom: CGFloat,
        around viewportPoint: CGPoint
    ) -> CanvasViewportState {
        let anchor = state.canvasPoint(fromViewportPoint: viewportPoint)
        var next = state
        next.zoomScale = zoom
        next.contentOffset = CGPoint(
            x: anchor.x - viewportPoint.x / zoom,
            y: anchor.y - viewportPoint.y / zoom
        )
        return next
    }
}

/// Flipped (top-left origin, matching SwiftUI) event catcher. Sits behind
/// the canvas content, so it only sees clicks the content did not claim;
/// scroll and magnify events reach it anywhere over empty canvas.
final class CanvasEventCatcher: NSView {
    var isLocked = false
    var onPan: (@MainActor (CGSize) -> Void)?
    var onMagnify: (@MainActor (CGFloat, CGPoint) -> Void)?
    var onMagnifyEnded: (@MainActor (CGPoint) -> Void)?
    var onDoubleClick: (@MainActor (CGPoint) -> Void)?

    override var isFlipped: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        guard !isLocked else {
            super.scrollWheel(with: event)
            return
        }
        // scrollingDelta* already reflects the user's natural-direction setting.
        onPan?(CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
    }

    override func magnify(with event: NSEvent) {
        guard !isLocked else {
            super.magnify(with: event)
            return
        }
        let location = convert(event.locationInWindow, from: nil)
        if event.phase == .ended || event.phase == .cancelled {
            onMagnifyEnded?(location)
        } else {
            onMagnify?(event.magnification, location)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard !isLocked, event.clickCount == 2 else {
            super.mouseDown(with: event)
            return
        }
        onDoubleClick?(convert(event.locationInWindow, from: nil))
    }
}
#endif
