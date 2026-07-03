import CoreGraphics
import DotsDomain
import DotsEngine
import Foundation
import Testing

@Suite("CanvasLayout")
struct CanvasLayoutTests {
    private func dot(_ id: String, at seconds: TimeInterval) -> Dot {
        Dot(id: Dot.ID(id), content: id, capturedAt: Date(timeIntervalSince1970: seconds))
    }

    @Test("Same input yields the same output")
    func deterministic() {
        let dots = (0..<9).map { dot("01J0DOT\($0)", at: TimeInterval($0)) }
        let arrangement = CanvasArrangement(
            positions: ["01J0DOT3": CanvasArrangement.Position(x: -50, y: 900)]
        )

        let first = CanvasLayout.positions(for: dots, arrangement: arrangement)
        let second = CanvasLayout.positions(for: dots.shuffled(), arrangement: arrangement)

        #expect(first == second)
        #expect(first.count == dots.count)
    }

    @Test("Newest dots come first on the grid, wrapping after 4 columns")
    func newestFirstGrid() {
        let dots = (0..<5).map { dot("01J0DOT\($0)", at: TimeInterval($0)) }

        let positions = CanvasLayout.positions(for: dots, arrangement: CanvasArrangement())

        #expect(positions[Dot.ID("01J0DOT4")] == CGPoint(x: 80, y: 80))
        #expect(positions[Dot.ID("01J0DOT3")] == CGPoint(x: 380, y: 80))
        #expect(positions[Dot.ID("01J0DOT2")] == CGPoint(x: 680, y: 80))
        #expect(positions[Dot.ID("01J0DOT1")] == CGPoint(x: 980, y: 80))
        #expect(positions[Dot.ID("01J0DOT0")] == CGPoint(x: 80, y: 260))
    }

    @Test("Pinned positions override the computed grid")
    func pinnedOverride() {
        let dots = [dot("01J0PINNED", at: 10), dot("01J0FREE", at: 5)]
        let arrangement = CanvasArrangement(
            positions: ["01J0PINNED": CanvasArrangement.Position(x: 120.5, y: -340.0)]
        )

        let positions = CanvasLayout.positions(for: dots, arrangement: arrangement)

        #expect(positions[Dot.ID("01J0PINNED")] == CGPoint(x: 120.5, y: -340.0))
        #expect(positions[Dot.ID("01J0FREE")] == CGPoint(x: 80, y: 80))
    }

    @Test("Unpinned arrangement entries fall back to the computed grid")
    func unpinnedEntryIgnored() {
        let dots = [dot("01J0SOLO", at: 1)]
        let arrangement = CanvasArrangement(
            positions: ["01J0SOLO": CanvasArrangement.Position(x: 999, y: 999, pinned: false)]
        )

        let positions = CanvasLayout.positions(for: dots, arrangement: arrangement)

        #expect(positions[Dot.ID("01J0SOLO")] == CGPoint(x: 80, y: 80))
    }

    @Test("Equal capture times break ties by id, newest-style id first")
    func capturedAtTieBreak() {
        let dots = [dot("01J0AAAA", at: 0), dot("01J0BBBB", at: 0)]

        let positions = CanvasLayout.positions(for: dots, arrangement: CanvasArrangement())

        #expect(positions[Dot.ID("01J0BBBB")] == CGPoint(x: 80, y: 80))
        #expect(positions[Dot.ID("01J0AAAA")] == CGPoint(x: 380, y: 80))
    }
}
