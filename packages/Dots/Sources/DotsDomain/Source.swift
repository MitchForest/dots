public import Foundation

/// A saved piece of source material — an article, post, or pasted text kept
/// whole so extraction and distillation always have the full context.
///
/// Canonical storage is `sources/YYYY/MM/<ulid>.md`; see `.docs/target.md`.
public struct Source: Equatable, Identifiable, Sendable {
    public struct ID: Hashable, RawRepresentable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public var author: String?
    public var capturedAt: Date
    /// The full extracted text, as markdown. Imperfect extraction is fine —
    /// the file is editable.
    public var content: String
    /// The vault directory this source lives in — derived from the file
    /// path, never stored in frontmatter. Nil = unfiled (the Inbox).
    public var folder: String?
    public var id: ID
    public var site: String?
    public var title: String
    public var url: URL?

    public init(
        id: ID,
        title: String,
        content: String,
        capturedAt: Date,
        url: URL? = nil,
        author: String? = nil,
        site: String? = nil,
        folder: String? = nil
    ) {
        self.author = author
        self.capturedAt = capturedAt
        self.content = content
        self.folder = folder
        self.id = id
        self.site = site
        self.title = title
        self.url = url
    }
}

/// Everything needed to save a source except identity and timestamp, which
/// the vault assigns at write time.
public struct SourceSeed: Equatable, Sendable {
    public var author: String?
    public var content: String
    public var folder: String?
    public var site: String?
    public var title: String
    public var url: URL?

    public init(
        title: String,
        content: String,
        url: URL? = nil,
        author: String? = nil,
        site: String? = nil,
        folder: String? = nil
    ) {
        self.author = author
        self.content = content
        self.folder = folder
        self.site = site
        self.title = title
        self.url = url
    }
}
