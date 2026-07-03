import DotsEngine
import Testing

@Suite("MarkdownFormatting")
struct MarkdownFormattingTests {
    // MARK: - Inline styles

    @Test("Bold wraps the selection and selects the content")
    func boldWrapsSelection() {
        let result = MarkdownFormatting.toggle(.bold, in: "one two three", selection: 4..<7)
        #expect(result.text == "one **two** three")
        #expect(result.selection == 6..<9)
    }

    @Test("Bold unwraps when the selection includes the delimiters")
    func boldUnwrapsSelectionIncludingDelimiters() {
        let result = MarkdownFormatting.toggle(.bold, in: "a **b** c", selection: 2..<7)
        #expect(result.text == "a b c")
        #expect(result.selection == 2..<3)
    }

    @Test("Bold unwraps when the delimiters surround the selection")
    func boldUnwrapsSurroundingDelimiters() {
        let result = MarkdownFormatting.toggle(.bold, in: "a **b** c", selection: 4..<5)
        #expect(result.text == "a b c")
        #expect(result.selection == 2..<3)
    }

    @Test("Empty selection inserts a delimiter pair with the caret between")
    func emptySelectionInsertsPairAroundCaret() {
        let result = MarkdownFormatting.toggle(.bold, in: "ab cd", selection: 2..<2)
        #expect(result.text == "ab**** cd")
        #expect(result.selection == 4..<4)

        let again = MarkdownFormatting.toggle(.bold, in: result.text, selection: result.selection)
        #expect(again.text == "ab cd")
        #expect(again.selection == 2..<2)
    }

    @Test("Italic on a selected bold span wraps additionally")
    func italicOnSelectedBoldWrapsAdditionally() {
        let result = MarkdownFormatting.toggle(.italic, in: "**x**", selection: 0..<5)
        #expect(result.text == "***x***")
        #expect(result.selection == 1..<6)
    }

    @Test("Italic inside bold-italic content strips only the single-star pair")
    func italicInsideBoldItalicStripsSinglePair() {
        let result = MarkdownFormatting.toggle(.italic, in: "***x***", selection: 3..<4)
        #expect(result.text == "**x**")
        #expect(result.selection == 2..<3)
    }

    @Test("Code wraps and unwraps back to the original")
    func codeRoundTrip() {
        let wrapped = MarkdownFormatting.toggle(.code, in: "call foo now", selection: 5..<8)
        #expect(wrapped.text == "call `foo` now")
        #expect(wrapped.selection == 6..<9)

        let unwrapped = MarkdownFormatting.toggle(.code, in: wrapped.text, selection: wrapped.selection)
        #expect(unwrapped.text == "call foo now")
        #expect(unwrapped.selection == 5..<8)
    }

    @Test("Strikethrough wraps and unwraps back to the original")
    func strikethroughRoundTrip() {
        let wrapped = MarkdownFormatting.toggle(.strikethrough, in: "drop this word", selection: 5..<9)
        #expect(wrapped.text == "drop ~~this~~ word")
        #expect(wrapped.selection == 7..<11)

        let unwrapped = MarkdownFormatting.toggle(.strikethrough, in: wrapped.text, selection: wrapped.selection)
        #expect(unwrapped.text == "drop this word")
        #expect(unwrapped.selection == 5..<9)
    }

    @Test(
        "Toggling twice restores the original text and selection",
        arguments: [
            MarkdownFormatting.InlineStyle.bold,
            MarkdownFormatting.InlineStyle.code,
            MarkdownFormatting.InlineStyle.italic,
            MarkdownFormatting.InlineStyle.strikethrough
        ]
    )
    func toggleTwiceRoundTrips(style: MarkdownFormatting.InlineStyle) {
        let original = "alpha beta gamma"
        let once = MarkdownFormatting.toggle(style, in: original, selection: 6..<10)
        let twice = MarkdownFormatting.toggle(style, in: once.text, selection: once.selection)
        #expect(twice.text == original)
        #expect(twice.selection == 6..<10)
    }

    @Test("Offsets are UTF-16 code units when emoji precede the selection")
    func emojiPrefixKeepsOffsetsCorrect() {
        // Each 🧠 is two UTF-16 code units, so "brain" spans 5..<10.
        let result = MarkdownFormatting.toggle(.bold, in: "🧠🧠 brain", selection: 5..<10)
        #expect(result.text == "🧠🧠 **brain**")
        #expect(result.selection == 7..<12)
    }

    @Test("An out-of-bounds selection is clamped instead of crashing")
    func outOfBoundsSelectionIsClamped() {
        let result = MarkdownFormatting.toggle(.bold, in: "ab", selection: 10..<20)
        #expect(result.text == "ab****")
        #expect(result.selection == 4..<4)
    }

    // MARK: - Headings

    @Test("Heading toggle sets the prefix and selects the line")
    func headingSet() {
        let result = MarkdownFormatting.toggle(.heading(2), in: "Title", selection: 3..<3)
        #expect(result.text == "## Title")
        #expect(result.selection == 0..<8)
    }

