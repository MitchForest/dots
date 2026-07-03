public import DotsDomain
import Foundation

/// Codec for idea markdown files (YAML frontmatter + markdown body).
/// Mirrors the idea schema in .docs/target.md; `render(_:)` → `parse(_:)`
/// round-trips. Folder is path-derived and never appears in frontmatter.
public enum DotFile {
    /// Parses an idea file. Returns nil when there is no frontmatter or no
    /// id. Legacy keys (`origin:`, `links:`, `parents:`) map into the v2
    /// schema: links and parents merge into references; `origin: distilled`
    /// moves the source ref into references (the words were the writer's).
    public static func parse(_ contents: String) -> Dot? {
        let lines = contents.components(separatedBy: "\n")
        guard lines.first == "---" else { return nil }
        guard let closing = lines.dropFirst().firstIndex(of: "---") else { return nil }

        var fields = ParsedFields()
        for line in lines[1..<closing] {
            fields.consume(line: line)
        }
        guard !fields.id.isEmpty else { return nil }

        let body = lines[(closing + 1)...].joined(separator: "\n")
        return fields.dot(body: body)
    }

    /// Renders an idea to canonical file contents.
    public static func render(_ dot: Dot) -> String {
        var front = ["---"]
        front.append("id: \(dot.id.rawValue)")
        front.append("captured_at: \(iso8601(dot.capturedAt))")
        if let source = dot.source {
            front.append("source:")
            front.append("  kind: \(source.kind.rawValue)")
            if let url = source.url {
                front.append("  url: \(url.absoluteString)")
            }
            if let ref = source.ref {
                front.append("  ref: \(ref.rawValue)")
            }
        }
        front.append("references: [\(dot.references.map(\.rawValue).joined(separator: ", "))]")
        front.append("tags: [\(dot.tags.joined(separator: ", "))]")
        front.append("---")
        return front.joined(separator: "\n") + "\n" + dot.content
    }

    /// Accumulates frontmatter lines, including legacy-schema keys.
    private struct ParsedFields {
        var capturedAt: Date?
        var id = ""
        var inSource = false
        var legacyOrigin: String?
        var references: [Reference] = []
        var sourceKind: DotSource.Kind?
        var sourceRef: Source.ID?
        var sourceURL: URL?
        var tags: [String] = []

        mutating func consume(line: String) {
            if line.hasPrefix("  ") {
                guard inSource else { return }
                let field = line.dropFirst(2)
                if let raw = DotFile.value(of: "kind", in: field) {
                    sourceKind = DotSource.Kind(rawValue: raw)
                } else if let raw = DotFile.value(of: "url", in: field) {
                    sourceURL = URL(string: raw)
                } else if let raw = DotFile.value(of: "ref", in: field) {
                    sourceRef = Source.ID(raw)
                }
                return
            }
            inSource = false
            if line.trimmingCharacters(in: .whitespaces) == "source:" {
                inSource = true
            } else if let raw = DotFile.value(of: "id", in: line[...]) {
                id = raw
            } else if let raw = DotFile.value(of: "captured_at", in: line[...]) {
                capturedAt = DotFile.date(from: raw)
            } else if let raw = DotFile.value(of: "references", in: line[...]) {
                references += DotFile.inlineList(raw).map { Reference($0) }
            } else if let raw = DotFile.value(of: "origin", in: line[...]) {
                legacyOrigin = raw
            } else if let raw = DotFile.value(of: "links", in: line[...]) {
                references += DotFile.inlineList(raw).map { Reference($0) }
            } else if let raw = DotFile.value(of: "parents", in: line[...]) {
                references += DotFile.inlineList(raw).map { Reference($0) }
            } else if let raw = DotFile.value(of: "tags", in: line[...]) {
                tags = DotFile.inlineList(raw)
            }
        }

        func dot(body: String) -> Dot {
            var source: DotSource?
            if let sourceKind {
                source = DotSource(kind: sourceKind, url: sourceURL, ref: sourceRef)
            }
            var references = references
            if legacyOrigin == "distilled" || legacyOrigin == "original" {
                // Legacy authored ideas: the words were the writer's, so any
                // source becomes an inspiration reference, not an origin.
                if let ref = source?.ref, !references.contains(Reference(ref)) {
                    references.append(Reference(ref))
                }
                source = nil
            }
            return Dot(
                id: Dot.ID(id),
                content: body,
                capturedAt: capturedAt ?? Date(timeIntervalSince1970: 0),
                source: source,
                references: references,
                tags: tags
            )
        }
    }

    /// The trimmed value of `key: value` when the line carries that key, nil otherwise.
    private static func value(of key: String, in line: Substring) -> String? {
        let prefix = key + ":"
        guard line.hasPrefix(prefix) else { return nil }
        return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
    }

    /// Parses `[a, b, c]` (or a bare comma list) into trimmed elements.
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
