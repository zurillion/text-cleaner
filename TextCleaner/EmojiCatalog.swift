import Foundation

/// Curated emoji catalog driven by the same `CharacterPickerController`
/// as the Unicode picker. The picker's search filter already matches
/// against the Unicode scalar's official name, so for most emojis
/// (`😀` → "GRINNING FACE", `🚗` → "AUTOMOBILE") no custom description
/// is required — the system property does the heavy lifting. The few
/// places where the Unicode name isn't searchable (flags built from
/// regional indicator pairs, ZWJ sequences whose meaning lives in the
/// composition rather than the first scalar) get an explicit
/// description with searchable keywords.
enum EmojiCatalog {

    static let sections: [CharacterSection] = [
        CharacterSection(title: "Smileys",        entries: smileys),
        CharacterSection(title: "Gestures",       entries: gestures),
        CharacterSection(title: "People",         entries: people),
        CharacterSection(title: "Animals",        entries: animals),
        CharacterSection(title: "Nature",         entries: nature),
        CharacterSection(title: "Food & Drink",   entries: foodAndDrink),
        CharacterSection(title: "Activities",     entries: activities),
        CharacterSection(title: "Travel & Places", entries: travel),
        CharacterSection(title: "Objects",        entries: objects),
        CharacterSection(title: "Symbols",        entries: symbols),
        CharacterSection(title: "Flags",          entries: flags),
    ]

    /// Splits a string into one entry per grapheme cluster, dropping
    /// whitespace introduced for readability in the source literals.
    /// Swift's Character respects extended grapheme clusters, so emojis
    /// with variation selectors (❤️ = U+2764 + U+FE0F) and short ZWJ
    /// sequences (👨‍⚕️) are kept whole.
    private static func flat(_ string: String) -> [CharacterEntry] {
        string.filter { !$0.isWhitespace }.map { CharacterEntry(String($0)) }
    }

    // MARK: - Smileys

    private static let smileys: [CharacterEntry] = flat("""
        😀😃😄😁😆😅🤣😂🙂🙃😉😊😇🥰😍🤩😘😗☺️😚😙🥲
        😋😛😜🤪😝🤑🤗🤭🤫🤔🤐🤨😐😑😶😏😒🙄😬🤥
        😌😔😪🤤😴😷🤒🤕🤢🤮🤧🥵🥶🥴😵🤯🤠🥳😎🤓🧐
        😕😟🙁☹️😮😯😲😳🥺😦😧😨😰😥😢😭😱😖😣😞😓😩😫🥱
        😤😡😠🤬😈👿💀☠️💩🤡👹👺👻👽👾🤖
        😺😸😹😻😼😽🙀😿😾
        """)

    // MARK: - Gestures

    private static let gestures: [CharacterEntry] = flat("""
        👋🤚🖐✋🖖👌🤏✌️🤞🤟🤘🤙
        👈👉👆🖕👇☝️👍👎✊👊🤛🤜
        👏🙌👐🤲🤝🙏
        """)

    // MARK: - People

    private static let people: [CharacterEntry] = flat("""
        👶🧒👦👧🧑👨👩🧓👴👵🧔
        👮👷💂🕵🤴👸🤵👰🤶🎅🧙🧚🧛🧜🧝🧞🧟🥷
        💃🕺👫👭👬💑💏👪
        """)

    // MARK: - Animals

    private static let animals: [CharacterEntry] = flat("""
        🐶🐱🐭🐹🐰🦊🐻🐼🐨🐯🦁🐮🐷🐽🐸🐵🙈🙉🙊🐒
        🐔🐧🐦🐤🐣🐥🦆🦅🦉🦇🐺🐗🐴🦄🦓🦌
        🐝🐛🦋🐌🐞🐜🦗🕷🕸🦂
        🐢🐍🦎🦖🦕🐙🦑🦐🦞🦀🐡🐠🐟🐬🐳🐋🦈
        🐊🐅🐆🐃🐂🐄🐪🐫🦙🦘🐘🦏🦛🐐🐏🐑🐎🐖🐀🐁🐓🦃🦚🦜🦢🕊🐇🦝🦨🦡🦔🐾
        """)

    // MARK: - Nature

    private static let nature: [CharacterEntry] = flat("""
        🌱🌲🌳🌴🌵🌾🌿☘️🍀🍁🍂🍃
        🌷🌹🥀🌺🌸🌼🌻
        🌞🌝🌛🌜🌚🌕🌖🌗🌘🌑🌒🌓🌔🌙🌎🌍🌏🪐💫⭐️🌟✨⚡️☄️💥🔥🌪🌈
        ☀️🌤⛅️🌥☁️🌦🌧⛈🌩🌨❄️☃️⛄️🌬💨💧💦☔️
        """)

    // MARK: - Food & Drink

