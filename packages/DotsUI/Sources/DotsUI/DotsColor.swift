public import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Canonical surface palette for the interactive problem surface.
/// Nonisolated: these are immutable `Color` values that shader code samples
/// from nonisolated rendering closures.
nonisolated public enum DotsColor {
    public enum Surface {
        // Never pure white / pure black. The lightest canvas is a faint warm
        // off-white; the darkest surfaces stay a touch above true black so the
        // material system always reads as paper, never as a void.
        public static let canvas = dynamic(light: 0xFCFCFA, dark: 0x2A2A2A)
        public static let control = dynamic(light: 0xF6F6F6, dark: 0x323232)
        public static let pressed = dynamic(light: 0xEDEDED, dark: 0x3A3A3A)
        public static let edge = dynamic(light: 0xE9E9E9, dark: 0x3A3A3A)
        public static let gridLine = dynamic(light: 0xF6F6F6, dark: 0x323232)
        public static let gridMajorLine = dynamic(light: 0xE9E9E9, dark: 0x3A3A3A)
    }

    public enum Ink {
        public static let primary = dynamic(light: 0x3C3C3C, dark: 0xFEFEFE)
        public static let secondary = dynamic(light: 0x979797, dark: 0xD7D7D7)
        public static let muted = dynamic(light: 0xBCBBBB, dark: 0x8F8F8F)
        public static let inverse = dynamic(light: 0xFEFEFE, dark: 0x202020)
    }

    public enum Accent {
        public static let green = dynamic(light: 0x00B85B, dark: 0x32D074)
        public static let red = dynamic(light: 0xFF3B30, dark: 0xFF453A)
        public static let orange = dynamic(light: 0xFF9500, dark: 0xFF9F0A)
    }

    /// App-level backgrounds for full screens (login, onboarding, future
    /// marketing surfaces) as distinct from the in-lesson `Surface.canvas`.
    /// These are the calm field the brand shader and glass panels sit on.
    public enum Background {
        public static let primary = dynamic(light: 0xFAF9F6, dark: 0x161618)
        public static let elevated = dynamic(light: 0xF2F1ED, dark: 0x202023)
        public static let hairline = dynamic(light: 0xE7E6E1, dark: 0x33333A)
    }

    /// One coherent palette for every hero shader. The blue is the app's system
    /// blue — the exact same blue as buttons (`DotsColor.brand`) — with a single
    /// deeper shade for depth/shadow, plus paper white. The halftone shader is
    /// the black/white variant, built from `ink` + `paper`. Nothing here is an
    /// off-brand royal or azure; shaders reference `DotsColor.brand` for the
    /// mid blue and `Hero.blueDeep` for the dark.
    public enum Hero {
        /// A deeper system blue for shadow/depth in the gradients. Same family
        /// as `DotsColor.brand`, just sunk down.
        public static let blueDeep = dynamic(light: 0x0050C8, dark: 0x0A3D8F)
        /// Deep navy floor for the halftone matrix — the "black" of the
        /// black/white variant. Never pure black.
        public static let ink = dynamic(light: 0x171614, dark: 0x100F0D)
        /// The warm off-white of the brand panel, as a fixed (non-dynamic) value
        /// so shader highlights/dots read as the same paper white in light and
        /// dark — the one white used everywhere.
        public static let paper = Color(red: 0.980, green: 0.976, blue: 0.965)
        /// Legible scrim used where content overlaps the shader on compact
        /// layouts. Darkens the field beneath glass/text.
        public static let scrim = Color.black.opacity(0.28)
    }

    public enum Neutral {
        public static let chrome = Surface.control
        public static let pressed = Surface.pressed
        public static let inkPrimary = Ink.primary
        public static let inkSecondary = Ink.secondary
        public static let hairline = Surface.edge
    }

    public struct Semantic: Sendable {
        public let background: Color
        public let foreground: Color
        public let medallion: Color

        public init(
            background: Color,
            foreground: Color,
            medallion: Color
        ) {
            self.background = background
            self.foreground = foreground
            self.medallion = medallion
        }
    }

    public static let solved = Semantic(
        background: Accent.green.opacity(0.12),
        foreground: Accent.green,
        medallion: Accent.green
    )

    public static let needsWork = Semantic(
        background: Accent.orange.opacity(0.10),
        foreground: Accent.orange,
        medallion: Accent.orange
    )

    public static let needsRevision = Semantic(
        background: Accent.red.opacity(0.10),
        foreground: Accent.red,
        medallion: Accent.red
    )

    #if canImport(UIKit)
    public static let brand = Color(uiColor: .systemBlue)
    #elseif canImport(AppKit)
    public static let brand = Color(nsColor: .systemBlue)
    #else
    public static let brand = Color.blue
    #endif
    public static let shadow = dynamic(light: 0x202020, dark: 0x000000)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: 1.0
            )
        })
        #elseif canImport(AppKit)
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: 1.0
            )
        })
        #else
        color(hex: light)
        #endif
    }

    #if !canImport(UIKit) && !canImport(AppKit)
    private static func color(hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
    #endif
}
