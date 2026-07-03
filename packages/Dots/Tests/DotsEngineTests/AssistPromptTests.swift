import DotsEngine
import Testing

@Suite("AssistPrompt")
struct AssistPromptTests {
    @Test("Editing assists demarcate context from the edit target")
    func editPromptSections() {
        let prompt = AssistPrompt.prompt(
            for: .tighten,
            selection: "THE SELECTION",
            before: "words before.",
            after: "words after."
        )

        #expect(prompt.contains("--- CONTEXT BEFORE (reference only) ---\nwords before."))
        #expect(prompt.contains("--- CONTEXT AFTER (reference only) ---\nwords after."))
        #expect(prompt.hasSuffix("--- TEXT TO EDIT ---\nTHE SELECTION"))
    }

    @Test("Empty context windows leave no empty sections")
    func editPromptWithoutContext() {
        let prompt = AssistPrompt.prompt(
            for: .fixGrammar,
            selection: "Just this.",
            before: "",
            after: ""
        )

        #expect(prompt == "--- TEXT TO EDIT ---\nJust this.")
    }

    @Test("Context windows clamp to their budgets")
    func budgetsClamp() {
        let longBefore = String(repeating: "b", count: 5000)
        let longAfter = String(repeating: "a", count: 5000)
        let edit = AssistPrompt.prompt(
            for: .tighten,
            selection: "x",
            before: longBefore,
            after: longAfter
        )
        #expect(!edit.contains(String(repeating: "b", count: AssistPrompt.editBeforeBudget + 1)))
        #expect(!edit.contains(String(repeating: "a", count: AssistPrompt.afterBudget + 1)))

        let cont = AssistPrompt.prompt(
            for: .continueWriting,
            selection: "",
            before: longBefore,
            after: ""
        )
        #expect(cont.count == AssistPrompt.continueBeforeBudget)
    }

    @Test("Continue includes following text only when it exists")
    func continueBridging() {
        let atEnd = AssistPrompt.prompt(
            for: .continueWriting,
            selection: "",
            before: "The story so far.",
            after: ""
        )
        #expect(atEnd == "The story so far.")

        let midDocument = AssistPrompt.prompt(
            for: .continueWriting,
            selection: "",
            before: "The story so far.",
            after: "The ending."
        )
        #expect(midDocument.contains("--- TEXT THAT FOLLOWS THE INSERTION POINT (do not repeat) ---\nThe ending."))
    }

    @Test("Ask puts the writer's instruction above the usual sections")
    func customPromptShape() {
        let prompt = AssistPrompt.customPrompt(
            instruction: "turn into bullets",
            selection: "THE SELECTION",
            before: "before.",
            after: "after."
        )

        #expect(prompt.hasPrefix("--- WRITER'S INSTRUCTION ---\nturn into bullets\n"))
        #expect(prompt.contains("--- CONTEXT BEFORE (reference only) ---"))
        #expect(prompt.hasSuffix("--- TEXT TO EDIT ---\nTHE SELECTION"))
    }

    @Test("Every kind carries reply-with-only instructions")
    func instructionsAreStrict() {
        for kind in AssistKind.allCases {
            #expect(AssistPrompt.instructions(for: kind).contains("ONLY"))
        }
    }
}
