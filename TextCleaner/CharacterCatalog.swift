import Foundation

/// One pick-able glyph plus an optional human description shown in the
/// picker's header bar when the entry is selected or hovered.
struct CharacterEntry: Hashable, Identifiable {
    let id = UUID()
    let character: String
    let description: String?

    init(_ character: String, _ description: String? = nil) {
        self.character = character
        self.description = description
    }
}

struct CharacterSection: Identifiable {
    let id = UUID()
    let title: String
    let entries: [CharacterEntry]
}

/// Built-in catalog of glyphs shown by the Unicode picker. The picker
/// flattens these into one long sequence for keyboard navigation but
/// keeps the section break visible in the layout. Entries marked with a
/// description show that text in the header bar when selected.
enum CharacterCatalog {
    /// Looks up the first catalog entry whose character matches. Used to
    /// hydrate the Recent section: we only persist the character itself
    /// in UserDefaults, then on each picker open we re-attach the
    /// catalog's description so the header still labels it nicely.
    /// If the character isn't in the catalog (e.g. an old recent for a
    /// glyph that was removed), returns a plain entry without a
    /// description rather than dropping it entirely.
    static func entry(for character: String) -> CharacterEntry {
        for section in sections {
            if let match = section.entries.first(where: { $0.character == character }) {
                return CharacterEntry(match.character, match.description)
            }
        }
        return CharacterEntry(character)
    }

    static let sections: [CharacterSection] = [
        CharacterSection(title: "Greek Alphabet", entries: greek),
        CharacterSection(title: "Superscript", entries: superscript),
        CharacterSection(title: "Subscript", entries: subscriptEntries),
        CharacterSection(title: "Marks", entries: marks),
        CharacterSection(title: "Mathematical Symbols", entries: math),
        CharacterSection(title: "Differential Calculus", entries: calculus),
        CharacterSection(title: "Set Theory", entries: setTheory),
        CharacterSection(title: "Logic", entries: logic),
        CharacterSection(title: "Math Letters", entries: mathLetters),
        CharacterSection(title: "Arrows", entries: arrows),
    ]

    private static func flat(_ string: String) -> [CharacterEntry] {
        string
            .filter { !$0.isWhitespace }
            .map { CharacterEntry(String($0)) }
    }

    // MARK: - Greek

    private static let greek: [CharacterEntry] =
        flat("ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ") +
        flat("αβγδεζηθικλμνξοπρστυφχψω")

    // MARK: - Superscript / Subscript

    private static let superscript: [CharacterEntry] =
        flat("⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ⁱⁿªºⱽ") +
        flat("ᴬᴭᴮᴯᴰᴱᴲᴳᴴᴵᴶᴷᴸᴹᴺᴻᴼᴽᴾᴿᵀᵁᵂᵃᵄᵅᵆᵇᵈᵉᵊᵋᵌᵍᵏᵐᵑᵒᵓᵖᵗᵘᵚᵛ") +
        flat("ᵝᵞᵟᵠᵡ") +
        flat("ᶛᶜᶝᶞᶟᶠᶡᶢᶣᶤᶥᶦᶧᶨᶩᶪᶫᶬᶭᶮᶯᶰᶱᶲᶳᶴᶵᶶᶷᶸᶹᶺᶻᶼᶽᶾ") +
        flat("ʰʱʲʳʴʵʶʷˀˠˤʸˣ") +
        flat("ꜝꜞ")

    private static let subscriptEntries: [CharacterEntry] =
        flat("₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎") +
        flat("ₐₑₒₓₔⱼᵢᵣᵤᵥᵦᵧᵨᵩᵪₕₖₗₘₙₚₛₜ")

    // MARK: - Marks

    private static let marks: [CharacterEntry] = [
        CharacterEntry("‖", "double vertical line"),
        CharacterEntry("′", "prime"),
        CharacterEntry("″", "double prime"),
        CharacterEntry("‴", "triple prime"),
        CharacterEntry("♭", "flat"),
        CharacterEntry("♮", "natural"),
    ]

    // MARK: - Math

    private static let math: [CharacterEntry] =
        flat("±∓≠≤≥√∛∜∞") +
        flat("⊕⊗⨁⨂") +
        flat("⟦⟧⟨⟩⟪⟫⟬⟭⟮⟯")

    private static let calculus: [CharacterEntry] = [
        CharacterEntry("∂", "partial derivative"),
        CharacterEntry("∆", "delta / Laplacian"),
        CharacterEntry("∇", "nabla / del"),
        CharacterEntry("∑", "sum"),
        CharacterEntry("⅀", "double-struck sum"),
        CharacterEntry("∏", "product"),
        CharacterEntry("∫", "integral"),
        CharacterEntry("∬", "double integral"),
        CharacterEntry("∭", "triple integral"),
        CharacterEntry("∮", "contour integral"),
        CharacterEntry("∯", "surface integral"),
        CharacterEntry("∰", "volume integral"),
    ]

    private static let setTheory: [CharacterEntry] = [
        CharacterEntry("⌀", "empty set"),
        CharacterEntry("∈", "element of"),
        CharacterEntry("∉", "not element of"),
        CharacterEntry("∋", "contains"),
        CharacterEntry("∌", "does not contain"),
        CharacterEntry("∩", "intersection"),
        CharacterEntry("∪", "union"),
        CharacterEntry("⊂", "subset"),
        CharacterEntry("⊃", "superset"),
        CharacterEntry("⊄", "not a subset"),
        CharacterEntry("⊅", "not a superset"),
        CharacterEntry("⊆", "subset or equal"),
        CharacterEntry("⊇", "superset or equal"),
        CharacterEntry("⊈", "not subset or equal"),
        CharacterEntry("⊉", "not superset or equal"),
        CharacterEntry("⊊", "proper subset"),
        CharacterEntry("⊋", "proper superset"),
        CharacterEntry("⨆", "big disjoint union"),
        CharacterEntry("⨅", "big meet"),
    ]

