import DotsEngine
import Testing

@Suite("CompletionPrompt")
struct CompletionPromptTests {
    @Test("Caret position classifies mid-sentence, sentence start, and lists")
    func positions() {
        #expect(CompletionPrompt.position(before: "The idea is") == .midSentence)
        #expect(CompletionPrompt.position(before: "It works. But the") == .midSentence)
        #expect(CompletionPrompt.position(before: "It works.") == .sentenceStart)
        #expect(CompletionPrompt.position(before: "It works. ") == .sentenceStart)
        #expect(CompletionPrompt.position(before: "Really?") == .sentenceStart)
        #expect(CompletionPrompt.position(before: "Wait…") == .sentenceStart)
        #expect(CompletionPrompt.position(before: "") == .sentenceStart)
        #expect(CompletionPrompt.position(before: "Intro.\n\n") == .sentenceStart)
        #expect(CompletionPrompt.position(before: "Intro.\n- first item") == .listItem)
        #expect(CompletionPrompt.position(before: "Intro.\n3. numbered") == .listItem)
        #expect(CompletionPrompt.position(before: "Intro.\n- [ ] task") == .listItem)
        // A finished list line followed by a fresh line is prose again.
        #expect(CompletionPrompt.position(before: "- item\nAnd then") == .midSentence)
    }

    @Test("Glue separates words, respects existing whitespace and openers")
    func glue() {
        #expect(CompletionPrompt.leadingGlue(before: "ends with word") == " ")
        #expect(CompletionPrompt.leadingGlue(before: "ends with period.") == " ")
        #expect(CompletionPrompt.leadingGlue(before: "trailing space ").isEmpty)
        #expect(CompletionPrompt.leadingGlue(before: "newline\n").isEmpty)
        #expect(CompletionPrompt.leadingGlue(before: "open (").isEmpty)
        #expect(CompletionPrompt.leadingGlue(before: "dash—").isEmpty)
        #expect(CompletionPrompt.leadingGlue(before: "").isEmpty)
    }

    @Test("Instructions are position-specific and concise-bounded")
    func instructions() {
        #expect(CompletionPrompt.instructions(for: .midSentence).contains("complete the current sentence"))
        #expect(CompletionPrompt.instructions(for: .sentenceStart).contains("one logical next sentence"))
        #expect(CompletionPrompt.instructions(for: .listItem).contains("next item"))
        #expect(CompletionPrompt.maxTokens <= 80)
    }

    @Test("Prompt includes a do-not-repeat glimpse of following text")
    func promptShape() {
        let atEnd = CompletionPrompt.prompt(before: "Before.", after: "")
        #expect(atEnd == "Before.")

        let mid = CompletionPrompt.prompt(before: "Before.", after: "After.")
        #expect(mid.contains("do not repeat"))
        #expect(mid.hasSuffix("After."))
    }
}