    @Test("Heading toggle replaces a different heading level")
    func headingReplace() {
        let result = MarkdownFormatting.toggle(.heading(3), in: "# Title", selection: 0..<0)
        #expect(result.text == "### Title")
        #expect(result.selection == 0..<9)
    }

    @Test("Heading toggle removes a matching prefix")
    func headingRemove() {
        let result = MarkdownFormatting.toggle(.heading(2), in: "## Title", selection: 4..<4)
        #expect(result.text == "Title")
        #expect(result.selection == 0..<5)
    }

    @Test("A caret-only heading toggle affects just its own line")
    func caretOnlyHeadingToggle() {
        let result = MarkdownFormatting.toggle(.heading(1), in: "one\ntwo\nthree", selection: 5..<5)
        #expect(result.text == "one\n# two\nthree")
        #expect(result.selection == 4..<9)
    }

    // MARK: - Quotes

    @Test("Quote add marks every non-empty line and skips empty ones")
    func quoteAddSkipsEmptyLines() {
        let result = MarkdownFormatting.toggle(.quote, in: "alpha\n\nbeta", selection: 0..<11)
        #expect(result.text == "> alpha\n\n> beta")
        #expect(result.selection == 0..<15)
    }

    @Test("Quote remove strips the marker from every line")
    func quoteRemoveMultiLine() {
        let result = MarkdownFormatting.toggle(.quote, in: "> alpha\n> beta", selection: 0..<14)
        #expect(result.text == "alpha\nbeta")
        #expect(result.selection == 0..<10)
    }

    @Test("Quote remove recognizes a bare angle without a trailing space")
    func quoteRemoveWithoutSpace() {
        let result = MarkdownFormatting.toggle(.quote, in: "> alpha\n>beta", selection: 0..<13)
        #expect(result.text == "alpha\nbeta")
        #expect(result.selection == 0..<10)
    }

    // MARK: - Bullets and ordered lists

    @Test("Bullet add converts existing ordered markers")
    func orderedToBulletConversion() {
        let result = MarkdownFormatting.toggle(.bullet, in: "1. alpha\n2. beta", selection: 0..<16)
        #expect(result.text == "- alpha\n- beta")
        #expect(result.selection == 0..<14)
    }

    @Test("Bullet remove recognizes star and dash markers alike")
    func bulletRemoveRecognizesVariants() {
        let result = MarkdownFormatting.toggle(.bullet, in: "* alpha\n- beta", selection: 0..<14)
        #expect(result.text == "alpha\nbeta")
        #expect(result.selection == 0..<10)
    }

    @Test("Ordered add converts existing bullet markers with sequential numbers")
    func bulletToOrderedConversion() {
        let result = MarkdownFormatting.toggle(.ordered, in: "- alpha\n- beta", selection: 0..<14)
        #expect(result.text == "1. alpha\n2. beta")
        #expect(result.selection == 0..<16)
    }

    @Test("Ordered numbering skips a blank middle line without consuming a number")
    func orderedNumberingSkipsBlankLine() {
        let result = MarkdownFormatting.toggle(.ordered, in: "alpha\nbeta\n\ngamma", selection: 0..<17)
        #expect(result.text == "1. alpha\n2. beta\n\n3. gamma")
        #expect(result.selection == 0..<26)
    }

    @Test("Ordered remove strips markers, recognizing the paren form")
    func orderedRemoveRecognizesParenForm() {
        let result = MarkdownFormatting.toggle(.ordered, in: "1. alpha\n2) beta", selection: 0..<16)
        #expect(result.text == "alpha\nbeta")
        #expect(result.selection == 0..<10)
    }

    // MARK: - Line-boundary edge cases

    @Test("A non-empty selection ending at a line start excludes that line")
    func selectionEndingAtLineStartExcludesTrailingLine() {
        let result = MarkdownFormatting.toggle(.bullet, in: "alpha\nbeta\ngamma", selection: 0..<11)
        #expect(result.text == "- alpha\n- beta\ngamma")
        #expect(result.selection == 0..<14)
    }

    @Test("A caret at a line start counts as that line")
    func caretAtLineStartCountsAsItsLine() {
        let result = MarkdownFormatting.toggle(.bullet, in: "alpha\nbeta", selection: 6..<6)
        #expect(result.text == "alpha\n- beta")
        #expect(result.selection == 6..<12)
    }

    // MARK: - Links

    @Test("Link insertion keeps the selected text and selects the placeholder")
    func linkWithSelection() {
        let result = MarkdownFormatting.insertLink(in: "see docs here", selection: 4..<8)
        #expect(result.text == "see [docs](url) here")
        #expect(result.selection == 11..<14)
    }

    @Test("Link insertion at a caret leaves the text slot empty")
    func linkWithCaret() {
        let result = MarkdownFormatting.insertLink(in: "ab", selection: 1..<1)
        #expect(result.text == "a[](url)b")
        #expect(result.selection == 4..<7)
    }
}
