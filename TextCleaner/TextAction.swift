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
    // Converts TeX/LaTeX math notation that MathJax/KaTeX pages (Google's
    // AI answers, Wikipedia, arXiv…) leave on the clipboard back to the
    // Unicode glyphs it stands for: `\(\Lambda \)CDM` → `ΛCDM`.
    case latexToUnicode
    // Clipboard HTML normalisation. When the clipboard carries competing
    // flavors (e.g. plain text + HTML from a browser copy), these read the
    // HTML specifically and re-emit it as clean rich text (RTF) or as
    // plain text, so the paste is predictable instead of leaving the
    // target app to pick a flavor.
    case htmlToRichText
    case htmlToPlainText
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

    /// Actions that operate on the clipboard's HTML representation
    /// specifically rather than on the preferred flavor the popup read
    /// for every other action. The popup feeds them the HTML-decoded
    /// source (falling back to the generic source when the clipboard has
    /// no HTML).
    var prefersHTMLSource: Bool {
        switch self {
        case .htmlToRichText, .htmlToPlainText: return true
        default: return false
        }
    }
}

struct TextAction: Identifiable, Hashable {
    let kind: TextActionKind
    let title: String
    /// Canonical SF Symbol name. May be a glyph introduced after our
    /// minimum OS; use `displayIcon` when actually rendering so older
    /// systems get a substitute instead of a blank.
    let icon: String

    var id: TextActionKind { kind }

    /// SF Symbol that actually renders on the host OS. `characters.uppercase`
    /// / `characters.lowercase` are SF Symbols 4 (macOS 13) and show blank
    /// on Monterey, so substitute an older equivalent there. macOS 13+ keeps
    /// the canonical glyph.
    var displayIcon: String {
        if #available(macOS 13, *) { return icon }
        switch icon {
        case "characters.uppercase": return "textformat.abc"
        case "characters.lowercase": return "textformat.abc.dottedunderline"
        default: return icon
        }
    }

    static let all: [TextAction] = [
        TextAction(kind: .unvaried,         title: "Unvaried",         icon: "equal"),
        TextAction(kind: .removeFormatting, title: "Remove formatting", icon: "textformat"),
        TextAction(kind: .uppercase,        title: "UPPERCASE",        icon: "characters.uppercase"),
        TextAction(kind: .lowercase,        title: "lowercase",        icon: "characters.lowercase"),
        TextAction(kind: .camelCase,        title: "camelCase",        icon: "text.append"),
        TextAction(kind: .snakeCase,        title: "snake_case",       icon: "minus.forwardslash.plus"),
        TextAction(kind: .cleanURL,         title: "Clean URL",        icon: "link"),
        TextAction(kind: .latexToUnicode,   title: "LaTeX → Unicode",   icon: "function"),
        TextAction(kind: .htmlToRichText,   title: "HTML → Rich Text",  icon: "doc.richtext"),
        TextAction(kind: .htmlToPlainText,  title: "HTML → Plain Text", icon: "doc.plaintext"),
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
        case .latexToUnicode:
            return NSAttributedString(string: TextTransforms.latexToUnicode(input.string))
        case .htmlToRichText:
            // `input` is already the HTML-decoded attributed string (the
            // popup feeds us the HTML source). Passing it through re-emits
            // it as RTF at paste time — see PasteSimulator.writeAttributed.
            return input
        case .htmlToPlainText:
            return NSAttributedString(string: input.string)

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

    // MARK: - LaTeX → Unicode

    /// Converts the TeX/LaTeX math notation that MathJax- and KaTeX-rendered
    /// pages (Google's AI answers, Wikipedia, arXiv…) put on the clipboard
    /// back into the Unicode glyphs it stands for:
    ///   `\(\Lambda \)CDM`  → `ΛCDM`
    ///   `\alpha \to \infty` → `α → ∞`
    ///   `H_2O`, `x^{10}`    → `H₂O`, `x¹⁰`
    /// Handled: inline/display math delimiters, Greek letters, common
    /// operators / relations / arrows, `\frac{}{}`, super/subscripts (where
    /// Unicode has the glyph), spacing macros and `\text{}`-style wrappers.
    /// Unknown commands are kept verbatim so nothing is silently dropped.
    /// Output is plain text (the formatting isn't the point of this paste);
    /// `$…$` is intentionally left alone so currency amounts survive.
    static func latexToUnicode(_ input: String) -> String {
        let chars = Array(input)
        var out = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            switch c {
            case "\\":
                guard i + 1 < chars.count else { out.append(c); i += 1; continue }
                let next = chars[i + 1]
                if next.isLetter {
                    var j = i + 1
                    var name = ""
                    while j < chars.count && chars[j].isLetter { name.append(chars[j]); j += 1 }
                    let afterName = j
                    var afterSpace = j
                    while afterSpace < chars.count && chars[afterSpace] == " " { afterSpace += 1 }

                    if name == "frac", let frac = readFraction(chars, from: afterSpace) {
                        out += frac.text; i = frac.next; continue
                    }
                    if let rep = latexCommands[name] {
                        out += rep; i = afterSpace
                    } else if latexOperatorNames.contains(name) {
                        out += name; i = afterSpace
                    } else if latexWrapperCommands.contains(name) {
                        i = afterSpace            // drop wrapper; its { } content survives below
                    } else {
                        out += "\\" + name; i = afterName   // unknown: keep, preserve the space
                    }
                } else {
                    out += latexSymbols[String(next)] ?? String(next)
                    i += 2
                }
            case "{", "}":
                i += 1                            // drop grouping braces
            case "^", "_":
                let run = scriptRun(chars, from: i)
                out += run.text; i = run.next
            default:
                out.append(c); i += 1
            }
        }
        return out
    }

