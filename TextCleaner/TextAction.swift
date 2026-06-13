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
    // Unicode "font" styles (yaytext-style). Plain-text only. These are
    // disabled by default (see `defaultEnabled`) so the popup doesn't get
    // flooded — the user opts into the ones they want from Settings.
    case boldSerif
    case italicSerif
    case boldItalicSerif
    case boldSans
    case italicSans
    case boldItalicSans
    case doubleStruck
    case monospace
    case sansSerif
    case cursiveScript
    case boldCursiveScript
    case fraktur
    case boldFraktur
    case shortStrikethrough
    case longStrikethrough
    case underlineDoubleMacron
    case upperSquigglesHooks
    case lowerSquigglesHooks
    case alternatingSquigglesHooks
    case upsideDown
    case reverse
    case largeCherokee
    case smallCherokee
    case fullwidth
    case vaporwave
    case smallCaps
    case forceLineBreak
    case tabbedParagraph
    case doubleTabbed

    /// Whether this action defaults to ON the first time it shows up in
    /// the user's preferences. Currently everything defaults to on —
    /// the popup is scrollable, and the user prunes from Settings what
    /// they don't use.
    var defaultEnabled: Bool { true }
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
        // Unicode styles
        TextAction(kind: .boldSerif,             title: "Bold (serif)",            icon: "bold"),
        TextAction(kind: .italicSerif,           title: "Italic (serif)",          icon: "italic"),
        TextAction(kind: .boldItalicSerif,       title: "Bold italic (serif)",     icon: "italic"),
        TextAction(kind: .boldSans,              title: "Bold (sans)",             icon: "bold"),
        TextAction(kind: .italicSans,            title: "Italic (sans)",           icon: "italic"),
        TextAction(kind: .boldItalicSans,        title: "Bold italic (sans)",      icon: "italic"),
        TextAction(kind: .doubleStruck,          title: "Double-struck",           icon: "textformat"),
        TextAction(kind: .monospace,             title: "Monospace",               icon: "chevron.left.forwardslash.chevron.right"),
        TextAction(kind: .sansSerif,             title: "Sans serif",              icon: "textformat"),
        TextAction(kind: .cursiveScript,         title: "Cursive script",          icon: "signature"),
        TextAction(kind: .boldCursiveScript,     title: "Bold cursive script",     icon: "signature"),
        TextAction(kind: .fraktur,               title: "Fraktur",                 icon: "textformat"),
        TextAction(kind: .boldFraktur,           title: "Bold fraktur",            icon: "textformat"),
        TextAction(kind: .shortStrikethrough,    title: "Short strikethrough",     icon: "strikethrough"),
        TextAction(kind: .longStrikethrough,     title: "Long strikethrough",      icon: "strikethrough"),
        TextAction(kind: .underlineDoubleMacron, title: "Underline (double macron)", icon: "underline"),
        TextAction(kind: .upperSquigglesHooks,   title: "Upper squiggles and hooks",  icon: "scribble"),
        TextAction(kind: .lowerSquigglesHooks,   title: "Lower squiggles and hooks",  icon: "scribble"),
        TextAction(kind: .alternatingSquigglesHooks, title: "Alternating squiggles and hooks", icon: "scribble"),
        TextAction(kind: .upsideDown,            title: "Upside down",             icon: "arrow.uturn.down"),
        TextAction(kind: .reverse,               title: "Reverse",                 icon: "arrow.left.arrow.right"),
        TextAction(kind: .largeCherokee,         title: "Large Cherokee letterlike", icon: "character"),
        TextAction(kind: .smallCherokee,         title: "Small Cherokee letterlike", icon: "character"),
        TextAction(kind: .fullwidth,             title: "Fullwidth",               icon: "arrow.left.and.right"),
        TextAction(kind: .vaporwave,             title: "Vaporwave",               icon: "sparkles"),
        TextAction(kind: .smallCaps,             title: "Small caps",              icon: "textformat.size"),
        TextAction(kind: .forceLineBreak,        title: "Force line break",        icon: "return"),
        TextAction(kind: .tabbedParagraph,       title: "Tabbed paragraph",        icon: "increase.indent"),
        TextAction(kind: .doubleTabbed,          title: "Double tabbed",           icon: "increase.indent"),
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

        // Unicode styles — plain text only, so they operate on the
        // string and discard any incoming formatting.
        case .boldSerif:             return styled(input, TextStyler.boldSerif)
        case .italicSerif:           return styled(input, TextStyler.italicSerif)
        case .boldItalicSerif:       return styled(input, TextStyler.boldItalicSerif)
        case .boldSans:              return styled(input, TextStyler.boldSans)
        case .italicSans:            return styled(input, TextStyler.italicSans)
        case .boldItalicSans:        return styled(input, TextStyler.boldItalicSans)
        case .doubleStruck:          return styled(input, TextStyler.doubleStruck)
        case .monospace:             return styled(input, TextStyler.monospace)
        case .sansSerif:             return styled(input, TextStyler.sansSerif)
        case .cursiveScript:         return styled(input, TextStyler.cursiveScript)
        case .boldCursiveScript:     return styled(input, TextStyler.boldCursiveScript)
        case .fraktur:               return styled(input, TextStyler.fraktur)
        case .boldFraktur:           return styled(input, TextStyler.boldFraktur)
        case .shortStrikethrough:    return styled(input, TextStyler.shortStrikethrough)
        case .longStrikethrough:     return styled(input, TextStyler.longStrikethrough)
        case .underlineDoubleMacron: return styled(input, TextStyler.underlineDoubleMacron)
        case .upperSquigglesHooks:        return styled(input, TextStyler.upperSquigglesHooks)
        case .lowerSquigglesHooks:        return styled(input, TextStyler.lowerSquigglesHooks)
        case .alternatingSquigglesHooks:  return styled(input, TextStyler.alternatingSquigglesHooks)
        case .upsideDown:            return styled(input, TextStyler.upsideDown)
        case .reverse:               return styled(input, TextStyler.reverse)
        case .largeCherokee:         return styled(input, TextStyler.largeCherokeeLetterlike)
        case .smallCherokee:         return styled(input, TextStyler.smallCherokeeLetterlike)
        case .fullwidth:             return styled(input, TextStyler.fullwidth)
        case .vaporwave:             return styled(input, TextStyler.vaporwave)
        case .smallCaps:             return styled(input, TextStyler.smallCaps)
        case .forceLineBreak:        return styled(input, TextStyler.forceLineBreak)
        case .tabbedParagraph:       return styled(input, TextStyler.tabbedParagraph)
        case .doubleTabbed:          return styled(input, TextStyler.doubleTabbed)
        }
    }

    /// Wraps a plain-string styler into the attributed return type. The
    /// styled output deliberately carries no attributes — these styles
    /// only make sense on unformatted text.
    private func styled(
        _ input: NSAttributedString,
        _ transform: (String) -> String
    ) -> NSAttributedString {
        NSAttributedString(string: transform(input.string))
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
