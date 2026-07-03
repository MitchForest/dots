public import Foundation

/// AI-drafted ideas awaiting the writer's review — the human-in-the-loop
/// gate between a captured source and the vault. Canonical storage is
/// `.dots/proposals/<ulid>.json` with `kind: "ideas"` (edit proposals, the
/// 3.x kind, share the directory); see `.docs/target.md`. Nothing enters
/// `ideas/` without an accept. One proposal per source, ever — dismissed
/// means never regenerate.
public struct IdeaProposal: Equatable, Identifiable, Sendable {
    public struct ID: Hashable, RawRepresentable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public enum Status: String, Equatable, Sendable {
        /// Every idea reviewed (accepted or discarded).
        case applied
        /// The writer waved the whole batch away; never regenerate.
        case dismissed
        case open
    }

    public var author: String
    public var createdAt: Date
    public var id: ID
    public var ideas: [ProposedIdea]
    public var sourceId: Source.ID
    public var status: Status

    public var pendingIdeas: [ProposedIdea] {
        ideas.filter { $0.status == .pending }
    }

    public init(
        id: ID,
        sourceId: Source.ID,
        ideas: [ProposedIdea],
        createdAt: Date,
        author: String = "dots-extract",
        status: Status = .open
    ) {
        self.author = author
        self.createdAt = createdAt
        self.id = id
        self.ideas = ideas
        self.sourceId = sourceId
        self.status = status
    }
}

/// One drafted idea inside a proposal. Accept mints a real idea with
/// extraction provenance; discard just records the judgement.
public struct ProposedIdea: Equatable, Identifiable, Sendable {
    public enum Status: String, Equatable, Sendable {
        case accepted
        case discarded
        case pending
    }

    public var id: Int
    public var status: Status
    public var text: String

    public init(id: Int, text: String, status: Status = .pending) {
        self.id = id
        self.status = status
        self.text = text
    }
}
