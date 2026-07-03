public import SwiftUI

/// Dots's type scale. All prose uses the system font (SF Pro, `.default`) for
/// clarity, Dynamic Type, and an Apple-native, mathematically-precise feel that
/// matches the sharp-cornered logo. The one expressive step is `display`, used
/// for the wordmark.
///
/// SF Pro Rounded (`.rounded`) is reserved **exclusively for numerals** — stat
/// values, counters, progress numbers — via the `Metric` namespace below, so
/// data reads friendly and gamified while the rest of the UI stays precise.
public enum DotsTypography {
    public static let display = Font.system(size: 52, weight: .bold, design: .default)
    public static let title = Font.system(size: 24, weight: .semibold, design: .default)
    public static let titleSmall = Font.system(size: 20, weight: .semibold, design: .default)
    public static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    public static let callout = Font.system(size: 16, weight: .semibold, design: .default)
    public static let body = Font.system(size: 15, weight: .medium, design: .default)
    public static let footnote = Font.system(size: 12, weight: .medium, design: .default)
    public static let caption = Font.system(size: 11, weight: .semibold, design: .default)

    /// Numerals only. Rounded design + monospaced digits so meters and counters
    /// stay friendly and don't jitter as values change.
    public enum Metric {
        public static let countCompact = Font.system(size: 16, weight: .bold, design: .rounded).monospacedDigit()
    }
}