    private static let foodAndDrink: [CharacterEntry] = flat("""
        🍎🍐🍊🍋🍌🍉🍇🍓🍈🍒🍑🥭🍍🥥🥝
        🍅🍆🥑🥦🥬🥒🌶🌽🥕🧄🧅🥔🍠
        🥐🥯🍞🥖🥨🧀🥚🍳🥞🧇🥓🥩🍗🍖🌭🍔🍟🍕🥪🥙🧆🌮🌯🥗🥘🍝🍜🍲🍛🍣🍱🥟🦪🍤🍙🍚🍘🍥🥠🥮🍢🍡
        🍧🍨🍦🥧🍰🎂🍮🍭🍬🍫🍿🍩🍪
        🌰🥜🍯
        🥛🍼☕️🍵🥤🍶🍺🍻🥂🍷🥃🍸🍹🍾
        """)

    // MARK: - Activities

    private static let activities: [CharacterEntry] = flat("""
        ⚽️🏀🏈⚾️🥎🎾🏐🏉🥏🎱🏓🏸🏒🏑🥍🏏🥅⛳️🏹🎣🥊🥋🎽⛸🥌🎿⛷🏂🪂
        🏋️🤼🤸⛹️🤺🤾🏌️🏇🧘🏄🏊🤽🚣🧗🚵🚴
        🏆🥇🥈🥉🏅🎖🎫🎟🎪🤹🎭🎨🎬🎤🎧🎼🎹🥁🎷🎺🎸🎻
        🎲♟🎯🎳🎮🎰🧩
        """)

    // MARK: - Travel & Places

    private static let travel: [CharacterEntry] = flat("""
        🚗🚕🚙🚌🚎🏎🚓🚑🚒🚐🚚🚛🚜🛴🚲🛵🏍🛺
        🚨🚔🚍🚘🚖🚡🚠🚟🚃🚋🚞🚝🚄🚅🚈🚂🚆🚇🚊🚉
        ✈️🛫🛬🛩💺🛰🚀🛸🚁
        ⛵️🚤🛥🛳⛴🚢⚓️⛽️
        🚧🚦🚥🚏
        🗺🗿🗽🗼🏰🏯🏟🎡🎢🎠⛲️⛱🏖🏝🏜🌋⛰🏔🗻🏕⛺️
        🏠🏡🏘🏚🏗🏭🏢🏬🏣🏤🏥🏦🏨🏪🏫🏩💒🏛⛪️🕌🕍🛕🕋⛩
        """)

    // MARK: - Objects

    private static let objects: [CharacterEntry] = flat("""
        ⌚️📱💻⌨️🖥🖨🖱🖲🕹💽💾💿📀📼
        📷📸📹🎥📽📞☎️📟📠📺📻🎙🎚🎛
        ⏱⏲⏰🕰⌛️⏳📡
        🔋🔌💡🔦🕯🧯🛢
        💸💵💴💶💷💰💳💎⚖️
        🧰🔧🔨⚒🛠⛏🔩⚙️🧱⛓🧲🔫💣🧨🪓🔪🗡⚔️🛡🚬
        ⚰️⚱️🏺🔮📿🧿💈⚗️🔭🔬🕳
        🩹🩺💊💉🧬🦠🧫🧪🌡
        🧹🧺🧻🚽🚰🚿🛁🛀🧼🪒🧽🛎
        🔑🗝🚪🛋🛏🛌🧸
        🖼🛍🛒🎁🎈🎏🎀🎊🎉🎎🏮🎐🧧
        ✉️📩📨📧💌📥📤📦🏷📪📫📬📭📮📯
        📜📃📄📑🧾📊📈📉🗒🗓📆📅🗑📇🗃🗳🗄📋📁📂🗂🗞📰📓📔📒📕📗📘📙📚📖
        🔖🧷🔗📎🖇📐📏🧮📌📍✂️
        🖊🖋✒️🖌🖍📝✏️🔍🔎🔏🔐🔒🔓
        """)

    // MARK: - Symbols

    private static let symbols: [CharacterEntry] = flat("""
        ❤️🧡💛💚💙💜🖤🤍🤎💔❣️💕💞💓💗💖💘💝💟
        ☮️✝️☪️🕉☸️✡️🔯🕎☯️☦️🛐
        ⛎♈️♉️♊️♋️♌️♍️♎️♏️♐️♑️♒️♓️
        ⚛️☢️☣️
        ❌⭕️🛑⛔️📛🚫💯💢♨️🚷🚯🚳🚱🔞📵🚭
        ❗️❕❓❔‼️⁉️〽️⚠️🚸🔱⚜️🔰♻️✅
        🆎🆑🆔🆖🆗🆙🆒🆕🆓🆘
        🌐💠Ⓜ️🌀💤🏧🚾♿️🅿️🛗🚹🚺🚼🚻🚮🎦📶
        🔣ℹ️🔤🔡🔠
        ▶️⏸⏯⏹⏺⏭⏮⏩⏪⏫⏬◀️🔼🔽
        ➡️⬅️⬆️⬇️↗️↘️↙️↖️↕️↔️↪️↩️⤴️⤵️🔀🔁🔂🔄🔃
        🎵🎶➕➖➗✖️♾💲™️©️®️
        〰️➰➿🔚🔙🔛🔝🔜
        ✔️☑️🔘🔴🟠🟡🟢🔵🟣⚫️⚪️🟤🔺🔻🔸🔹🔶🔷🔳🔲▪️▫️◾️◽️◼️◻️🟥🟧🟨🟩🟦🟪⬛️⬜️🟫
        🔈🔇🔉🔊🔔🔕📣📢💬💭🗯
        ♠️♣️♥️♦️🃏🎴🀄️
        🕐🕑🕒🕓🕔🕕🕖🕗🕘🕙🕚🕛
        """)

