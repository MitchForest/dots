import Foundation

/// One ⌘P full-text result: what matched and a snippet of why. Drafts open
/// in the editor; ideas and sources reveal in the workspace's ideas pane.
public enum VaultSearchHit: Equatable, Identifiable, Sendable {
    case draft(VaultDocument, snippet: String)
    case idea(Dot, snippet: String)
    case source(Source, snippet: String)

    public var id: String {
        switch self {
        case .draft(let document, _): document.url.absoluteString
        case .idea(let dot, _): dot.id.rawValue
        case .source(let source, _): source.id.rawValue
        }
    }

    public var snippet: String {
        switch self {
        case .draft(_, let snippet), .idea(_, let snippet), .source(_, let snippet): snippet
        }
    }

    public var title: String {
        switch self {
        case .draft(let document, _): document.title
        case .idea(let dot, _):
            String((dot.content.split(separator: "\n", maxSplits: 1).first ?? "").prefix(80))
        case .source(let source, _): source.title
        }
    }
}
