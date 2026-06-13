import Foundation

/// Converts plain ASCII text into the Unicode "font" lookalikes popular
/// on social networks that don't allow real formatting — the styles
/// offered by yaytext.com and similar. Each style operates on plain text
/// only: the calling `TextAction` passes `input.string`, so any rich
/// formatting is implicitly dropped before the mapping runs.
///
/// Most styles map ASCII letters/digits into the Unicode "Mathematical
/// Alphanumeric Symbols" block. That block is contiguous *except* for a
/// handful of glyphs Unicode had already encoded in "Letterlike Symbols"
/// (e.g. ℎ ℬ ℭ ℍ …). Those exceptions are patched per style via a
/// `holes` table so the output doesn't end up with missing-glyph boxes.
enum TextStyler {

    // MARK: - Mathematical-alphabet styles

    static func boldSerif(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D400, lower: 0x1D41A, digit: 0x1D7CE)
    }
    static func italicSerif(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D434, lower: 0x1D44E, digit: nil, holes: italicHoles)
    }
    static func boldItalicSerif(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D468, lower: 0x1D482, digit: 0x1D7CE)
    }
    static func boldSans(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D5D4, lower: 0x1D5EE, digit: 0x1D7EC)
    }
    static func italicSans(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D608, lower: 0x1D622, digit: nil)
    }
    static func boldItalicSans(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D63C, lower: 0x1D656, digit: 0x1D7EC)
    }
    static func doubleStruck(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D538, lower: 0x1D552, digit: 0x1D7D8, holes: doubleStruckHoles)
    }
    static func monospace(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D670, lower: 0x1D68A, digit: 0x1D7F6)
    }
    static func sansSerif(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D5A0, lower: 0x1D5BA, digit: 0x1D7E2)
    }
    static func cursiveScript(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D49C, lower: 0x1D4B6, digit: nil, holes: scriptHoles)
    }
    static func boldCursiveScript(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D4D0, lower: 0x1D4EA, digit: nil)
    }
    static func fraktur(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D504, lower: 0x1D51E, digit: nil, holes: frakturHoles)
    }
    static func boldFraktur(_ s: String) -> String {
        mathAlphabet(s, upper: 0x1D56C, lower: 0x1D586, digit: nil)
    }

    // MARK: - Combining-mark styles

    static func shortStrikethrough(_ s: String) -> String { overlay(s, 0x0335) }
    static func longStrikethrough(_ s: String) -> String { overlay(s, 0x0336) }
    static func underlineDoubleMacron(_ s: String) -> String { overlay(s, 0x035F) }

    // MARK: - One-off styles

    static func upsideDown(_ s: String) -> String {
        String(s.reversed().map { upsideDownMap[$0] ?? $0 })
    }

    static func fullwidth(_ s: String) -> String { widen(s) }

    /// Fullwidth Latin with the classic vaporwave Greek substitutions:
    /// A→Λ, E→Ξ (both cases). Done before widening so the replacements,
    /// being non-ASCII, pass through `widen` untouched.
    static func vaporwave(_ s: String) -> String {
        var pre = String()
        pre.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "A", "a": pre.append("Λ")
            case "E", "e": pre.append("Ξ")
            default: pre.append(ch)
            }
        }
        return widen(pre)
    }

    /// Lowercase → Unicode small-capital letters; uppercase stays full
    /// size, which is the conventional small-caps look. 's' and 'x' have
    /// no small-capital glyph in Unicode so they pass through unchanged.
    /// Uses ꜰ (U+A730) for 'f' — the widely supported "compatible F".
    static func smallCaps(_ s: String) -> String {
        String(s.map { smallCapsMap[$0] ?? $0 })
    }

    // MARK: - Engine

    private static func mathAlphabet(
        _ text: String,
        upper: UInt32?,
        lower: UInt32?,
        digit: UInt32?,
        holes: [Character: String] = [:]
    ) -> String {
        var out = String()
        out.reserveCapacity(text.count * 2)
        for ch in text {
            if let replacement = holes[ch] {
                out += replacement
                continue
            }
            guard let ascii = ch.asciiValue else { out.append(ch); continue }
            switch ascii {
            case 65...90 where upper != nil:
                out.unicodeScalars.append(Unicode.Scalar(upper! + UInt32(ascii - 65))!)
            case 97...122 where lower != nil:
                out.unicodeScalars.append(Unicode.Scalar(lower! + UInt32(ascii - 97))!)
            case 48...57 where digit != nil:
                out.unicodeScalars.append(Unicode.Scalar(digit! + UInt32(ascii - 48))!)
            default:
                out.append(ch)
            }
        }
        return out
    }

    /// Appends a combining mark after each visible character so the mark
    /// renders over/under it. Spaces keep the mark (for a continuous line
    /// through words) but newlines don't, so the effect resets per line.
    private static func overlay(_ text: String, _ combining: UInt32) -> String {
        guard let mark = Unicode.Scalar(combining) else { return text }
        var out = String()
        out.reserveCapacity(text.count * 2)
        for ch in text {
            out.append(ch)
            if !ch.isNewline { out.unicodeScalars.append(mark) }
        }
        return out
    }

    /// Maps ASCII printable characters into the Halfwidth and Fullwidth
    /// Forms block (offset +0xFEE0); the regular space becomes the
    /// ideographic space so spacing looks consistent with the wide glyphs.
    private static func widen(_ text: String) -> String {
        var out = String()
        out.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x20:
                out.unicodeScalars.append(Unicode.Scalar(0x3000)!)
            case 0x21...0x7E:
                out.unicodeScalars.append(Unicode.Scalar(scalar.value + 0xFEE0)!)
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    // MARK: - Hole tables (Letterlike Symbols exceptions)

    private static let italicHoles: [Character: String] = ["h": "ℎ"]

    private static let scriptHoles: [Character: String] = [
        "B": "ℬ", "E": "ℰ", "F": "ℱ", "H": "ℋ", "I": "ℐ",
        "L": "ℒ", "M": "ℳ", "R": "ℛ",
        "e": "ℯ", "g": "ℊ", "o": "ℴ",
    ]

    private static let frakturHoles: [Character: String] = [
        "C": "ℭ", "H": "ℌ", "I": "ℑ", "R": "ℜ", "Z": "ℨ",
    ]

    private static let doubleStruckHoles: [Character: String] = [
        "C": "ℂ", "H": "ℍ", "N": "ℕ", "P": "ℙ", "Q": "ℚ", "R": "ℝ", "Z": "ℤ",
    ]

    // MARK: - Lookup tables

    private static let smallCapsMap: [Character: Character] = [
        "a": "ᴀ", "b": "ʙ", "c": "ᴄ", "d": "ᴅ", "e": "ᴇ", "f": "ꜰ",
        "g": "ɢ", "h": "ʜ", "i": "ɪ", "j": "ᴊ", "k": "ᴋ", "l": "ʟ",
        "m": "ᴍ", "n": "ɴ", "o": "ᴏ", "p": "ᴘ", "q": "ǫ", "r": "ʀ",
        "s": "s", "t": "ᴛ", "u": "ᴜ", "v": "ᴠ", "w": "ᴡ", "x": "x",
        "y": "ʏ", "z": "ᴢ",
    ]

    private static let upsideDownMap: [Character: Character] = [
        "a": "ɐ", "b": "q", "c": "ɔ", "d": "p", "e": "ǝ", "f": "ɟ",
        "g": "ƃ", "h": "ɥ", "i": "ᴉ", "j": "ɾ", "k": "ʞ", "l": "ๅ",
        "m": "ɯ", "n": "u", "o": "o", "p": "d", "q": "b", "r": "ɹ",
        "s": "s", "t": "ʇ", "u": "n", "v": "ʌ", "w": "ʍ", "x": "x",
        "y": "ʎ", "z": "z",
        "A": "∀", "B": "ᗺ", "C": "Ɔ", "D": "ᗡ", "E": "Ǝ", "F": "Ⅎ",
        "G": "⅁", "H": "H", "I": "I", "J": "ſ", "K": "ʞ", "L": "˥",
        "M": "W", "N": "N", "O": "O", "P": "Ԁ", "Q": "Ò", "R": "ᴚ",
        "S": "S", "T": "⊥", "U": "∩", "V": "Λ", "W": "M", "X": "X",
        "Y": "⅄", "Z": "Z",
        "0": "0", "1": "Ɩ", "2": "ᄅ", "3": "Ɛ", "4": "ㄣ", "5": "ϛ",
        "6": "9", "7": "ㄥ", "8": "8", "9": "6",
        ".": "˙", ",": "'", "'": ",", "\"": "„", "?": "¿", "!": "¡",
        "(": ")", ")": "(", "[": "]", "]": "[", "{": "}", "}": "{",
        "<": ">", ">": "<", "&": "⅋", "_": "‾",
    ]
}