    // MARK: - Flags

    // Regional-indicator flags don't have a useful single Unicode name
    // (each half just says "REGIONAL INDICATOR SYMBOL LETTER X"), so the
    // search-by-name fallback wouldn't find "italy" or "japan". Attach
    // a description per flag with common search keywords.
    private static let flags: [CharacterEntry] = [
        // Generic
        CharacterEntry("🏳️",   "white flag"),
        CharacterEntry("🏴",   "black flag"),
        CharacterEntry("🏁",   "checkered finish race"),
        CharacterEntry("🚩",   "triangular red flag"),
        CharacterEntry("🏳️‍🌈", "rainbow pride lgbt"),
        CharacterEntry("🏳️‍⚧️", "transgender trans"),
        CharacterEntry("🏴‍☠️", "pirate skull crossbones"),

        // Countries (alphabetical by English name)
        CharacterEntry("🇦🇷", "argentina"),
        CharacterEntry("🇦🇺", "australia"),
        CharacterEntry("🇦🇹", "austria"),
        CharacterEntry("🇧🇪", "belgium"),
        CharacterEntry("🇧🇷", "brazil"),
        CharacterEntry("🇨🇦", "canada"),
        CharacterEntry("🇨🇱", "chile"),
        CharacterEntry("🇨🇳", "china"),
        CharacterEntry("🇨🇴", "colombia"),
        CharacterEntry("🇭🇷", "croatia"),
        CharacterEntry("🇨🇿", "czech czechia"),
        CharacterEntry("🇩🇰", "denmark"),
        CharacterEntry("🇪🇬", "egypt"),
        CharacterEntry("🇫🇮", "finland"),
        CharacterEntry("🇫🇷", "france"),
        CharacterEntry("🇩🇪", "germany"),
        CharacterEntry("🇬🇷", "greece"),
        CharacterEntry("🇭🇺", "hungary"),
        CharacterEntry("🇮🇸", "iceland"),
        CharacterEntry("🇮🇳", "india"),
        CharacterEntry("🇮🇩", "indonesia"),
        CharacterEntry("🇮🇪", "ireland"),
        CharacterEntry("🇮🇱", "israel"),
        CharacterEntry("🇮🇹", "italy italia"),
        CharacterEntry("🇯🇵", "japan"),
        CharacterEntry("🇲🇽", "mexico"),
        CharacterEntry("🇳🇱", "netherlands holland"),
        CharacterEntry("🇳🇿", "new zealand"),
        CharacterEntry("🇳🇴", "norway"),
        CharacterEntry("🇵🇪", "peru"),
        CharacterEntry("🇵🇭", "philippines"),
        CharacterEntry("🇵🇱", "poland"),
        CharacterEntry("🇵🇹", "portugal"),
        CharacterEntry("🇷🇴", "romania"),
        CharacterEntry("🇷🇺", "russia"),
        CharacterEntry("🇸🇦", "saudi arabia"),
        CharacterEntry("🇿🇦", "south africa"),
        CharacterEntry("🇰🇷", "south korea"),
        CharacterEntry("🇪🇸", "spain españa"),
        CharacterEntry("🇸🇪", "sweden"),
        CharacterEntry("🇨🇭", "switzerland swiss"),
        CharacterEntry("🇹🇭", "thailand"),
        CharacterEntry("🇹🇷", "turkey türkiye"),
        CharacterEntry("🇺🇦", "ukraine"),
        CharacterEntry("🇦🇪", "uae emirates"),
        CharacterEntry("🇬🇧", "united kingdom uk britain"),
        CharacterEntry("🇺🇸", "united states usa america"),
        CharacterEntry("🇺🇾", "uruguay"),
        CharacterEntry("🇻🇪", "venezuela"),
        CharacterEntry("🇻🇳", "vietnam"),

        // Organisations
        CharacterEntry("🇪🇺", "europe european union eu"),
        CharacterEntry("🇺🇳", "united nations un"),
    ]
}