    private static let logic: [CharacterEntry] = [
        CharacterEntry("¬", "not"),
        CharacterEntry("∧", "and"),
        CharacterEntry("∨", "or"),
        CharacterEntry("∀", "for all"),
        CharacterEntry("∃", "exists"),
        CharacterEntry("∄", "does not exist"),
        CharacterEntry("⊻", "xor"),
        CharacterEntry("⊼", "nand"),
        CharacterEntry("⊽", "nor"),
        CharacterEntry("⊙", "xnor"),
        CharacterEntry("⇒", "implies"),
        CharacterEntry("→", "right arrow / implies"),
        CharacterEntry("⇔", "if and only if"),
        CharacterEntry("↔", "left right arrow / iff"),
        CharacterEntry("↮", "not iff"),
        CharacterEntry("≡", "equivalent"),
        CharacterEntry("≢", "not equivalent"),
        CharacterEntry("≔", "is defined as"),
        CharacterEntry("≝", "equal by definition"),
        CharacterEntry("≜", "equal by definition"),
        CharacterEntry("∴", "therefore"),
        CharacterEntry("∵", "because"),
        CharacterEntry("□", "necessity"),
        CharacterEntry("◇", "possibility"),
    ]

    // MARK: - Math letters

    private static let mathLetters: [CharacterEntry] =
        flat("ℵ") +
        flat("ℬℰℱℋℏℒℓℳ℘ℛℜ№") +
        flat("𝕬𝕭𝕮𝕯𝕰𝕱𝕲𝕳𝕴𝕵𝕶𝕷𝕸𝕹𝕺𝕻𝕼𝕽𝕾𝕿𝖀𝖁𝖂𝖃𝖄𝖅") +
        flat("𝖆𝖇𝖈𝖉𝖊𝖋𝖌𝖍𝖎𝖏𝖐𝖑𝖒𝖓𝖔𝖕𝖖𝖗𝖘𝖙𝖚𝖛𝖜𝖝𝖞𝖟") +
        flat("𝟘𝟙𝟚𝟛𝟜𝟝𝟞𝟟𝟠𝟡") +
        flat("𝔸𝔹ℂ𝔻𝔼𝔽𝔾ℍ𝕀𝕁𝕂𝕃𝕄ℕ𝕆ℙℚℝ𝕊𝕋𝕌𝕍𝕎𝕏𝕐ℤ") +
        flat("𝕒𝕓𝕔𝕕𝕖𝕗𝕘𝕙𝕚𝕛𝕜𝕝𝕞𝕟𝕠𝕡𝕢𝕣𝕤𝕥𝕦𝕧𝕨𝕩𝕪𝕫")

    // MARK: - Arrows

    private static let arrows: [CharacterEntry] =
        flat("↖↑↗←→↙↓↘") +
        flat("⬉⬆⬈⬅➡⬋⬇⬊") +
        flat("⇐⇑⇒⇓⇖⇗⇘⇙") +
        flat("⬁⬀⬂⬃⇦⇨⇧⇩") +
        flat("￩￪￫￬") +
        flat("←↑→↓↔↕↖↗↘↙↚↛↜↝↞↟") +
        flat("↠↡↢↣↤↥↦↧↨↩↪↫↬↭↮↯") +
        flat("↰↱↲↳↴↵↶↷↸↹↺↻↼↽↾↿") +
        flat("⇀⇁⇂⇃⇄⇅⇆⇇⇈⇉⇊⇋⇌⇍⇎⇏") +
        flat("⇐⇑⇒⇓⇔⇕⇖⇗⇘⇙⇚⇛⇜⇝⇞⇟") +
        flat("⇠⇡⇢⇣⇤⇥⇦⇧⇨⇩⇪⇫⇬⇭⇮⇯") +
        flat("⇰⇱⇲⇳⇴⇵⇶⇷⇸⇹⇺⇻⇼⇽⇾⇿") +
        flat("⟰⟱⟲⟳⟴⟵⟶⟷⟸⟹⟺⟻⟼⟽⟾⟿") +
        flat("⤀⤁⤂⤃⤄⤅⤆⤇⤈⤉⤊⤋⤌⤍⤎⤏") +
        flat("⤐⤑⤒⤓⤔⤕⤖⤗⤘⤙⤚⤛⤜⤝⤞⤟") +
        flat("⤠⤡⤢⤣⤤⤥⤦⤧⤨⤩⤪⤫⤬⤭⤮⤯") +
        flat("⤰⤱⤲⤳⤴⤵⤶⤷⤸⤹⤺⤻⤼⤽⤾⤿") +
        flat("⥀⥁⥂⥃⥄⥅⥆⥇⥈⥉⥊⥋⥌⥍⥎⥏") +
        flat("⥐⥑⥒⥓⥔⥕⥖⥗⥘⥙⥚⥛⥜⥝⥞⥟") +
        flat("⥠⥡⥢⥣⥤⥥⥦⥧⥨⥩⥪⥫⥬⥭⥮⥯") +
        flat("⥰⥱⥲⥳⥴⥵⥶⥷⥸⥹⥺⥻⥼⥽⥾⥿") +
        flat("⬀⬁⬂⬃⬄⬅⬆⬇⬈⬉⬊⬋⬌⬍⬎⬏⬐⬑") +
        flat("⮐⮑⮕")
}
