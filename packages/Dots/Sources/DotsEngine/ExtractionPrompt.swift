import Foundation

/// The extraction pass: an attentive reader distills a saved source into
/// the few core ideas the piece itself argues, drafted for the writer's
/// review. Prompts are pure data — features stream them through whichever
/// provider is selected.
public enum ExtractionPrompt {
    /// The lead of an article carries its theses; the tail is truncated.
    public static let contentBudget = 24_000

    public static let instructions = """
        You are an attentive reader distilling a saved article for a \
        writer. Identify the 3 to 7 distinct core ideas the piece itself \
        makes — its theses, arguments, and claims — never your own \
        commentary, never summary padding. Express each idea as one \
        self-contained sentence, two at most, in plain prose. Reply with \
        ONLY a numbered list ("1. …"), one idea per line — nothing before \
        it, nothing after it.
        """

    /// Room for seven one-to-two-sentence ideas.
    public static let maxTokens = 500

    /// Recovers the numbered list from a possibly noisy response: accepts
    /// numbered and bulleted markers, strips surrounding emphasis, ignores
    /// preamble and epilogue prose, drops empties and exact duplicates, and
    /// caps at seven. An unparseable response returns [] — callers treat
    /// empty as failure; there is no retry loop.
    public static func parse(_ response: String) -> [String] {
        var ideas: [String] = []
        for line in response.components(separatedBy: "\n") {
            guard let item = listItem(of: line) else { continue }
            let text = strippingEmphasis(item)
            guard !text.isEmpty, !ideas.contains(text) else { continue }
            ideas.append(text)
            if ideas.count == maxIdeas {
                break
            }
        }
        return ideas
    }

    /// The user prompt: title plus the full extracted text, truncated at the
    /// content budget with a visible marker.
    public static func prompt(title: String, content: String) -> String {
        var text = String(content.prefix(contentBudget))
        if text.count < content.count {
            text += "\n[truncated]"
        }
        return [
            "--- TITLE ---",
            title,
            "--- FULL TEXT ---",
            text
        ].joined(separator: "\n")
    }

    private static let maxIdeas = 7

    /// The item text when the line is a list entry ("1. ", "1) ", "- ",
    /// "* "), nil for prose.
    private static func listItem(of line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            return String(trimmed.dropFirst(2))
        }
        let digits = trimmed.prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }
        let marker = trimmed.dropFirst(digits.count)
        guard marker.first == "." || marker.first == ")" else { return nil }
        guard let next = marker.dropFirst().first, next == " " else { return nil }
        return String(marker.dropFirst(2))
    }

    /// Trims whitespace and peels matched surrounding markdown emphasis.
    private static func strippingEmphasis(_ text: String) -> String {
        var stripped = text.trimmingCharacters(in: .whitespaces)
        for marker in ["**", "__", "*", "_"] {
            if stripped.hasPrefix(marker), stripped.hasSuffix(marker), stripped.count > marker.count * 2 {
                stripped = stripped
                    .dropFirst(marker.count)
                    .dropLast(marker.count)
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return stripped
    }
}
