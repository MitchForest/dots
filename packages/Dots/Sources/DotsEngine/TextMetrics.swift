import Foundation

/// Pure text measurements used by the editor chrome (word counts, etc.).
public enum TextMetrics {
    /// Word count for markdown prose: syntax tokens (`>`, `#`, `-`, `---`,
    /// fence markers, link URLs) don't count — only tokens carrying letters
    /// or digits do.
    public static func wordCount(in text: String) -> Int {
        let withoutLinkTargets = text.replacingOccurrences(
            of: #"\]\([^)]*\)"#,
            with: "]",
            options: .regularExpression
        )
        return withoutLinkTargets
            .split(whereSeparator: \.isWhitespace)
            .filter { token in
                token.contains { $0.isLetter || $0.isNumber }
            }
            .count
    }
}
