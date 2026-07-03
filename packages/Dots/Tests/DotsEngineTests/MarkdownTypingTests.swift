import DotsEngine
import Testing

@Suite("MarkdownTyping")
struct MarkdownTypingTests {
    // MARK: - Return: continuation

    @Test("A dash bullet with content continues with a dash")
    func dashBulletContinues() {
        #expect(MarkdownTyping.returnBehavior(forLine: "- item") == .continueMarker("- "))
    }

    @Test("Star and plus bullets keep their own bullet character")
    func starAndPlusBulletsKeepTheirCharacter() {
        #expect(MarkdownTyping.returnBehavior(forLine: "* item") == .continueMarker("* "))
        #expect(MarkdownTyping.returnBehavior(forLine: "+ item") == .continueMarker("+ "))
    }

    @Test("An indented bullet preserves its exact leading whitespace")
    func indentedBulletPreservesIndent() {
        #expect(MarkdownTyping.returnBehavior(forLine: "  - x") == .continueMarker("  - "))
        #expect(MarkdownTyping.returnBehavior(forLine: "    * deep") == .continueMarker("    * "))
    }

    @Test("An ordered item continues with the next number")
    func orderedIncrements() {
        #expect(MarkdownTyping.returnBehavior(forLine: "3. item") == .continueMarker("4. "))
    }

    @Test("Ordered increment carries into a new digit count")
    func orderedNineBecomesTen() {
        #expect(MarkdownTyping.returnBehavior(forLine: "9. item") == .continueMarker("10. "))
    }

    @Test("Paren ordered punctuation is preserved")
    func orderedParenPreserved() {
        #expect(MarkdownTyping.returnBehavior(forLine: "3) item") == .continueMarker("4) "))
    }

    @Test("An indented ordered item preserves indentation and increments")
    func indentedOrderedItem() {
        #expect(MarkdownTyping.returnBehavior(forLine: "  12. item") == .continueMarker("  13. "))
    }

    @Test("An unchecked task continues with a fresh unchecked box")
    func uncheckedTaskContinues() {
        #expect(MarkdownTyping.returnBehavior(forLine: "- [ ] task") == .continueMarker("- [ ] "))
    }

    @Test("Checked tasks of either case continue with a fresh unchecked box")
    func checkedTaskContinuesUnchecked() {
        #expect(MarkdownTyping.returnBehavior(forLine: "- [x] done") == .continueMarker("- [ ] "))
        #expect(MarkdownTyping.returnBehavior(forLine: "- [X] done") == .continueMarker("- [ ] "))
    }

    @Test("An indented task preserves its indentation")
    func indentedTaskPreservesIndent() {
        #expect(MarkdownTyping.returnBehavior(forLine: "    - [x] deep") == .continueMarker("    - [ ] "))
    }

    @Test("A quote line continues the quote")
    func quoteContinues() {
        #expect(MarkdownTyping.returnBehavior(forLine: "> quoted") == .continueMarker("> "))
        #expect(MarkdownTyping.returnBehavior(forLine: "  > nested") == .continueMarker("  > "))
    }

    @Test("Emoji content counts as content, not emptiness")
    func emojiContentContinues() {
        #expect(MarkdownTyping.returnBehavior(forLine: "- 🧠") == .continueMarker("- "))
    }

    // MARK: - Return: exit on empty items

    @Test("An empty bullet exits, deleting the whole marker")
    func emptyBulletExits() {
        #expect(MarkdownTyping.returnBehavior(forLine: "- ") == .exitEmptyItem(markerRange: 0..<2))
        #expect(MarkdownTyping.returnBehavior(forLine: "* ") == .exitEmptyItem(markerRange: 0..<2))
    }

    @Test("An empty indented bullet's range covers the indentation too")
    func emptyIndentedBulletRangeCoversIndent() {
        #expect(MarkdownTyping.returnBehavior(forLine: "  - ") == .exitEmptyItem(markerRange: 0..<4))
    }

