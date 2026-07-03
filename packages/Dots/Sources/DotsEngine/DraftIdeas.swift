public import DotsDomain
import Foundation

/// Reads and rewrites the `ideas:` reference list in a draft's frontmatter —
/// the structured slot sent ideas land in. Never touches the body. The
/// legacy key `dots:` parses; writes always emit `ideas:`.
public enum DraftIdeas {
    /// The idea ids a draft references, from `ideas:` or legacy `dots:`.
    public static func ids(in contents: String) -> [Dot.ID] {
        let lines = contents.components(separatedBy: "\n")
        guard lines.first == "---" else { return [] }
        for line in lines.dropFirst() {
            if line == "---" { break }
            if let raw = value(of: "ideas", in: line) ?? value(of: "dots", in: line) {
                return inlineList(raw).map { Dot.ID($0) }
            }
        }
        return []
    }

    /// Contents with `id` appended to the reference list (no-op when already
    /// present or when there is no frontmatter).
    public static func adding(_ id: Dot.ID, to contents: String) -> String {
        var ids = Self.ids(in: contents)
        guard !ids.contains(id) else { return contents }
        ids.append(id)
        return replacing(ids: ids, in: contents)
    }

    /// Contents with `id` removed from the reference list.
    public static func removing(_ id: Dot.ID, from contents: String) -> String {
        var ids = Self.ids(in: contents)
        guard ids.contains(id) else { return contents }
        ids.removeAll { $0 == id }
        return replacing(ids: ids, in: contents)
    }

    private static func replacing(ids: [Dot.ID], in contents: String) -> String {
        var lines = contents.components(separatedBy: "\n")
        guard lines.first == "---" else { return contents }
        let rendered = "ideas: [\(ids.map(\.rawValue).joined(separator: ", "))]"
        var index = 1
        while index < lines.count, lines[index] != "---" {
            if value(of: "ideas", in: lines[index]) != nil
                || value(of: "dots", in: lines[index]) != nil {
                lines[index] = rendered
                return lines.joined(separator: "\n")
            }
            index += 1
        }
        guard index < lines.count else { return contents }
        lines.insert(rendered, at: index)
        return lines.joined(separator: "\n")
    }

    private static func value(of key: String, in line: String) -> String? {
        let prefix = key + ":"
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    private static func inlineList(_ raw: String) -> [String] {
        var trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("]") {
            trimmed.removeLast()
        }
        return trimmed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
