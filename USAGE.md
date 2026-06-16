# TextMagician — User Guide

TextMagician is a macOS menu-bar utility with three independent tools, each
on its own global hotkey:

| Tool                  | Default hotkey | What it does                                                                                       |
| --------------------- | -------------- | -------------------------------------------------------------------------------------------------- |
| Clipboard transformer | `⌃⌥⌘V`         | Apply a transformation (case change, URL clean-up, Unicode "font" style, …) to whatever you copied |
| Unicode picker        | `⌃⌥⌘U`         | Browse and insert from a curated catalogue of Unicode glyphs                                       |
| Emoji picker          | `⌃⌥⌘E`         | Same UI as the Unicode picker, scoped to emojis                                                    |

All three end the same way: the chosen result is pasted at the current caret
position in whichever app was frontmost when you fired the hotkey, then the
original clipboard contents are restored.

---

## First-time setup

After installing the app from the DMG and launching it, two things have to
happen once:

1. **Grant the Accessibility permission.** Posting the `⌘V` keystroke to
   other apps requires it. The first time you trigger an action, macOS
   prompts you to open System Settings → Privacy & Security → Accessibility
   and flip the switch for TextMagician.
2. **Quit and relaunch the app** after granting. An already-running process
   doesn't pick up the permission until next start. Use the menu-bar icon →
   Quit, then re-launch.

If pasting doesn't work, the Accessibility permission is the first place to
check (one stale entry in the list is enough to silently break things).

---

## The clipboard transformer

This is the original tool. Copy some text (anywhere — Safari, an editor,
Notes), then press `⌃⌥⌘V`. A floating popup appears in front of whatever
you were doing.

### Navigation

| Key                            | Action                                                  |
| ------------------------------ | ------------------------------------------------------- |
| `↑` / `↓`                      | Move the highlight one row                              |
| `⇧↑` / `⇧↓`                    | Jump to the first / last row                            |
| `1`–`9`, then `a`–`z`          | Pick a row directly by its badge                        |
| `↩` (Return)                   | Confirm the highlighted action                          |
| `␣` (Space)                    | Toggle the preview pane                                 |
| `⇥` (Tab)                      | Enter edit mode (see below)                             |
| `⎋` (Escape)                   | Cancel and close                                        |

Mouse hover highlights a row without scrolling the list; clicking commits
the action immediately. The list itself scrolls with the trackpad / scroll
wheel when there are more rows than fit.

### Preview pane

Press `␣` (Space) to toggle a side pane that shows what the highlighted
action would produce, given your current clipboard. Useful when you're not
sure which transformation you want.

### Edit mode

Press `⇥` (Tab) to open the preview as an editable buffer. You can:

- Type, delete, rearrange.
- Apply bold / italic / underline with `⌘B` / `⌘I` / `⌘U`.
- Open the system Fonts panel with `⌘T` for font / size / colour changes.
- `⇧↩` confirms (pastes the edited result), `⎋` cancels.

The paste is smart: if your edits actually contain styling (bold, italic,
non-default font, size or colour), the clipboard receives both RTF and
plain text, so target apps that support rich text get the formatting.
Otherwise plain text only.

### Dragging and re-centering

Drag the popup by its title bar to reposition it anywhere on screen. The
preview pane (if open) follows. Press the re-center shortcut (default
`⌥C`, configurable) while the popup is open to snap it back to centre.

### Built-in actions

The popup ships with 36 actions, all enabled by default and grouped with
horizontal separators between logical blocks. Disable, reorder, or
re-separate from Preferences.

**Original text-processing actions**

| Name              | Result                                                                                |
| ----------------- | ------------------------------------------------------------------------------------- |
| Unvaried          | Pastes the clipboard contents back unchanged                                          |
| Remove formatting | Strips all styling, keeps the plain text                                              |
| UPPERCASE         | Uppercase                                                                             |
| lowercase         | Lowercase                                                                             |
| camelCase         | `helloWorld` from any tokenisation (spaces, dashes, underscores, case-change)         |
| snake_case        | `hello_world` from any tokenisation                                                   |
| Clean URL         | Strips tracking parameters (`utm_*`, `fbclid`, `gclid`, Amazon `pf_rd_*`/`ref`, etc.) and rebuilds Facebook group "multi-permalinks" links into the direct `/groups/<id>/posts/<id>/` form |

