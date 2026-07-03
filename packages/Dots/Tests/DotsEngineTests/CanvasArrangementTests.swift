import DotsEngine
import Foundation
import Testing

@Suite("CanvasArrangement")
struct CanvasArrangementTests {
    private var sample: CanvasArrangement {
        CanvasArrangement(
            positions: [
                "01J0ZZZZ": CanvasArrangement.Position(x: 120.5, y: -340.0),
                "01J0AAAA": CanvasArrangement.Position(x: 0, y: 12, pinned: false)
            ],
            version: 1
        )
    }

    @Test("Encoding is byte-equal across runs")
    func stableEncoding() throws {
        let first = try sample.encoded()
        let second = try sample.encoded()

        #expect(first == second)
    }

    @Test("Encoded JSON round-trips through decode")
    func roundTrip() throws {
        let decoded = try CanvasArrangement.decode(from: sample.encoded())

        #expect(decoded == sample)
    }

    @Test("Encoded JSON is pretty printed with sorted keys")
    func diffFriendlyShape() throws {
        let json = try #require(String(data: sample.encoded(), encoding: .utf8))

        #expect(json.contains("\n"))
        let aaaa = try #require(json.range(of: "01J0AAAA"))
        let zzzz = try #require(json.range(of: "01J0ZZZZ"))
        let positions = try #require(json.range(of: "\"positions\""))
        let version = try #require(json.range(of: "\"version\""))
        #expect(aaaa.lowerBound < zzzz.lowerBound)
        #expect(positions.lowerBound < version.lowerBound)
    }

    @Test("Defaults are an empty version-1 arrangement with pinned positions")
    func defaults() {
        let arrangement = CanvasArrangement()
        #expect(arrangement.positions.isEmpty)
        #expect(arrangement.version == 1)

        let position = CanvasArrangement.Position(x: 1, y: 2)
        #expect(position.pinned)
    }
}
