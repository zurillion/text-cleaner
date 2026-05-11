import Foundation

enum TextActionKind: String, CaseIterable, Codable {
    case removeFormatting
    case uppercase
    case lowercase
    case camelCase
    case snakeCase
}

struct TextAction: Identifiable, Hashable {
    let kind: TextActionKind
    let title: String
    let icon: String

    var id: TextActionKind { kind }

    static let all: [TextAction] = [
        TextAction(kind: .removeFormatting, title: "Remove formatting", icon: "textformat"),
        TextAction(kind: .uppercase,        title: "UPPERCASE",        icon: "characters.uppercase"),
        TextAction(kind: .lowercase,        title: "lowercase",        icon: "characters.lowercase"),
        TextAction(kind: .camelCase,        title: "camelCase",        icon: "text.append"),
        TextAction(kind: .snakeCase,        title: "snake_case",       icon: "minus.forwardslash.plus"),
    ]

    func transform(_ input: String) -> String {
        switch kind {
        case .removeFormatting: return input
        case .uppercase:        return input.uppercased()
        case .lowercase:        return input.lowercased()
        case .camelCase:        return TextTransforms.camelCase(input)
        case .snakeCase:        return TextTransforms.snakeCase(input)
        }
    }
}

enum TextTransforms {
    /// Tokenizes a string into "words" by splitting on non alphanumerics and
    /// on lowercase→uppercase transitions, so it handles "hello world",
    /// "hello-world", "helloWorld" and "HELLO_WORLD" uniformly.
    static func tokens(_ input: String) -> [String] {
        var rawWords: [String] = []
        var current = ""
        for ch in input {
            if ch.isLetter || ch.isNumber {
                current.append(ch)
            } else if !current.isEmpty {
                rawWords.append(current)
                current = ""
            }
        }
        if !current.isEmpty { rawWords.append(current) }
        return rawWords.flatMap(splitOnCaseChange)
    }

    private static func splitOnCaseChange(_ word: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var previous: Character? = nil
        for ch in word {
            if let prev = previous,
               prev.isLowercase, ch.isUppercase,
               !current.isEmpty {
                parts.append(current)
                current = ""
            }
            current.append(ch)
            previous = ch
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    static func camelCase(_ input: String) -> String {
        let parts = tokens(input).map { $0.lowercased() }
        guard let first = parts.first else { return "" }
        let rest = parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return ([first] + rest).joined()
    }

    static func snakeCase(_ input: String) -> String {
        tokens(input).map { $0.lowercased() }.joined(separator: "_")
    }
}