    /// `\frac{num}{den}` → `num/den` (each side recursively converted).
    /// `start` should point just past the command name; returns nil when
    /// the two brace groups aren't there, so the caller can fall back.
    private static func readFraction(_ chars: [Character], from start: Int) -> (text: String, next: Int)? {
        guard start < chars.count, chars[start] == "{" else { return nil }
        let (num, after1) = readBraceGroup(chars, from: start)
        var k = after1
        while k < chars.count && chars[k] == " " { k += 1 }
        guard k < chars.count, chars[k] == "{" else { return nil }
        let (den, after2) = readBraceGroup(chars, from: k)
        return ("\(latexToUnicode(num))/\(latexToUnicode(den))", after2)
    }

    /// `start` points at `{`. Returns the balanced content (without the
    /// outer braces) and the index just past the matching `}`. An
    /// unbalanced group consumes to the end, so the scanner can't loop.
    private static func readBraceGroup(_ chars: [Character], from start: Int) -> (String, Int) {
        var depth = 0, content = "", i = start
        while i < chars.count {
            let c = chars[i]
            if c == "{" {
                depth += 1; i += 1
                if depth == 1 { continue }
                content.append(c)
            } else if c == "}" {
                depth -= 1; i += 1
                if depth == 0 { break }
                content.append(c)
            } else {
                content.append(c); i += 1
            }
        }
        return (content, i)
    }

    /// Handles `^`/`_` followed by one token or a `{…}` group. Converts to
    /// Unicode super/subscripts when every character has a form; otherwise
    /// keeps the marker + content so the meaning isn't lost.
    private static func scriptRun(_ chars: [Character], from start: Int) -> (text: String, next: Int) {
        let isSuper = chars[start] == "^"
        var content = ""
        var i = start + 1
        if i < chars.count && chars[i] == "{" {
            let (inner, after) = readBraceGroup(chars, from: i)
            content = inner; i = after
        } else if i < chars.count {
            content = String(chars[i]); i += 1
        }
        let converted = latexToUnicode(content)
        let map = isSuper ? superscripts : subscripts
        let mapped = converted.map { map[$0] }
        if !converted.isEmpty, mapped.allSatisfy({ $0 != nil }) {
            return (mapped.compactMap { $0 }.map(String.init).joined(), i)
        }
        return ((isSuper ? "^" : "_") + converted, i)
    }

    /// Control symbols (`\` + a non-letter). Math delimiters and spacing
    /// collapse; escaped punctuation becomes its literal.
    private static let latexSymbols: [String: String] = [
        "(": "", ")": "", "[": "", "]": "",
        ",": " ", ";": " ", ":": " ", "!": "", " ": " ",
        "\\": "\n", "|": "‖",
        "{": "{", "}": "}", "$": "$", "%": "%", "&": "&", "#": "#", "_": "_",
    ]

    /// Operator names that stay as words with the backslash stripped.
    private static let latexOperatorNames: Set<String> = [
        "sin", "cos", "tan", "cot", "sec", "csc", "sinh", "cosh", "tanh",
        "arcsin", "arccos", "arctan", "log", "ln", "exp", "lim", "limsup",
        "liminf", "max", "min", "sup", "inf", "det", "gcd", "arg", "dim",
        "ker", "deg", "hom", "mod", "bmod",
    ]

    /// Formatting wrappers whose `{ }` content should survive unstyled.
    private static let latexWrapperCommands: Set<String> = [
        "text", "textrm", "textit", "textbf", "textsf", "texttt",
        "mathrm", "mathbf", "mathit", "mathsf", "mathtt", "mathbb",
        "mathcal", "mathfrak", "operatorname", "boldsymbol", "bm",
    ]