**Unicode "font" styles** (work on plain text; rich formatting is dropped
before the mapping runs)

`Bold (serif)`, `Italic (serif)`, `Bold italic (serif)`, `Bold (sans)`,
`Italic (sans)`, `Bold italic (sans)`, `Double-struck`, `Monospace`,
`Sans serif`, `Cursive script`, `Bold cursive script`, `Fraktur`,
`Bold fraktur`, `Short strikethrough`, `Long strikethrough`, `Underline
(double macron)`, `Upper squiggles and hooks`, `Lower squiggles and
hooks`, `Alternating squiggles and hooks`, `Upside down`, `Reverse`,
`Large Cherokee letterlike`, `Small Cherokee letterlike`, `Fullwidth`,
`Vaporwave` (fullwidth with A→Λ and E→Ξ), `Small caps`.

**Line-break tricks for social networks**

| Name              | Result                                                            |
| ----------------- | ----------------------------------------------------------------- |
| Force line break  | Fills empty lines with `U+2800` so Facebook / Instagram stop collapsing them |
| Tabbed paragraph  | Prepends `U+3000` (full-width space) to each line as a visible indent |
| Double tabbed     | Same but two indents per line                                    |

---

## The Unicode character picker

Press `⌃⌥⌘U`. A separate floating window opens — independent of your
clipboard. Pick a glyph, it pastes at the caret.

### Layout

