public import Foundation

/// The committed `.dots/canvas.json` model — user-authored spatial arrangement.
/// View-state, not content: pinned positions are durable overrides of the
/// computed layout (see .docs/target.md, "Canvas arrangement").
public struct CanvasArrangement: Codable, Equatable, Sendable {
    public struct Position: Codable, Equatable, Sendable {
        public var pinned: Bool
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double, pinned: Bool = true) {
            self.pinned = pinned
            self.x = x
            self.y = y
        }
    }

    /// Keyed by dot id rawValue.
    public var positions: [String: Position]
    public var version: Int

    public init(positions: [String: Position] = [:], version: Int = 1) {
        self.positions = positions
        self.version = version
    }

    /// Decodes canvas.json contents.
    public static func decode(from data: Data) throws -> CanvasArrangement {
        try JSONDecoder().decode(CanvasArrangement.self, from: data)
    }

    /// Encodes with sorted keys and pretty printing for stable git diffs.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
