import Foundation

/// Lossless split of a document into its raw frontmatter block (fences and
/// trailing blank lines included) and the markdown body. `join` is the exact
/// inverse — agents and git diffs depend on byte fidelity.
public enum FrontmatterBlock {
    public static func split(_ contents: String) -> (frontmatter: String, body: String) {
        let lines = contents.components(separatedBy: "\n")
        guard lines.first == "---" else { return ("", contents) }

        var closingIndex: Int?
        for index in 1..<lines.count where lines[index] == "---" {
            closingIndex = index
            break
        }
        guard var end = closingIndex else { return ("", contents) }

        // Blank lines directly after the closing fence belong to the block,
        // so the body starts at real content and the join stays lossless.
        while end + 1 < lines.count, lines[end + 1].isEmpty {
            end += 1
        }

        let frontmatter = lines[0...end].joined(separator: "\n") + "\n"
        let body = lines[(end + 1)...].joined(separator: "\n")
        return (frontmatter, body)
    }

    public static func join(frontmatter: String, body: String) -> String {
        frontmatter + body
    }
}
