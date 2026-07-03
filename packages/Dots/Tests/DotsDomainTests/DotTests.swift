import DotsDomain
import Foundation
import Testing

@Suite("Dot")
struct DotTests {
    @Test("Optional fields default to empty")
    func optionalFieldsDefaultToEmpty() {
        let dot = Dot(
            id: Dot.ID("01JZ0000000000000000000000"),
            content: "We read to collect dots.",
            capturedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(dot.folder == nil)
        #expect(dot.isExtraction == false)
        #expect(dot.references.isEmpty)
        #expect(dot.source == nil)
        #expect(dot.tags.isEmpty)
    }
}
