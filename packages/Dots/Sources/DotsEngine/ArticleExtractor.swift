import Foundation

/// Readable text and metadata pulled out of a raw HTML page.
public struct ArticleExtraction: Equatable, Sendable {
    public var author: String?
    public var site: String?
    public var text: String
    public var title: String?

    public init(
        author: String? = nil,
        site: String? = nil,
        text: String,
        title: String? = nil
    ) {
        self.author = author
        self.site = site
        self.text = text
        self.title = title
    }
}

/// Pure string-processing heuristic that turns raw HTML into readable,
/// markdown-ish article text plus metadata. No network, no WebKit —
/// imperfect extraction is fine; source files stay editable.
public enum ArticleExtractor {
    /// Extracts readable article text and metadata from raw HTML.
    public static func extract(html: String) -> ArticleExtraction {
        let title = metaContent(in: html, keys: ["og:title"]) ?? titleTag(in: html)
        let author = metaContent(in: html, keys: ["author", "article:author"])
        let site = metaContent(in: html, keys: ["og:site_name"])

        var text = articleScope(of: html)
        text = strippingJunkBlocks(text)
        text = convertingStructure(text)
        text = strippingTags(text)
        text = decodingEntities(text)
        text = normalizingWhitespace(text)
        return ArticleExtraction(author: author, site: site, text: text, title: title)
    }

    // MARK: Metadata

    /// The decoded `content` of the first meta tag whose `property`/`name`
    /// matches one of `keys`, tolerating either attribute order.
    private static func metaContent(in html: String, keys: [String]) -> String? {
        guard let meta = try? Regex("(?is)<meta\\b[^>]*>") else { return nil }
        for match in html.matches(of: meta) {
            let tag = String(html[match.range])
            let key = (attribute("property", in: tag) ?? attribute("name", in: tag))?.lowercased()
            guard let key, keys.contains(key) else { continue }
            guard let content = attribute("content", in: tag) else { continue }
            let decoded = decodingEntities(content).trimmingCharacters(in: .whitespaces)
            if !decoded.isEmpty {
                return decoded
            }
        }
        return nil
    }

