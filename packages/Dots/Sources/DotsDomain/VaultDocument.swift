public import Foundation

/// A document in the vault as listed on Home (recents) — not the parsed
/// content, just enough to render a card and open the file.
public struct VaultDocument: Equatable, Identifiable, Sendable {
    public var modifiedAt: Date
    public var title: String
    public var url: URL

    public var id: URL { url }

    public init(url: URL, title: String, modifiedAt: Date) {
        self.modifiedAt = modifiedAt
        self.title = title
        self.url = url
    }
}

/// Canonical vault directory layout (see .docs/target.md).
public enum VaultLayout {
    public static let directories = ["ideas", "sources", "drafts", "posts", ".dots"]
    public static let draftsDirectory = "drafts"
    public static let ideasDirectory = "ideas"
    /// Pre-v2 layout roots, migrated (flattened) on vault open.
    public static let legacyDotsDirectory = "dots"
    public static let metadataDirectory = ".dots"
    public static let sourcesDirectory = "sources"
}
