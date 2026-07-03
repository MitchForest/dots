public import Foundation

/// Renders new draft files and derives their file names.
/// Mirrors the draft frontmatter schema in .docs/target.md.
public enum DraftTemplate {
    public static func render(
        id: String,
        title: String,
        createdAt: Date,
        ideas: [String] = [],
        body: String = ""
    ) -> String {
        let stamp = Self.iso8601(createdAt)
        let ideaList = ideas.joined(separator: ", ")
        return """
        ---
        id: \(id)
        title: \(title)
        created_at: \(stamp)
        updated_at: \(stamp)
        ideas: [\(ideaList)]
        ---

        \(body)
        """
    }

    /// Lowercased, hyphen-separated file-name slug. Non-alphanumerics collapse
    /// to single hyphens; empty titles yield an empty slug (caller falls back
    /// to the id).
    public static func slug(fromTitle title: String) -> String {
        title
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "-")
    }

    /// Replaces (or inserts) the frontmatter `title:` line. Documents without
    /// frontmatter are returned unchanged apart from nothing — the caller
    /// renames the file only.
    public static func replacingTitle(in contents: String, with title: String) -> String {
        var lines = contents.components(separatedBy: "\n")
        guard lines.first == "---" else { return contents }
        var index = 1
        while index < lines.count, lines[index] != "---" {
            if lines[index].hasPrefix("title:") {
                lines[index] = "title: \(title)"
                return lines.joined(separator: "\n")
            }
            index += 1
        }
        lines.insert("title: \(title)", at: 1)
        return lines.joined(separator: "\n")
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
