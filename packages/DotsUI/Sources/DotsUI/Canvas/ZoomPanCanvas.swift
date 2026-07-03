public import SwiftUI

/// An infinite pan/zoom canvas surface with phase-locked graph paper.
///
/// Content is laid out by the CALLER in canvas coordinates — children use
/// `.position` with canvas points inside an infinite coordinate space —
/// and `ZoomPanCanvas` applies the viewport transform: scale at
/// `.topLeading`, then offset by `-contentOffset * zoomScale` (so
/// `contentOffset` stays in canvas units).
///
/// On macOS a background event view supplies gestures: two-finger scroll
/// pans, trackpad pinch zooms around the cursor (soft-clamped to
/// `[0.25, 2.5]`), and double-click on empty canvas reports the canvas
/// point. Because the event view sits BEHIND the content, single clicks
/// and drags on content (cards, etc.) reach the content untouched. On iOS
/// the canvas renders identically but ships no gestures.
///
/// ⌘0-style recenter is the caller's shortcut to own: mutate the binding
/// with `viewport.recenter()` inside `withAnimation` and both the content
/// and the grid glide home together.
public struct ZoomPanCanvas<Underlay: View, Content: View>: View {
    @Binding private var viewport: CanvasViewportState
    private let isLocked: Bool
    private let showsGrid: Bool
    private let onDoubleClick: ((_ canvasPoint: CGPoint) -> Void)?
    private let underlay: (CanvasViewportState) -> Underlay
    private let content: Content

    /// `underlay` renders in SCREEN space above the grid and below the
    /// transformed content — the home for connection lines and other
    /// large-extent drawing that must not live inside the scaled layer
    /// (giant rasterized canvases get tiled/culled by the renderer).
    public init(
        viewport: Binding<CanvasViewportState>,
        isLocked: Bool = false,
        showsGrid: Bool = true,
        onDoubleClick: ((_ canvasPoint: CGPoint) -> Void)? = nil,
        @ViewBuilder underlay: @escaping (CanvasViewportState) -> Underlay,
        @ViewBuilder content: () -> Content
    ) {
        self._viewport = viewport
        self.isLocked = isLocked
        self.showsGrid = showsGrid
        self.onDoubleClick = onDoubleClick
        self.underlay = underlay
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if showsGrid {
                CanvasGridPaper(
                    zoom: viewport.zoomScale,
                    screenPhaseOffset: CGPoint(
                        x: viewport.contentOffset.x * viewport.zoomScale,
                        y: viewport.contentOffset.y * viewport.zoomScale
                    )
                )
            }
            underlay(viewport)
                .allowsHitTesting(false)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .scaleEffect(viewport.zoomScale, anchor: .topLeading)
                .offset(
                    x: -viewport.contentOffset.x * viewport.zoomScale,
                    y: -viewport.contentOffset.y * viewport.zoomScale
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(eventSurface)
        .clipped()
    }

    @ViewBuilder private var eventSurface: some View {
        #if os(macOS)
        CanvasEventSurface(
            viewport: $viewport,
            isLocked: isLocked,
            onDoubleClick: onDoubleClick
        )
        #else
        Color.clear
        #endif
    }
}

extension ZoomPanCanvas where Underlay == EmptyView {
    public init(
        viewport: Binding<CanvasViewportState>,
        isLocked: Bool = false,
        showsGrid: Bool = true,
        onDoubleClick: ((_ canvasPoint: CGPoint) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            viewport: viewport,
            isLocked: isLocked,
            showsGrid: showsGrid,
            onDoubleClick: onDoubleClick,
            underlay: { _ in EmptyView() },
            content: content
        )
    }
}

/// Proof-style infinite graph paper, drawn in SCREEN space so line widths
/// stay constant at any zoom. Line positions follow the viewport transform
/// (phase-locked to `contentOffset` and `zoomScale`), so the paper never
/// reveals an edge. Animatable, so it stays registered with the content
/// when the caller animates the viewport (e.g. recenter).
nonisolated struct CanvasGridPaper: View, Animatable {
    static let minorSpacing: CGFloat = 24
    static let majorSpacing: CGFloat = 120
    /// Skip a line family when its screen spacing collapses — a moiré guard.
    static let minimumScreenSpacing: CGFloat = 4

    var zoom: CGFloat
    /// Screen-space phase, i.e. `contentOffset * zoom`.
    var screenPhaseOffset: CGPoint

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(zoom, AnimatablePair(screenPhaseOffset.x, screenPhaseOffset.y)) }
        set {
            zoom = newValue.first
            screenPhaseOffset = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }

