public import DotsDomain
import Foundation

/// Codec for source markdown files (YAML frontmatter + full extracted text).
/// Mirrors the source schema in .docs/target.md; `render(_:)` → `parse(_:)` round-trips.
public enum SourceFile {
    /// Parses a source file (YAML-ish frontmatter + markdown body). Returns nil
    /// when there is no frontmatter or no id.
    public static func parse(_ contents: String) -> Source? {
        let lines = contents.components(separatedBy: "\n")
        guard lines.first == "---" else { return nil }
        guard let closing = lines.dropFirst().firstIndex(of: "---") else { return nil }

        var id = ""
        var title = ""
        var url: URL?
        var author: String?
        var site: String?
        var capturedAt: Date?

        for line in lines[1..<closing] {
            if let raw = value(of: "id", in: line[...]) {
                id = raw
            } else if let raw = value(of: "title", in: line[...]) {
                title = raw
            } else if let raw = value(of: "url", in: line[...]) {
                url = URL(string: raw)
            } else if let raw = value(of: "author", in: line[...]) {
                author = raw
            } else if let raw = value(of: "site", in: line[...]) {
                site = raw
            } else if let raw = value(of: "captured_at", in: line[...]) {
                capturedAt = date(from: raw)
            }
        }

        guard !id.isEmpty else { return nil }

        let body = lines[(closing + 1)...].joined(separator: "\n")
        return Source(
            id: Source.ID(id),
            title: title.isEmpty ? "Untitled" : title,
            content: body,
            capturedAt: capturedAt ?? Date(timeIntervalSince1970: 0),
            url: url,
            author: author,
            site: site
        )
    }

    /// Renders a source to canonical file contents.
    public static func render(_ source: Source) -> String {
        var front = ["---"]
        front.append("id: \(source.id.rawValue)")
        front.append("title: \(source.title)")
        if let url = source.url {
            front.append("url: \(url.absoluteString)")
        }
        if let author = source.author {
            front.append("author: \(author)")
        }
        if let site = source.site {
            front.append("site: \(site)")
        }
        front.append("captured_at: \(iso8601(source.capturedAt))")
        front.append("---")
        return front.joined(separator: "\n") + "\n" + source.content
    }

    /// The trimmed value of `key: value` when the line carries that key, nil otherwise.
    private static func value(of key: String, in line: Substring) -> String? {
        let prefix = key + ":"
        guard line.hasPrefix(prefix) else { return nil }
        return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
    }

    private static func date(from raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: raw) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw)
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
