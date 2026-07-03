import Foundation

/// List-row representation of an idea: title = first line (Apple Notes
/// convention), snippet = what follows. Markdown lead-in characters are
/// stripped so `# Heading` and `> quote` read as plain text.
public enum DotPreview {
    public static func title(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let cleaned = strippingLead(line)
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        return "New idea"
    }

    public static func snippet(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var sawTitle = false
        for line in lines {
            let cleaned = strippingLead(line)
            guard !cleaned.isEmpty else { continue }
            if sawTitle {
                return cleaned
            }
            sawTitle = true
        }
        return ""
    }

    private static func strippingLead(_ line: String) -> String {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        while let first = trimmed.first, "#>-*".contains(first) {
            trimmed.removeFirst()
            trimmed = trimmed.trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }
}
