import AppKit
import Foundation

enum TextActionKind: String, CaseIterable, Codable {
    case unvaried
    case removeFormatting
    case uppercase
    case lowercase
    case camelCase
    case snakeCase
    case cleanURL
}

struct TextAction: Identifiable, Hashable {
    let kind: TextActionKind
    let title: String
    let icon: String

    var id: TextActionKind { kind }

    static let all: [TextAction] = [
        TextAction(kind: .unvaried,         title: "Unvaried",         icon: "equal"),
        TextAction(kind: .removeFormatting, title: "Remove formatting", icon: "textformat"),
        TextAction(kind: .uppercase,        title: "UPPERCASE",        icon: "characters.uppercase"),
        TextAction(kind: .lowercase,        title: "lowercase",        icon: "characters.lowercase"),
        TextAction(kind: .camelCase,        title: "camelCase",        icon: "text.append"),
        TextAction(kind: .snakeCase,        title: "snake_case",       icon: "minus.forwardslash.plus"),
        TextAction(kind: .cleanURL,         title: "Clean URL",        icon: "link"),
    ]

    func transform(_ input: NSAttributedString) -> NSAttributedString {
        switch kind {
        case .unvaried:
            return input
        case .removeFormatting:
            return NSAttributedString(string: input.string)
        case .uppercase:
            return mapCase(input) { $0.uppercased() }
        case .lowercase:
            return mapCase(input) { $0.lowercased() }
        case .camelCase:
            return NSAttributedString(string: TextTransforms.camelCase(input.string))
        case .snakeCase:
            return NSAttributedString(string: TextTransforms.snakeCase(input.string))
        case .cleanURL:
            return NSAttributedString(string: URLCleaner.clean(input.string))
        }
    }

    /// Applies a string transform while preserving the original attribute
    /// runs (assumes the transform doesn't change character count, which
    /// `uppercased`/`lowercased` honour for the common cases).
    private func mapCase(
        _ input: NSAttributedString,
        _ transform: (String) -> String
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let range = NSRange(location: 0, length: input.length)
        let nsString = input.string as NSString

        input.enumerateAttributes(in: range, options: []) { attrs, runRange, _ in
            let chunk = nsString.substring(with: runRange)
            result.append(NSAttributedString(string: transform(chunk), attributes: attrs))
        }
        return result
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
