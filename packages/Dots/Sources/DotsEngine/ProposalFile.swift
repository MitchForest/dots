public import DotsDomain
public import Foundation

/// Codec for idea-proposal files (`.dots/proposals/<ulid>.json`).
/// Mirrors the proposals schema in .docs/target.md; `render(_:)` → `parse(_:)`
/// round-trips. The directory also holds edit proposals (the 3.x kind), so
/// the JSON carries a `kind` discriminator; sorted, pretty-printed keys keep
/// git diffs stable.
public enum ProposalFile {
    /// Parses an idea-proposal file. Returns nil for malformed JSON, a
    /// missing or foreign `kind` (an edit proposal in the same directory is
    /// simply not ours), an unknown version, or an unknown status string.
    public static func parse(_ data: Data) -> IdeaProposal? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(File.self, from: data) else { return nil }
        guard file.kind == kind, file.version == version else { return nil }
        guard let status = IdeaProposal.Status(rawValue: file.status) else { return nil }

        var ideas: [ProposedIdea] = []
        for idea in file.ideas {
            guard let ideaStatus = ProposedIdea.Status(rawValue: idea.status) else { return nil }
            ideas.append(ProposedIdea(id: idea.id, text: idea.text, status: ideaStatus))
        }

        return IdeaProposal(
            id: IdeaProposal.ID(file.id),
            sourceId: Source.ID(file.sourceId),
            ideas: ideas,
            createdAt: file.createdAt,
            author: file.author,
            status: status
        )
    }

    /// Renders a proposal to canonical file contents: sorted keys, pretty
    /// printing, ISO8601 dates, trailing newline.
    public static func render(_ proposal: IdeaProposal) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let file = File(
            author: proposal.author,
            createdAt: proposal.createdAt,
            id: proposal.id.rawValue,
            ideas: proposal.ideas.map { Idea(id: $0.id, status: $0.status.rawValue, text: $0.text) },
            kind: kind,
            sourceId: proposal.sourceId.rawValue,
            status: proposal.status.rawValue,
            version: version
        )
        // Encoding a plain value tree cannot fail; the fallback keeps the
        // signature honest without a crash path.
        let json = (try? encoder.encode(file)) ?? Data()
        return json + Data("\n".utf8)
    }

    /// The on-disk shape. Statuses travel as raw strings so unknown values
    /// reject in `parse(_:)` instead of crashing inside Codable.
    private struct File: Codable {
        var author: String
        var createdAt: Date
        var id: String
        var ideas: [Idea]
        var kind: String
        var sourceId: String
        var status: String
        var version: Int
    }

    private struct Idea: Codable {
        var id: Int
        var status: String
        var text: String
    }

    private static let kind = "ideas"
    private static let version = 1
}
