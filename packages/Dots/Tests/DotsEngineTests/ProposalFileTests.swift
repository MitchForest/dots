import DotsDomain
import DotsEngine
import Foundation
import Testing

@Suite("ProposalFile")
struct ProposalFileTests {
    private let proposal = IdeaProposal(
        id: IdeaProposal.ID("01J2PROPOSAL"),
        sourceId: Source.ID("01J1SOURCE"),
        ideas: [
            ProposedIdea(id: 1, text: "First idea, already accepted.", status: .accepted),
            ProposedIdea(id: 2, text: "Second idea ✨ still pending.", status: .pending),
            ProposedIdea(id: 3, text: "Third idea, discarded.", status: .discarded)
        ],
        createdAt: Date(timeIntervalSince1970: 1_782_034_200),
        author: "dots-extract",
        status: .open
    )

    @Test("Render emits the target.md proposal schema")
    func renderSchema() throws {
        let data = ProposalFile.render(proposal)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["version"] as? Int == 1)
        #expect(object["kind"] as? String == "ideas")
        #expect(object["id"] as? String == "01J2PROPOSAL")
        #expect(object["sourceId"] as? String == "01J1SOURCE")
        #expect(object["author"] as? String == "dots-extract")
        #expect(object["createdAt"] as? String == "2026-06-21T09:30:00Z")
        #expect(object["status"] as? String == "open")

        let ideas = try #require(object["ideas"] as? [[String: Any]])
        #expect(ideas.count == 3)
        #expect(ideas[0]["id"] as? Int == 1)
        #expect(ideas[0]["text"] as? String == "First idea, already accepted.")
        #expect(ideas[0]["status"] as? String == "accepted")
        #expect(ideas[1]["status"] as? String == "pending")
        #expect(ideas[2]["status"] as? String == "discarded")

        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasSuffix("}\n"))
    }

    @Test("Render is byte-stable across calls (git diffs stay quiet)")
    func renderStability() {
        #expect(ProposalFile.render(proposal) == ProposalFile.render(proposal))
    }

    @Test("Round-trips mixed idea statuses losslessly")
    func roundTrip() {
        #expect(ProposalFile.parse(ProposalFile.render(proposal)) == proposal)
    }

    @Test("Round-trips applied and dismissed proposal statuses")
    func roundTripProposalStatuses() {
        for status in [IdeaProposal.Status.applied, .dismissed] {
            var variant = proposal
            variant.status = status
            #expect(ProposalFile.parse(ProposalFile.render(variant)) == variant)
        }
    }

    @Test("Returns nil for an edit-kind proposal sharing the directory")
    func parseRejectsEditKind() {
        let edit = Data(
            """
            {
              "version": 1,
              "kind": "edit",
              "id": "01J2EDIT",
              "target": "drafts/my-essay.md",
              "baseBlob": "a94a8fe5",
              "author": "claude-code",
              "hunks": [],
              "status": "open"
            }
            """.utf8
        )
        #expect(ProposalFile.parse(edit) == nil)
    }

    @Test("Returns nil when kind is wrong or missing on an otherwise valid file")
    func parseRejectsForeignKind() throws {
        let wrongKind = try rendered { $0["kind"] = "edit" }
        #expect(ProposalFile.parse(wrongKind) == nil)

        let missingKind = try rendered { $0["kind"] = nil }
        #expect(ProposalFile.parse(missingKind) == nil)
    }

    @Test("Returns nil for an unknown version")
    func parseRejectsUnknownVersion() throws {
        let futureVersion = try rendered { $0["version"] = 2 }
        #expect(ProposalFile.parse(futureVersion) == nil)
    }

    @Test("Returns nil for unknown status strings")
    func parseRejectsUnknownStatuses() throws {
        let unknownProposalStatus = try rendered { $0["status"] = "archived" }
        #expect(ProposalFile.parse(unknownProposalStatus) == nil)

        let unknownIdeaStatus = try rendered { object in
            var ideas = object["ideas"] as? [[String: Any]] ?? []
            ideas[1]["status"] = "maybe"
            object["ideas"] = ideas
        }
        #expect(ProposalFile.parse(unknownIdeaStatus) == nil)
    }

    @Test("Returns nil for junk data")
    func parseRejectsJunk() {
        #expect(ProposalFile.parse(Data()) == nil)
        #expect(ProposalFile.parse(Data("not json at all".utf8)) == nil)
        #expect(ProposalFile.parse(Data("[1, 2, 3]".utf8)) == nil)
        #expect(ProposalFile.parse(Data("{\"version\": 1, \"kind\": \"ideas\"}".utf8)) == nil)
    }

    /// The fixture rendered, mutated as JSON, and re-serialized — corruption
    /// without depending on the encoder's exact formatting.
    private func rendered(mutating: (inout [String: Any]) -> Void) throws -> Data {
        let data = ProposalFile.render(proposal)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        mutating(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }
}
