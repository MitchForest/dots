public import SwiftUI

public struct DotsElevation: Sendable {
    public let yOffset: CGFloat
    public let blur: CGFloat
    public let opacity: Double

    public init(yOffset: CGFloat, blur: CGFloat, opacity: Double) {
        self.yOffset = yOffset
        self.blur = blur
        self.opacity = opacity
    }

    public static let floating = DotsElevation(yOffset: 8, blur: 24, opacity: 0.08)
}

public extension View {
    func dotsElevation(_ elevation: DotsElevation) -> some View {
        shadow(
            color: DotsColor.shadow.opacity(elevation.opacity),
            radius: elevation.blur / 2,
            x: 0,
            y: elevation.yOffset
        )
    }
}
