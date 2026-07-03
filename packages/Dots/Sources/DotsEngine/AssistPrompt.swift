/// The selection assists: small, surgical writing actions. Prompts are pure
/// data — features stream them through whichever provider is selected.
public enum AssistKind: String, CaseIterable, Equatable, Sendable {
    /// Wispr-Flow-grade dictation cleanup: artifacts out, words untouched.
    /// Internal to the dictation flow, never in menus.
    case cleanupDictation
    case continueWriting
    case expand
    case fixGrammar
    case formatMarkdown
    /// The writer's own instruction, applied to the selection ("Ask").
    case prompt
    case tighten

    public var displayName: String {
        switch self {
        case .cleanupDictation: "Clean up dictation"
        case .continueWriting: "Continue"
        case .expand: "Expand"
        case .fixGrammar: "Fix grammar"
        case .formatMarkdown: "Format as markdown"
        case .prompt: "Ask"
        case .tighten: "Tighten"
        }
    }

    /// The selection verbs, in menu order. Continuation is not a menu item —
    /// it's the Tab-summoned ghost completion.
    public static let menuKinds: [AssistKind] = [.fixGrammar, .tighten, .expand, .formatMarkdown]

    /// Continue works from the caret; the others need a selection.
    public var needsSelection: Bool {
        self != .continueWriting
    }
}

public enum AssistPrompt {
    /// Context budgets, sized so selection + windows fit the on-device
    /// model's ~4K-token context comfortably. Continue leans on what came
    /// before; edits get a lighter view both ways.
    public static let continueBeforeBudget = 2000
    public static let editBeforeBudget = 1200
    public static let afterBudget = 400

    public static func instructions(for kind: AssistKind) -> String {
        switch kind {
        case .continueWriting:
            """
            You continue drafts for a writer. Match their voice, tone, and \
            markdown conventions exactly. If text following the insertion \
            point is provided, write so your continuation flows into it. \
            Reply with ONLY the continuation text — no preamble, no \
            quotation marks, no commentary, and never repeat the \
            surrounding text.
            """
        case .cleanupDictation:
            """
            You clean up dictated speech. Remove ONLY audio artifacts from \
            the TEXT TO EDIT: filler words (um, uh, like, you know), false \
            starts, and self-corrections (when the speaker corrects \
            themselves, keep only the correction). Fix punctuation, \
            capitalization, and paragraph breaks. PRESERVE the speaker's \
            exact words and voice otherwise — never rephrase, never \
            summarize, never restructure. Reply with ONLY the cleaned text.
            """
        case .expand:
            """
            You are a developmental editor. The surrounding context is \
            reference only — expand the TEXT TO EDIT: develop its idea more \
            fully, in the writer's voice and markdown conventions, keeping \
            its register consistent with the context. Reply with ONLY the \
            expanded replacement for the text to edit.
            """
        case .fixGrammar:
            """
            You are a copy editor. The surrounding context is reference \
            only — fix grammar, spelling, and punctuation in the TEXT TO \
            EDIT alone. Preserve the writer's voice, word choice, line \
            breaks, and markdown syntax exactly. Reply with ONLY the \
            corrected replacement for the text to edit.
            """
        case .prompt:
            """
            You are a writing collaborator. Apply the WRITER'S INSTRUCTION \
            to the TEXT TO EDIT — and only to it; the surrounding context \
            is reference. Match the writer's voice and markdown \
            conventions unless the instruction says otherwise. Reply with \
            ONLY the replacement text — no preamble, no commentary.
            """
        case .formatMarkdown:
            """
            You convert rough text into clean markdown structure — headings, \
            lists, emphasis, quotes — changing the words themselves as \
            little as possible. The surrounding context is reference only \
            (match its heading levels and conventions); transform the TEXT \
            TO EDIT alone. Reply with ONLY the formatted replacement.
            """
        case .tighten:
            """
            You are a line editor. The surrounding context is reference \
            only — rewrite the TEXT TO EDIT more concisely without losing \
            meaning, voice, or markdown formatting, and keep its register \
            consistent with the context. Reply with ONLY the tightened \
            replacement for the text to edit.
            """
        }
    }

    /// The Ask prompt: the writer's instruction rides above the usual
    /// context/selection sections.
    public static func customPrompt(
        instruction: String,
        selection: String,
        before: String,
        after: String
    ) -> String {
        let body = prompt(for: .prompt, selection: selection, before: before, after: after)
        return "--- WRITER'S INSTRUCTION ---\n\(instruction)\n\(body)"
    }

    /// The user prompt. Editing assists see the selection plus demarcated
    /// before/after windows (reference, never edit target); Continue sees
    /// what precedes the caret and a glimpse of what follows so mid-document
    /// continuations bridge instead of colliding.
    public static func prompt(
        for kind: AssistKind,
        selection: String,
        before: String,
        after: String
    ) -> String {
        switch kind {
        case .continueWriting:
            var parts = [String(before.suffix(continueBeforeBudget))]
            let following = String(after.prefix(afterBudget))
            if !following.isEmpty {
                parts.append("--- TEXT THAT FOLLOWS THE INSERTION POINT (do not repeat) ---")
                parts.append(following)
            }
            return parts.joined(separator: "\n")
        case .cleanupDictation, .expand, .fixGrammar, .formatMarkdown, .prompt, .tighten:
            var parts: [String] = []
            let preceding = String(before.suffix(editBeforeBudget))
            if !preceding.isEmpty {
                parts.append("--- CONTEXT BEFORE (reference only) ---")
                parts.append(preceding)
            }
            let following = String(after.prefix(afterBudget))
            if !following.isEmpty {
                parts.append("--- CONTEXT AFTER (reference only) ---")
                parts.append(following)
            }
            parts.append("--- TEXT TO EDIT ---")
            parts.append(selection)
            return parts.joined(separator: "\n")
        }
    }
}
