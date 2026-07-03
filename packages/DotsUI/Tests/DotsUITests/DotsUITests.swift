import CoreGraphics
import Testing

@testable import DotsUI

@Suite("Dots components")
struct DotsUITests {
    @Test("spacing tokens remain stable")
    func spacingTokens() {
        #expect(DotsSpacing.sm == 12)
        #expect(DotsRadius.md == 8)
    }
}

@Suite("Canvas viewport")
struct CanvasViewportTests {
    @Test("Fit frames bounds centered with clamped zoom")
    func fitFramesBounds() {
        var viewport = CanvasViewportState()
        viewport.fit(
            bounds: CGRect(x: 1000, y: 1000, width: 400, height: 200),
            in: CGSize(width: 800, height: 600),
            padding: 100
        )

        // Padded bounds: 600×400 → zoom limited by width: 800/600 ≈ 1.33 → capped at 1.
        #expect(viewport.zoomScale == 1)
        // Content center (1200, 1100) sits at viewport center.
        #expect(abs(viewport.contentOffset.x - (1200 - 400)) < 0.001)
        #expect(abs(viewport.contentOffset.y - (1100 - 300)) < 0.001)
    }

    @Test("Fit with empty bounds recenters")
    func fitEmptyRecenters() {
        var viewport = CanvasViewportState(contentOffset: CGPoint(x: 9, y: 9), zoomScale: 2)
        viewport.fit(bounds: .null, in: CGSize(width: 800, height: 600))

        #expect(viewport == CanvasViewportState())
    }
}
