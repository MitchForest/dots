import Foundation

/// The Tab-summoned completion, made contextual: what the ghost proposes
/// depends on where the caret sits — finish the sentence, offer the next
/// one, or add the next list item. Always concise; never a paragraph.
public enum CompletionPrompt {
    public enum Position: Equatable, Sendable {
        /// The caret's line is a list/task item.
        case listItem
        /// Inside an unfinished sentence.
        case midSentence
        /// After a completed sentence (or at fresh, empty ground).
        case sentenceStart
    }

    /// A hard cap the instructions can't talk their way past.
    public static let maxTokens = 60
    public static let beforeBudget = 2000
    public static let afterBudget = 300

    /// Classifies the caret from the text before it.
    public static func position(before: String) -> Position {
        let line = currentLine(of: before)
        if MarkdownTyping.hasBlockMarker(line) {
            return .listItem
        }
        let trimmed = before.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.unicodeScalars.last else { return .sentenceStart }
        return ".;!?…".unicodeScalars.contains(last) ? .sentenceStart : .midSentence
    }

    public static func instructions(for position: Position) -> String {
        switch position {
        case .listItem:
            """
            You complete lists for a writer, in their voice. If the current \
            list item is unfinished, reply with only the words that finish \
            it. If it reads complete, reply with a newline followed by the \
            single next item, using the same marker style. One item at most; \
            no commentary.
            """
        case .midSentence:
            """
            You finish sentences for a writer, in their voice. Reply with \
            ONLY the words that complete the current sentence, including \
            its final punctuation. Never write a second sentence, never \
            repeat what's already written, no commentary.
            """
        case .sentenceStart:
            """
            You suggest the next sentence for a writer, in their voice. \
            Reply with ONLY one logical next sentence — never more than \
            one, never a paragraph, no commentary, never repeat what's \
            already written.
            """
        }
    }

    /// Mechanical spacing: what must be inserted before the model's reply so
    /// it doesn't weld onto the last word. Applied only when the reply
    /// doesn't begin with its own whitespace.
    public static func leadingGlue(before: String) -> String {
        guard let last = before.unicodeScalars.last else { return "" }
        if CharacterSet.whitespacesAndNewlines.contains(last) {
            return ""
        }
        // Openers hug what follows them.
        if "([{\u{201C}\u{2018}\"'—–-/".unicodeScalars.contains(last) {
            return ""
        }
        return " "
    }

    public static func prompt(before: String, after: String) -> String {
        var parts = [String(before.suffix(beforeBudget))]
        let following = String(after.prefix(afterBudget))
        if !following.isEmpty {
            parts.append("--- TEXT THAT FOLLOWS THE INSERTION POINT (do not repeat) ---")
            parts.append(following)
        }
        return parts.joined(separator: "\n")
    }

    private static func currentLine(of before: String) -> String {
        if let newline = before.lastIndex(of: "\n") {
            return String(before[before.index(after: newline)...])
        }
        return before
    }
}