- **Header bar** at the top shows a large preview of the highlighted glyph,
  its description (when there's one), and its Unicode codepoint.
- **Search field** filters across the catalogue (see below).
- **Grid** with one section per category: Greek Alphabet, Superscript /
  Subscript, Marks, Mathematical Symbols, Differential Calculus, Set Theory,
  Logic, Math Letters, Arrows, Music – Notes / Accidentals / Clefs /
  Barlines / Fermata / Dynamics.
- **Recent** appears at the top once you've made at least one pick. Up to
  15 most-recent glyphs, newest first, deduplicated. Survives app restarts.

### Navigation

| Key             | Action                                              |
| --------------- | --------------------------------------------------- |
| `←` `→` `↑` `↓` | Move the highlight                                  |
| `↩`             | Insert the highlighted glyph and close              |
| `⎋`             | If the search box has text, clear it; otherwise close |

The search field is focused on open so you can type immediately. Arrow keys
and Return work even with focus in the field, so you don't have to switch.

### Search

Typing in the search field filters by, in order:

1. The custom description shipped with the entry (`"xor"`, `"therefore"`,
   `"treble clef"`, …).
2. The Unicode scalar's official name. Searching "alpha" finds α even
   though α has no custom description, because its Unicode name is
   "GREEK SMALL LETTER ALPHA".
3. The literal character.

Case-insensitive substring match throughout.

### Resizing

Drag the window edges — the grid reflows to use the new width (more
columns = more glyphs per row). When you release the drag, the window
re-centres itself on screen.

---

## The Emoji picker

Press `⌃⌥⌘E`. Same UI as the Unicode picker, scoped to emojis.
Categories: Smileys, Gestures, People, Animals, Nature, Food & Drink,
Activities, Travel & Places, Objects, Symbols, Flags.

Search runs over the Unicode name plus, for flags, the country name
(searching "italy" finds 🇮🇹).

Recent picks are tracked separately from the Unicode picker, so the two
don't pollute each other.

---

## Preferences

Open via the menu-bar icon → Settings, or `⌘,` from inside any popup.

### General

- **Launch at login** — auto-start when you log in to macOS. Driven by
  `SMAppService`, so the toggle stays in sync with what System Settings
  → Login Items shows.
- **Show icon in Dock** — turn off to run as a menu-bar app only.

### Shortcuts

Each global hotkey has its own field. Click into the field and press the
combination you want; the recorder updates. The Reset button next to each
restores its default.

| Field            | Default | Scope                                  |
| ---------------- | ------- | -------------------------------------- |
| Invoke           | `⌃⌥⌘V`  | Opens the clipboard transformer popup  |
| Unicode picker   | `⌃⌥⌘U`  | Opens the Unicode picker window        |
| Emoji picker     | `⌃⌥⌘E`  | Opens the Emoji picker window          |
| Re-center popup  | `⌥C`    | Local to the popup — only while open   |

Combinations must include at least one modifier (`⌃`, `⌥`, `⇧`, `⌘`).

### Theme

Eight themes for the popup's chrome and pickers: System, Light, Dark,
Solarized Light / Dark, Nord, Dracula, High Contrast. Click a swatch.

### Actions

The whole transformer list, in the order it appears in the popup. For
each row:

- **Drag handle** (the `≡` icon on the left) reorders the row. Drag to a
  new gap; a horizontal accent line shows where it'll land.
- **Toggle** on the right enables / disables. Disabled rows sink below the
  enabled ones; the only way back into the popup is the toggle.
- **Badge** at the front is the keyboard shortcut the row gets in the
  popup. Positions 1–9 use the digit keys; positions 10–35 use letters
  `a`–`z`; positions past the 35th get no badge (still reachable by arrow
  + Return or mouse).
- **⌥-click between two rows** adds a visual separator there — drawn both
  in Settings and in the popup. ⌥-click the same gap again removes it.
  Defaults: a separator after Clean URL and another after Reverse.

The **Reset** button restores the default order, the default enabled
state (all on), and the default separators.

---

## Tips and recipes

- **Quick clean of a Facebook URL** — copy the URL, `⌃⌥⌘V`, hit the badge
  for Clean URL. Tracking parameters disappear; group "multi-permalinks"
  links rebuild into direct `/groups/<id>/posts/<id>/` form.
- **Bold + italic on Facebook / Twitter** — copy the text, `⌃⌥⌘V`, pick
  the desired style. Result is real Unicode characters that survive
  copy-paste in places that strip formatting.
- **Force a blank line on Facebook** — type your post, fire the popup,
  pick Force line break. Empty lines now contain a non-whitespace
  invisible character so they survive Facebook's normalisation.
- **Faster Unicode** — anything you've used recently lives in the Recent
  section at the top of the picker; you usually don't need to search again.

---

## Troubleshooting

**Paste does nothing, or you hear a beep.** Almost always Accessibility.
1. Open System Settings → Privacy & Security → Accessibility.
2. Remove any TextMagician entry there (there may be more than one if you
   tested multiple builds).
3. Quit TextMagician from the menu-bar icon.
4. Relaunch, trigger an action, accept the permission prompt.
5. **Quit and relaunch a second time.** A running process doesn't see a
   permission granted while it was running.

**Some glyphs in the picker show as empty boxes.** The system font on
your Mac doesn't have those codepoints. Update macOS or accept that those
specific glyphs aren't usable; the rest of the catalogue is unaffected.

**The hotkey doesn't fire.** Open System Settings → Keyboard → Keyboard
Shortcuts and check whether something else is bound to the same
combination. Either disable the conflict or change TextMagician's
shortcut in Preferences.

**The Settings window shows the wrong app name.** Quit and relaunch from
a clean rebuild. macOS's Launch Services cache is sticky after a rename.

---

## Privacy

TextMagician is local-only:

- No network requests of any kind.
- The clipboard is read on demand and only when you invoke the popup.
- Recent picks (Unicode / emoji) are stored in your local `UserDefaults`,
  not synced anywhere.
- The Accessibility permission is used solely to post a `⌘V` keystroke to
  the frontmost app after the new value is on the clipboard.
