public import CoreGraphics

/// Corner-radius scale. The primitive steps (`none`…`xxl`) are the raw values;
/// the `Semantic` namespace names the role each surface plays so callers ask for
/// "card" or "panel" intent rather than a bare number. Modest radii throughout —
/// rectangles with a soft corner, never pills (capsules are a separate, explicit
/// choice for true progress meters).
public enum DotsRadius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 8
    public static let xl: CGFloat = 16
    public static let xxl: CGFloat = 20

    /// Role-named radii. Every surface should reference one of these, not a raw
    /// step, so the curvature hierarchy (medallion < control < card < panel) stays
    /// coherent as the scale evolves.
    public enum Semantic {
        /// Small square status cells (`DotsStatusMark`, chip medallions).
        public static let medallion = DotsRadius.xs
        /// Compact controls: chips, count pills, icon-button backgrounds.
        public static let control = DotsRadius.md
        /// Chips and labels.
        public static let chip = DotsRadius.md
        /// Content cards (problem-set cards, error/info surfaces).
        public static let card = DotsRadius.xl
        /// Floating glass panels: top bar, control rail, overlays, login panel.
        public static let panel = DotsRadius.xxl
    }
}
