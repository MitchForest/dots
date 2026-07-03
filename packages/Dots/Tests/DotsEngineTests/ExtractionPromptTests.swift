import DotsEngine
import Testing

@Suite("ExtractionPrompt")
struct ExtractionPromptTests {
    @Test("Instructions demand the piece's own ideas as a bare numbered list")
    func instructions() {
        #expect(ExtractionPrompt.instructions.contains("3 to 7"))
        #expect(ExtractionPrompt.instructions.contains("numbered list"))
        #expect(ExtractionPrompt.maxTokens >= 400)
    }

    @Test("Prompt sections title and full text")
    func promptShape() {
        let prompt = ExtractionPrompt.prompt(title: "Deep Work", content: "The full text.")

        #expect(prompt == "--- TITLE ---\nDeep Work\n--- FULL TEXT ---\nThe full text.")
        #expect(!prompt.contains("[truncated]"))
    }

    @Test("Prompt truncates content at the budget with a visible marker")
    func promptTruncation() {
        let content = String(repeating: "x", count: ExtractionPrompt.contentBudget + 5_000)
        let prompt = ExtractionPrompt.prompt(title: "Long Read", content: content)

        #expect(prompt.hasSuffix("\n[truncated]"))
        let body = prompt.filter { $0 == "x" }
        #expect(body.count == ExtractionPrompt.contentBudget)

        let exact = ExtractionPrompt.prompt(
            title: "Exact",
            content: String(repeating: "x", count: ExtractionPrompt.contentBudget)
        )
        #expect(!exact.contains("[truncated]"))
    }

    @Test("Parses a clean numbered list")
    func parseClean() {
        let response = """
        1. Attention is the scarce resource.
        2. Depth beats volume.
        3. Rituals lower the cost of starting.
        """

        #expect(ExtractionPrompt.parse(response) == [
            "Attention is the scarce resource.",
            "Depth beats volume.",
            "Rituals lower the cost of starting."
        ])
    }

    @Test("Ignores preamble and epilogue, strips markdown emphasis")
    func parseNoisy() {
        let response = """
        Here are the core ideas I found in the article:

        1. **Attention is the scarce resource.**
        2. _Depth beats volume._
        3. Rituals lower the cost of starting.

        Let me know if you'd like me to expand on any of these!
        """

        #expect(ExtractionPrompt.parse(response) == [
            "Attention is the scarce resource.",
            "Depth beats volume.",
            "Rituals lower the cost of starting."
        ])
    }

    @Test("Accepts paren-numbered and bulleted variants")
    func parseMarkerVariants() {
        let response = """
        1) First idea.
        - Second idea.
        * Third idea.
          2. Indented fourth idea.
        """

        #expect(ExtractionPrompt.parse(response) == [
            "First idea.",
            "Second idea.",
            "Third idea.",
            "Indented fourth idea."
        ])
    }

    @Test("Drops empties and exact duplicates")
    func parseDuplicates() {
        let response = """
        1. Same idea.
        2. Same idea.
        3.
        4. Other idea.
        """

        #expect(ExtractionPrompt.parse(response) == ["Same idea.", "Other idea."])
    }

    @Test("Caps the list at seven ideas")
    func parseCap() {
        let response = (1...10).map { "\($0). Idea number \($0)." }.joined(separator: "\n")
        let ideas = ExtractionPrompt.parse(response)

        #expect(ideas.count == 7)
        #expect(ideas.last == "Idea number 7.")
    }

    @Test("Garbage parses to empty — callers treat empty as failure")
    func parseGarbage() {
        #expect(ExtractionPrompt.parse("").isEmpty)
        #expect(ExtractionPrompt.parse("The article discusses many things at length.").isEmpty)
        #expect(ExtractionPrompt.parse("Sorry, I can't help with that.").isEmpty)
        #expect(ExtractionPrompt.parse("2026 was the year everything changed.").isEmpty)
    }
}