    var body: some View {
        Canvas { context, size in
            drawLines(
                &context,
                size: size,
                spacing: Self.minorSpacing * zoom,
                color: DotsColor.Surface.gridLine,
                lineWidth: 0.5
            )
            drawLines(
                &context,
                size: size,
                spacing: Self.majorSpacing * zoom,
                color: DotsColor.Surface.gridMajorLine,
                lineWidth: 0.8
            )
        }
        .allowsHitTesting(false)
    }

    private func drawLines(
        _ context: inout GraphicsContext,
        size: CGSize,
        spacing: CGFloat,
        color: Color,
        lineWidth: CGFloat
    ) {
        guard spacing > Self.minimumScreenSpacing else { return }
        var path = Path()
        var x = phase(screenPhaseOffset.x, spacing: spacing)
        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }
        var y = phase(screenPhaseOffset.y, spacing: spacing)
        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    /// Screen position of the first grid line: canvas line `k * spacing`
    /// lands on screen at `k * spacing - screenPhaseOffset`.
    private func phase(_ offsetComponent: CGFloat, spacing: CGFloat) -> CGFloat {
        let remainder = (-offsetComponent).truncatingRemainder(dividingBy: spacing)
        return remainder < 0 ? remainder + spacing : remainder
    }
}

#Preview("ZoomPanCanvas") {
    @Previewable @State var viewport = CanvasViewportState()
    @Previewable @State var isLocked = false
    @Previewable @State var droppedPoints: [CGPoint] = []

    ZStack(alignment: .top) {
        ZoomPanCanvas(
            viewport: $viewport,
            isLocked: isLocked,
            onDoubleClick: { canvasPoint in
                droppedPoints.append(canvasPoint)
            },
            content: {
                canvasContent(droppedPoints: droppedPoints)
            }
        )
        .background(DotsTheme.paperBase)

        previewControls(viewport: $viewport, isLocked: $isLocked)
    }
    .frame(width: 960, height: 640)
}

@ViewBuilder
private func canvasContent(droppedPoints: [CGPoint]) -> some View {
    ZStack(alignment: .topLeading) {
        DotsCard {
            VStack(alignment: .leading, spacing: DotsSpacing.xs) {
                Text("Linear equations")
                    .font(DotsTypography.titleSmall)
                    .foregroundStyle(DotsColor.Ink.primary)
                Text("Solve for the unknown by keeping both sides balanced.")
                    .font(DotsTypography.body)
                    .foregroundStyle(DotsColor.Ink.secondary)
            }
        }
        .frame(width: 260)
        .position(x: 320, y: 220)

        DotsHairlineCard(
            title: "Today's session",
            metaLeading: "2 reviews · 1 lesson",
            metaTrailing: "~18 min",
            minHeight: 132,
            action: {}
        )
        .frame(width: 240)
        .position(x: 660, y: 380)

        DotsHairlineCard(title: "Map", metaLeading: "14 of 27", minHeight: 100, action: {})
            .frame(width: 200)
            .position(x: 420, y: 560)

        ForEach(Array(droppedPoints.enumerated()), id: \.offset) { _, point in
            Circle()
                .fill(DotsColor.brand)
                .frame(width: 10, height: 10)
                .position(point)
        }
    }
}

@ViewBuilder
private func previewControls(viewport: Binding<CanvasViewportState>, isLocked: Binding<Bool>) -> some View {
    HStack(spacing: DotsSpacing.md) {
        Toggle(isOn: isLocked) {
            DotsMetaLabel("Locked")
        }
        .toggleStyle(.switch)
        .fixedSize()
        Button("Recenter") {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                viewport.wrappedValue.recenter()
            }
        }
        DotsMetaLabel("Zoom \(Int(viewport.wrappedValue.zoomScale * 100))%")
    }
    .padding(DotsSpacing.md)
    .background(.regularMaterial, in: Capsule())
    .padding(.top, DotsSpacing.md)
}
