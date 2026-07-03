public import Foundation

/// An idea — the atomic unit of the writer's thinking. ("Dot" is the brand
/// name for an idea; the two words are synonyms throughout.)
///
/// Canonical storage is a markdown file with YAML frontmatter in the vault
/// (`ideas/[<folder>/]<ulid>.md`); see `.docs/target.md` for the schema.
/// Provenance is binary and automatic: `source` present means the content
/// came from that source (an extraction, someone else's words); absent means
/// the writer authored it.
public struct Dot: Equatable, Identifiable, Sendable {
    public struct ID: Hashable, RawRepresentable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public var capturedAt: Date
    public var content: String
    /// The vault directory this idea lives in — derived from the file path,
    /// never stored in frontmatter. Nil = unfiled (the Inbox).
    public var folder: String?
    public var id: ID
    /// Directed references to what this idea came from: source ids
    /// (inspiration, distillation) and idea ids (synthesis, association).
    public var references: [Reference]
    /// Present = extraction: this content came from there, don't publish it
    /// as yours. Absent = authored by the writer.
    public var source: DotSource?
    public var tags: [String]

    public var isExtraction: Bool {
        source != nil
    }

    public init(
        id: ID,
        content: String,
        capturedAt: Date,
        source: DotSource? = nil,
        references: [Reference] = [],
        tags: [String] = [],
        folder: String? = nil
    ) {
        self.capturedAt = capturedAt
        self.content = content
        self.folder = folder
        self.id = id
        self.references = references
        self.source = source
        self.tags = tags
    }
}

/// A directed edge from a newer thing to what it came from. The raw value is
/// the referenced file's ULID — resolvable to an idea or a source by lookup;
/// the reference itself is deliberately untyped so files stay simple.
public struct Reference: Hashable, RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ id: Dot.ID) {
        self.rawValue = id.rawValue
    }

    public init(_ id: Source.ID) {
        self.rawValue = id.rawValue
    }
}

/// Where an extraction came from, auto-filled by the extract gesture.
public struct DotSource: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case image
        case quote
        case text
        case tweet
        case url
    }

    public var kind: Kind
    /// The saved Source file this content was extracted from.
    public var ref: Source.ID?
    public var url: URL?

    public init(kind: Kind, url: URL? = nil, ref: Source.ID? = nil) {
        self.kind = kind
        self.ref = ref
        self.url = url
    }
}

/// Everything needed to mint an idea except identity and timestamp, which
/// the vault assigns at write time.
public struct DotSeed: Equatable, Sendable {
    public var content: String
    public var folder: String?
    public var references: [Reference]
    public var source: DotSource?
    public var tags: [String]

    public init(
        content: String,
        source: DotSource? = nil,
        references: [Reference] = [],
        tags: [String] = [],
        folder: String? = nil
    ) {
        self.content = content
        self.folder = folder
        self.references = references
        self.source = source
        self.tags = tags
    }
}