    @Test("An empty ordered item exits, paren form included")
    func emptyOrderedItemExits() {
        #expect(MarkdownTyping.returnBehavior(forLine: "3. ") == .exitEmptyItem(markerRange: 0..<3))
        #expect(MarkdownTyping.returnBehavior(forLine: "12) ") == .exitEmptyItem(markerRange: 0..<4))
    }

    @Test("An empty task exits, checked or not")
    func emptyTaskExits() {
        #expect(MarkdownTyping.returnBehavior(forLine: "- [ ] ") == .exitEmptyItem(markerRange: 0..<6))
        #expect(MarkdownTyping.returnBehavior(forLine: "- [x] ") == .exitEmptyItem(markerRange: 0..<6))
        #expect(MarkdownTyping.returnBehavior(forLine: "  - [ ] ") == .exitEmptyItem(markerRange: 0..<8))
    }

    @Test("An empty quote exits")
    func emptyQuoteExits() {
        #expect(MarkdownTyping.returnBehavior(forLine: "> ") == .exitEmptyItem(markerRange: 0..<2))
    }

    @Test("Whitespace-only content still counts as empty, range spans it")
    func whitespaceOnlyContentExits() {
        #expect(MarkdownTyping.returnBehavior(forLine: "-   ") == .exitEmptyItem(markerRange: 0..<4))
    }

    // MARK: - Return: plain

    @Test("Plain prose gets a plain newline")
    func plainProseIsPlain() {
        #expect(MarkdownTyping.returnBehavior(forLine: "just a sentence") == .plain)
    }

    @Test("A hashtag-like line is not a marker")
    func hashtagIsPlain() {
        #expect(MarkdownTyping.returnBehavior(forLine: "#hashtag") == .plain)
        #expect(MarkdownTyping.returnBehavior(forLine: "# Heading") == .plain)
    }

    @Test("Marker lookalikes without the trailing space are plain")
    func markerLookalikesArePlain() {
        #expect(MarkdownTyping.returnBehavior(forLine: "-dash word") == .plain)
        #expect(MarkdownTyping.returnBehavior(forLine: "1.item") == .plain)
        #expect(MarkdownTyping.returnBehavior(forLine: ">quote") == .plain)
    }

    @Test("Empty and whitespace-only lines are plain")
    func emptyLinesArePlain() {
        #expect(MarkdownTyping.returnBehavior(forLine: "") == .plain)
        #expect(MarkdownTyping.returnBehavior(forLine: "   ") == .plain)
    }

    // MARK: - Tab: marker detection

    @Test(
        "Block markers are recognized for Tab handling",
        arguments: ["- a", "* a", "+ a", "3. a", "3) a", "- [ ] a", "- [x] a", "> a", "  - a"]
    )
    func hasBlockMarkerRecognizesMarkers(line: String) {
        #expect(MarkdownTyping.hasBlockMarker(line))
    }

    @Test(
        "Non-marker lines are not Tab targets",
        arguments: ["plain", "", "-x", "#hashtag", "# Heading", "1.item"]
    )
    func hasBlockMarkerRejectsNonMarkers(line: String) {
        #expect(!MarkdownTyping.hasBlockMarker(line))
    }

    // MARK: - Tab: indent and outdent

    @Test("Indent prepends exactly two spaces")
    func indentPrependsTwoSpaces() {
        #expect(MarkdownTyping.indented("- a") == "  - a")
        #expect(MarkdownTyping.indented("  - a") == "    - a")
        #expect(MarkdownTyping.indented("") == "  ")
    }

    @Test("Outdent removes up to two leading spaces")
    func outdentRemovesUpToTwoSpaces() {
        #expect(MarkdownTyping.outdented("    - a") == "  - a")
        #expect(MarkdownTyping.outdented("  - a") == "- a")
        #expect(MarkdownTyping.outdented(" - a") == "- a")
        #expect(MarkdownTyping.outdented("- a") == "- a")
    }

    @Test("Indent then outdent round-trips")
    func indentOutdentRoundTrip() {
        let lines = ["- a", "  3. b", "> c", "plain"]
        for line in lines {
            #expect(MarkdownTyping.outdented(MarkdownTyping.indented(line)) == line)
        }
    }
}