    /// Control words (`\` + letters) → Unicode. Built with uniquing so a
    /// stray duplicate key can never trap at launch.
    private static let latexCommands: [String: String] =
        Dictionary(latexCommandPairs, uniquingKeysWith: { first, _ in first })

    private static let latexCommandPairs: [(String, String)] = [
        // Greek lowercase
        ("alpha", "α"), ("beta", "β"), ("gamma", "γ"), ("delta", "δ"),
        ("epsilon", "ε"), ("varepsilon", "ε"), ("zeta", "ζ"), ("eta", "η"),
        ("theta", "θ"), ("vartheta", "ϑ"), ("iota", "ι"), ("kappa", "κ"),
        ("lambda", "λ"), ("mu", "μ"), ("nu", "ν"), ("xi", "ξ"),
        ("omicron", "ο"), ("pi", "π"), ("varpi", "ϖ"), ("rho", "ρ"),
        ("varrho", "ϱ"), ("sigma", "σ"), ("varsigma", "ς"), ("tau", "τ"),
        ("upsilon", "υ"), ("phi", "φ"), ("varphi", "φ"), ("chi", "χ"),
        ("psi", "ψ"), ("omega", "ω"),
        // Greek uppercase
        ("Gamma", "Γ"), ("Delta", "Δ"), ("Theta", "Θ"), ("Lambda", "Λ"),
        ("Xi", "Ξ"), ("Pi", "Π"), ("Sigma", "Σ"), ("Upsilon", "Υ"),
        ("Phi", "Φ"), ("Psi", "Ψ"), ("Omega", "Ω"),
        // Binary / set operators
        ("times", "×"), ("div", "÷"), ("cdot", "⋅"), ("pm", "±"), ("mp", "∓"),
        ("ast", "∗"), ("star", "⋆"), ("circ", "∘"), ("bullet", "•"),
        ("oplus", "⊕"), ("ominus", "⊖"), ("otimes", "⊗"), ("oslash", "⊘"),
        ("odot", "⊙"), ("cup", "∪"), ("cap", "∩"), ("uplus", "⊎"),
        ("sqcup", "⊔"), ("sqcap", "⊓"), ("vee", "∨"), ("wedge", "∧"),
        ("lor", "∨"), ("land", "∧"), ("setminus", "∖"),
        // Relations
        ("leq", "≤"), ("le", "≤"), ("geq", "≥"), ("ge", "≥"), ("neq", "≠"),
        ("ne", "≠"), ("equiv", "≡"), ("approx", "≈"), ("cong", "≅"),
        ("simeq", "≃"), ("sim", "∼"), ("propto", "∝"), ("ll", "≪"),
        ("gg", "≫"), ("doteq", "≐"), ("asymp", "≍"), ("subset", "⊂"),
        ("supset", "⊃"), ("subseteq", "⊆"), ("supseteq", "⊇"),
        ("sqsubseteq", "⊑"), ("sqsupseteq", "⊒"), ("in", "∈"),
        ("notin", "∉"), ("ni", "∋"), ("mid", "∣"), ("parallel", "∥"),
        ("perp", "⊥"), ("models", "⊨"), ("vdash", "⊢"),
        // Arrows
        ("leftarrow", "←"), ("rightarrow", "→"), ("leftrightarrow", "↔"),
        ("Leftarrow", "⇐"), ("Rightarrow", "⇒"), ("Leftrightarrow", "⇔"),
        ("uparrow", "↑"), ("downarrow", "↓"), ("updownarrow", "↕"),
        ("mapsto", "↦"), ("to", "→"), ("gets", "←"), ("implies", "⇒"),
        ("impliedby", "⇐"), ("iff", "⇔"), ("longrightarrow", "⟶"),
        ("longleftarrow", "⟵"), ("hookrightarrow", "↪"), ("hookleftarrow", "↩"),
        // Large operators
        ("sum", "∑"), ("prod", "∏"), ("coprod", "∐"), ("int", "∫"),
        ("iint", "∬"), ("iiint", "∭"), ("oint", "∮"), ("bigcup", "⋃"),
        ("bigcap", "⋂"), ("bigoplus", "⨁"), ("bigotimes", "⨂"),
        ("bigvee", "⋁"), ("bigwedge", "⋀"),
        // Misc symbols
        ("infty", "∞"), ("partial", "∂"), ("nabla", "∇"), ("forall", "∀"),
        ("exists", "∃"), ("nexists", "∄"), ("neg", "¬"), ("lnot", "¬"),
        ("emptyset", "∅"), ("varnothing", "∅"), ("aleph", "ℵ"),
        ("hbar", "ℏ"), ("ell", "ℓ"), ("Re", "ℜ"), ("Im", "ℑ"), ("wp", "℘"),
        ("top", "⊤"), ("bot", "⊥"), ("angle", "∠"), ("triangle", "△"),
        ("prime", "′"), ("dots", "…"), ("ldots", "…"), ("cdots", "⋯"),
        ("vdots", "⋮"), ("ddots", "⋱"), ("sqrt", "√"), ("surd", "√"),
        ("backslash", "\\"), ("langle", "⟨"), ("rangle", "⟩"),
        ("lceil", "⌈"), ("rceil", "⌉"), ("lfloor", "⌊"), ("rfloor", "⌋"),
        // Absolute-value / norm bars (and their \left…\right variants)
        ("vert", "|"), ("lvert", "|"), ("rvert", "|"),
        ("Vert", "‖"), ("lVert", "‖"), ("rVert", "‖"),
        ("flat", "♭"), ("sharp", "♯"), ("natural", "♮"),
        ("dagger", "†"), ("ddagger", "‡"),
        // Delimiter sizing & math-style directives (drop; the glyph stays)
        ("left", ""), ("right", ""), ("big", ""), ("Big", ""),
        ("bigg", ""), ("Bigg", ""), ("bigl", ""), ("bigr", ""),
        ("Bigl", ""), ("Bigr", ""), ("biggl", ""), ("biggr", ""),
        ("Biggl", ""), ("Biggr", ""), ("displaystyle", ""),
        ("textstyle", ""), ("scriptstyle", ""), ("scriptscriptstyle", ""),
        ("limits", ""), ("nolimits", ""),
        // Spacing macros
        ("quad", " "), ("qquad", " "), ("thinspace", " "),
        ("space", " "), ("enspace", " "),
    ]

