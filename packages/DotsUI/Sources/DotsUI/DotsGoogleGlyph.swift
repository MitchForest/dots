import SwiftUI

/// The Google "G" rendered from its canonical four-color logo vector.
struct DotsGoogleGlyph: View {
    private static let viewBox: CGFloat = 18

    private struct Segment {
        let color: Color
        let data: String
    }

    private static let segments: [Segment] = [
        Segment(
            color: Color(red: 0.259, green: 0.522, blue: 0.957),
            data: "M17.64 9.2045c0-.6381-.0573-1.2518-.1636-1.8409H9v3.4814h4.8436c-.2086 1.125-.8427 2.0782-1.7959 2.7164v2.2581h2.9087c1.7018-1.5668 2.6836-3.874 2.6836-6.615z"
        ),
        Segment(
            color: Color(red: 0.204, green: 0.659, blue: 0.325),
            data: "M9 18c2.43 0 4.4673-.806 5.9564-2.1818l-2.9087-2.2581c-.8059.54-1.8368.859-3.0477.859-2.344 0-4.3282-1.5831-5.036-3.7104H.9573v2.3318C2.4382 15.9832 5.4818 18 9 18z"
        ),
        Segment(
            color: Color(red: 0.984, green: 0.737, blue: 0.020),
            data: "M3.964 10.71c-.18-.54-.2823-1.1168-.2823-1.71s.1023-1.17.2823-1.71V4.9582H.9573C.3477 6.1732 0 7.5477 0 9s.3477 2.8268.9573 4.0418L3.964 10.71z"
        ),
        Segment(
            color: Color(red: 0.918, green: 0.263, blue: 0.208),
            data: "M9 3.5795c1.3214 0 2.5077.4541 3.4405 1.346l2.5813-2.5814C13.4636.8918 11.426 0 9 0 5.4818 0 2.4382 2.0168.9573 4.9582L3.964 7.29C4.6718 5.1627 6.656 3.5795 9 3.5795z"
        )
    ]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / Self.viewBox
            let offsetX = (size.width - Self.viewBox * scale) / 2
            let offsetY = (size.height - Self.viewBox * scale) / 2
            let transform = CGAffineTransform(translationX: offsetX, y: offsetY)
                .scaledBy(x: scale, y: scale)
            for segment in Self.segments {
                let path = Path(svgPathData: segment.data).applying(transform)
                context.fill(path, with: .color(segment.color))
            }
        }
        .accessibilityHidden(true)
    }
}

private extension Path {
    init(svgPathData: String) {
        self.init()
        var scanner = SVGPathScanner(svgPathData)
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint?

        func resolve(_ point: CGPoint, relative: Bool) -> CGPoint {
            relative ? CGPoint(x: current.x + point.x, y: current.y + point.y) : point
        }

        while let command = scanner.nextCommand() {
            let relative = command.isLowercase
            switch Character(command.lowercased()) {
            case "m":
                let moved = resolve(scanner.point(), relative: relative)
                move(to: moved)
                current = moved
                start = moved
                lastControl = nil
                while scanner.hasNumber() {
                    let next = resolve(scanner.point(), relative: relative)
                    addLine(to: next)
                    current = next
                }
            case "l":
                lastControl = nil
                while scanner.hasNumber() {
                    let next = resolve(scanner.point(), relative: relative)
                    addLine(to: next)
                    current = next
                }
            case "h":
                lastControl = nil
                while scanner.hasNumber() {
                    let value = scanner.number()
                    let next = CGPoint(x: relative ? current.x + value : value, y: current.y)
                    addLine(to: next)
                    current = next
                }
            case "v":
                lastControl = nil
                while scanner.hasNumber() {
                    let value = scanner.number()
                    let next = CGPoint(x: current.x, y: relative ? current.y + value : value)
                    addLine(to: next)
                    current = next
                }
            case "c":
                while scanner.hasNumber() {
                    let control1 = resolve(scanner.point(), relative: relative)
                    let control2 = resolve(scanner.point(), relative: relative)
                    let end = resolve(scanner.point(), relative: relative)
                    addCurve(to: end, control1: control1, control2: control2)
                    lastControl = control2
                    current = end
                }
            case "s":
                while scanner.hasNumber() {
                    let control2 = resolve(scanner.point(), relative: relative)
                    let end = resolve(scanner.point(), relative: relative)
                    let control1 = lastControl.map {
                        CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y)
                    } ?? current
                    addCurve(to: end, control1: control1, control2: control2)
                    lastControl = control2
                    current = end
                }
            case "z":
                closeSubpath()
                current = start
                lastControl = nil
            default:
                break
            }
        }
    }
}

private struct SVGPathScanner {
    private let characters: [Character]
    private var index = 0

    init(_ string: String) {
        characters = Array(string)
    }

    private mutating func skipSeparators() {
        while index < characters.count,
              characters[index] == " " || characters[index] == ","
              || characters[index] == "\n" || characters[index] == "\t"
              || characters[index] == "\r" {
            index += 1
        }
    }

    mutating func nextCommand() -> Character? {
        skipSeparators()
        guard index < characters.count, characters[index].isLetter else { return nil }
        let command = characters[index]
        index += 1
        return command
    }

    mutating func hasNumber() -> Bool {
        skipSeparators()
        guard index < characters.count else { return false }
        let character = characters[index]
        return character.isNumber || character == "-" || character == "+" || character == "."
    }

    mutating func number() -> CGFloat {
        skipSeparators()
        var text = ""
        if index < characters.count, characters[index] == "-" || characters[index] == "+" {
            text.append(characters[index])
            index += 1
        }
        var seenDot = false
        while index < characters.count {
            let character = characters[index]
            if character.isNumber {
                text.append(character)
                index += 1
            } else if character == "." && !seenDot {
                seenDot = true
                text.append(character)
                index += 1
            } else {
                break
            }
        }
        return CGFloat(Double(text) ?? 0)
    }

    mutating func point() -> CGPoint {
        CGPoint(x: number(), y: number())
    }
}