    private static func titleTag(in html: String) -> String? {
        guard
            let regex = try? Regex("(?is)<title\\b[^>]*>(.*?)</title\\s*>"),
            let match = html.firstMatch(of: regex),
            let inner = match.output[1].substring
        else { return nil }
        let decoded = decodingEntities(String(inner))
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespaces)
        return decoded.isEmpty ? nil : decoded
    }

    /// The value of `name="…"` or `name='…'` inside a single tag, nil when absent.
    private static func attribute(_ name: String, in tag: String) -> String? {
        guard
            let regex = try? Regex("(?i)\\b\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')"),
            let match = tag.firstMatch(of: regex)
        else { return nil }
        let value = match.output[1].substring ?? match.output[2].substring
        return value.map(String.init)
    }

    // MARK: Scope

    /// The innerHTML of the first `<article>`, else `<main>`, else `<body>`,
    /// else the whole document.
    private static func articleScope(of html: String) -> String {
        for tag in ["article", "main", "body"] {
            if let inner = innerHTML(of: tag, in: html) {
                return inner
            }
        }
        return html
    }

    private static func innerHTML(of tag: String, in html: String) -> String? {
        guard
            let open = html.range(of: "<" + tag, options: .caseInsensitive),
            let next = html[open.upperBound...].first, next == ">" || next.isWhitespace,
            let openEnd = html.range(of: ">", range: open.upperBound..<html.endIndex),
            let close = html.range(of: "</" + tag, options: .caseInsensitive, range: openEnd.upperBound..<html.endIndex)
        else { return nil }
        return String(html[openEnd.upperBound..<close.lowerBound])
    }

    // MARK: Cleanup

    private static let junkTags = [
        "script", "style", "noscript", "svg", "nav", "header", "footer", "aside", "form", "figure"
    ]

    /// Removes comments and whole blocks that never carry article text.
    private static func strippingJunkBlocks(_ html: String) -> String {
        var result = replacing(pattern: "(?s)<!--.*?-->", in: html, with: "")
        for tag in junkTags {
            result = replacing(pattern: "(?is)<\(tag)\\b[^>]*>.*?</\(tag)\\s*>", in: result, with: "")
        }
        return result
    }

    /// Converts headings, list items, blockquotes, and paragraph-level tags
    /// into markdown-ish plain-text structure.
    private static func convertingStructure(_ html: String) -> String {
        var result = replacingGroup(pattern: "(?is)<blockquote\\b[^>]*>(.*?)</blockquote\\s*>", in: html) { inner in
            "\n\n" + quotedLines(inner) + "\n\n"
        }
        for level in 1...6 {
            result = replacingGroup(pattern: "(?is)<h\(level)\\b[^>]*>(.*?)</h\(level)\\s*>", in: result) { inner in
                let heading = strippingTags(inner)
                    .replacing(/\s+/, with: " ")
                    .trimmingCharacters(in: .whitespaces)
                return "\n\n" + String(repeating: "#", count: level) + " " + heading + "\n\n"
            }
        }
        result = replacing(pattern: "(?i)<li\\b[^>]*>", in: result, with: "\n- ")
        result = replacing(pattern: "(?i)</li\\s*>", in: result, with: "\n")
        result = replacing(pattern: "(?i)<br\\b[^>]*/?>", in: result, with: "\n")
        result = replacing(pattern: "(?i)</?(?:p|div|tr)\\b[^>]*>", in: result, with: "\n\n")
        return result
    }

    /// Flattens blockquote innerHTML into `> `-prefixed lines.
    private static func quotedLines(_ inner: String) -> String {
        var text = replacing(pattern: "(?i)<br\\b[^>]*/?>", in: inner, with: "\n")
        text = replacing(pattern: "(?i)</?(?:p|div)\\b[^>]*>", in: text, with: "\n")
        text = strippingTags(text)
        return text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { "> " + $0 }
            .joined(separator: "\n")
    }

    /// Removes every remaining tag (and the doctype); a bare `<` in prose survives.
    private static func strippingTags(_ html: String) -> String {
        replacing(pattern: "(?s)<[/!]?[a-zA-Z][^>]*>", in: html, with: "")
    }

    // MARK: Entities

    /// Named entities, ordered so `&amp;` decodes last and never re-decodes
    /// the output of an earlier replacement.
    private static let namedEntities: [(String, String)] = [
        ("&lt;", "<"),
        ("&gt;", ">"),
        ("&quot;", "\""),
        ("&#39;", "'"),
        ("&apos;", "'"),
        ("&nbsp;", " "),
        ("&mdash;", "\u{2014}"),
        ("&ndash;", "\u{2013}"),
        ("&rsquo;", "\u{2019}"),
        ("&lsquo;", "\u{2018}"),
        ("&rdquo;", "\u{201D}"),
        ("&ldquo;", "\u{201C}"),
        ("&hellip;", "\u{2026}"),
        ("&amp;", "&")
    ]

    private static func decodingEntities(_ text: String) -> String {
        var result = replacingGroup(pattern: "&#([0-9]{1,7});", in: text) { digits in
            guard let value = UInt32(digits), let scalar = Unicode.Scalar(value) else { return "" }
            return String(Character(scalar))
        }
        result = replacingGroup(pattern: "(?i)&#x([0-9a-f]{1,6});", in: result) { digits in
            guard let value = UInt32(digits, radix: 16), let scalar = Unicode.Scalar(value) else { return "" }
            return String(Character(scalar))
        }
        for (entity, character) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result
    }

    // MARK: Whitespace

    private static func normalizingWhitespace(_ text: String) -> String {
        var result = text.replacing(/[ \t\u{00A0}]+/, with: " ")
        result = result
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        result = result.replacing(/\n{3,}/, with: "\n\n")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Regex plumbing

    private static func replacing(pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? Regex(pattern) else { return text }
        return text.replacing(regex, with: replacement)
    }

    private static func replacingGroup(
        pattern: String,
        in text: String,
        transform: (String) -> String
    ) -> String {
        guard let regex = try? Regex(pattern) else { return text }
        return text.replacing(regex) { match in
            transform(match.output[1].substring.map(String.init) ?? "")
        }
    }
}