    private static let superscripts: [Character: Character] =
        Dictionary(superscriptPairs, uniquingKeysWith: { first, _ in first })

    private static let superscriptPairs: [(Character, Character)] = [
        ("0", "⁰"), ("1", "¹"), ("2", "²"), ("3", "³"), ("4", "⁴"),
        ("5", "⁵"), ("6", "⁶"), ("7", "⁷"), ("8", "⁸"), ("9", "⁹"),
        ("+", "⁺"), ("-", "⁻"), ("=", "⁼"), ("(", "⁽"), (")", "⁾"),
        ("a", "ᵃ"), ("b", "ᵇ"), ("c", "ᶜ"), ("d", "ᵈ"), ("e", "ᵉ"),
        ("f", "ᶠ"), ("g", "ᵍ"), ("h", "ʰ"), ("i", "ⁱ"), ("j", "ʲ"),
        ("k", "ᵏ"), ("l", "ˡ"), ("m", "ᵐ"), ("n", "ⁿ"), ("o", "ᵒ"),
        ("p", "ᵖ"), ("r", "ʳ"), ("s", "ˢ"), ("t", "ᵗ"), ("u", "ᵘ"),
        ("v", "ᵛ"), ("w", "ʷ"), ("x", "ˣ"), ("y", "ʸ"), ("z", "ᶻ"),
        ("A", "ᴬ"), ("B", "ᴮ"), ("D", "ᴰ"), ("E", "ᴱ"), ("G", "ᴳ"),
        ("H", "ᴴ"), ("I", "ᴵ"), ("J", "ᴶ"), ("K", "ᴷ"), ("L", "ᴸ"),
        ("M", "ᴹ"), ("N", "ᴺ"), ("O", "ᴼ"), ("P", "ᴾ"), ("R", "ᴿ"),
        ("T", "ᵀ"), ("U", "ᵁ"), ("V", "ⱽ"), ("W", "ᵂ"),
    ]

    private static let subscripts: [Character: Character] =
        Dictionary(subscriptPairs, uniquingKeysWith: { first, _ in first })

    private static let subscriptPairs: [(Character, Character)] = [
        ("0", "₀"), ("1", "₁"), ("2", "₂"), ("3", "₃"), ("4", "₄"),
        ("5", "₅"), ("6", "₆"), ("7", "₇"), ("8", "₈"), ("9", "₉"),
        ("+", "₊"), ("-", "₋"), ("=", "₌"), ("(", "₍"), (")", "₎"),
        ("a", "ₐ"), ("e", "ₑ"), ("h", "ₕ"), ("i", "ᵢ"), ("j", "ⱼ"),
        ("k", "ₖ"), ("l", "ₗ"), ("m", "ₘ"), ("n", "ₙ"), ("o", "ₒ"),
        ("p", "ₚ"), ("r", "ᵣ"), ("s", "ₛ"), ("t", "ₜ"), ("u", "ᵤ"),
        ("v", "ᵥ"), ("x", "ₓ"),
    ]
}
