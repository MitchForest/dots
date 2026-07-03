public import DotsDomain
import Foundation

/// ⌘P full-text ranking over the whole vault, pure: content in, ordered
/// hits out. A live file scan at personal-corpus scale beats an index —
/// instant, and never stale.
public enum VaultSearch {
    /// Results are capped so the palette stays a palette, not a report.
    public static let maxHits = 24

    /// Rank a query against everything. Title matches beat content
    /// matches; a prefix beats a substring; more occurrences break ties.
    /// Order within a score band: drafts, then ideas, then sources.
    public static func rank(
        query: String,
        drafts: [(document: VaultDocument, content: String)],
        dots: [Dot],
        sources: [Source]
    ) -> [VaultSearchHit] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        var scored: [Scored] = []
        for draft in drafts {
            if let match = match(query: needle, title: draft.document.title, content: draft.content) {
                scored.append(Scored(hit: .draft(draft.document, snippet: match.snippet), score: match.score, band: 0))
            }
        }
        for dot in dots {
            let title = String((dot.content.split(separator: "\n", maxSplits: 1).first ?? "").prefix(80))
            if let match = match(query: needle, title: title, content: dot.content) {
                scored.append(Scored(hit: .idea(dot, snippet: match.snippet), score: match.score, band: 1))
            }
        }
        for source in sources {
            if let match = match(query: needle, title: source.title, content: source.content) {
                scored.append(Scored(hit: .source(source, snippet: match.snippet), score: match.score, band: 2))
            }
        }
        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.band < rhs.band
            }
            .prefix(maxHits)
            .map(\.hit)
    }

    private struct Scored {
        var band: Int
        var hit: VaultSearchHit
        var score: Int

        init(hit: VaultSearchHit, score: Int, band: Int) {
            self.band = band
            self.hit = hit
            self.score = score
        }
    }

    struct Match: Equatable {
        var score: Int
        var snippet: String
    }

    /// Nil when neither the title nor the content contains the query
    /// (case- and diacritic-insensitive).
    static func match(query: String, title: String, content: String) -> Match? {
        let titleRange = title.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
        let contentRange = content.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
        guard titleRange != nil || contentRange != nil else { return nil }

        var score = 0
        if let titleRange {
            score += titleRange.lowerBound == title.startIndex ? 400 : 300
        }
        if let contentRange {
            score += 100 + min(occurrences(of: query, in: content), 20)
            return Match(score: score, snippet: snippet(around: contentRange, in: content))
        }
        // Title-only match: the first content line stands in as context.
        let firstLine = content.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        return Match(score: score, snippet: String(firstLine.prefix(120)))
    }

    private static func occurrences(of query: String, in text: String) -> Int {
        var count = 0
        var searchStart = text.startIndex
        while let range = text.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchStart..<text.endIndex
        ) {
            count += 1
            if count >= 20 { break }
            searchStart = range.upperBound
        }
        return count
    }

    /// The matched line, trimmed around the hit so the query is visible
    /// even when the line is long.
    private static func snippet(around range: Range<String.Index>, in content: String) -> String {
        let lineRange = content.lineRange(for: range)
        let line = content[lineRange].trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.count > 120 else { return line }

        let trimmed = content[lineRange]
        let hitOffset = trimmed.distance(from: trimmed.startIndex, to: range.lowerBound)
        let start = max(0, hitOffset - 40)
        let window = String(trimmed.dropFirst(start).prefix(120))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (start > 0 ? "…" : "") + window + "…"
    }
}
