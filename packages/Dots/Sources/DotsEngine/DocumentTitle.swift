/// Derives a display title from a markdown document: frontmatter `title:`
/// first, then the first `# ` heading, else nil (caller falls back to the
/// file name).
public enum DocumentTitle {
    public static func parse(_ contents: String) -> String? {
        var lines = contents.split(separator: "\n", omittingEmptySubsequences: false)[...]

        if lines.first?.trimmed == "---" {
            lines = lines.dropFirst()
            while let line = lines.first, line.trimmed != "---" {
                if let value = line.value(forFrontmatterKey: "title"), !value.isEmpty {
                    return value
                }
                lines = lines.dropFirst()
            }
            lines = lines.dropFirst()
        }

        for line in lines {
            let trimmed = line.trimmed
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmed
            }
            if !trimmed.isEmpty {
                break
            }
        }
        return nil
    }
}

extension StringProtocol {
    fileprivate var trimmed: String {
        String(drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }

    fileprivate func value(forFrontmatterKey key: String) -> String? {
        let trimmed = self.trimmed
        guard trimmed.hasPrefix("\(key):") else { return nil }
        return String(trimmed.dropFirst(key.count + 1)).trimmed
    }
}
