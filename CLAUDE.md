# CLAUDE.md — TextMagician handover

This file is loaded automatically by Claude Code. It is the single source of
truth for picking up development of this app. Read it fully before touching
code. It was written to let a fresh Claude continue exactly where the previous
(cloud) sessions left off.

---

## 1. What this is

A **macOS menu-bar utility** that transforms the clipboard and pastes the
result into whatever app is frontmost, driven by global hotkeys. Three tools,
one app:

| Tool | Default hotkey | What it does |
|------|----------------|--------------|
| **Transformations popup** ("Show Cleaner") | `⌃⌥⌘V` | A floating list of text actions (case changes, Clean URL, LaTeX→Unicode, HTML→RichText/PlainText, 25+ Unicode "font" styles, reverse, line-break tricks…). Pick one → it rewrites the clipboard and pastes it. |
| **Unicode character picker** | `⌃⌥⌘U` | Searchable catalog of symbols (math, arrows, music, decorative alphabets…), with a Recent section and a **pin** to insert several in a row. |
| **Emoji picker** | `⌃⌥⌘E` | Same UI as the Unicode picker, emoji catalog, separate recents. |

SwiftUI + AppKit. **Deployment target: macOS 12 (Monterey).** Universal
binary (Intel `x86_64` + Apple Silicon `arm64`).

---

## 2. Golden rules (do not break these)

- **Names:** the app is displayed as **"TextMagician"** but the Xcode
  project, target, executable, all file names and all internal identifiers
  (UserDefaults keys prefixed `TextCleaner.`, `Notification.Name`s, type
  names) stay **"TextCleaner"**. Only the user-visible name and the bundle id
  were ever changed. Do **not** rename internals.
- **Bundle id must be `com.caristi.TextMagician`.** An earlier
  `com.example.TextCleaner` was *rejected by syspolicyd on macOS 26* even when
  notarized. Never revert to `com.example.*` or any reverse-DNS you don't
  control.
- **Branch: `main` only.** Other branches are being deleted. (In the cloud env
  a stray `claude/fix-font-settings-apply-YD9f6` kept getting checked out on
  container recreation and had to be realigned to `main`; locally this won't
  happen, but always confirm you're on `main` before committing.)
- **Repo stays PUBLIC.**
- **No LICENSE file** yet (user: "per ora lascia così").
- **Never** put a model identifier (e.g. "Opus", "claude-…") into commits,
  PR text, code comments or any committed artifact. Keep it to chat only.
- Action names stay **in English** everywhere, including the Italian guide.
- The user communicates in **Italian**; reply in Italian.

---

## 3. Local build & the #1 gotcha

Development is now **local** (the user compiles directly in Xcode).

- Open the project in Xcode, **⌘B** to build, **⌘R** to run, **⌘U** for tests.
- **`TextCleaner.xcodeproj/` is gitignored** (see `.gitignore`). The project
  is maintained by hand in Xcode — despite the gitignore comment, there is
  **no `project.yml`/XcodeGen** in the repo. Consequence:

  > **When you add a NEW `.swift` file, the user must add it to the target's
  > *Compile Sources* build phase in Xcode, or it won't compile
  > ("Cannot find X in scope").** Prefer putting new code in an **existing**
  > file to avoid this. The same applies to new files in `TextCleanerTests/`
  > (manual add to the test target).

- You (Claude) cannot build here either way — **the user's Xcode is the
  compiler.** Expect build errors to come back from them; after any
  non-trivial change, ask for the build result or watch for pasted errors.
  Type mismatches that a read-through misses (e.g. a property defined on the
  enum but called on the struct) will surface there.

---

## 4. Source map (`TextCleaner/`)

Entry / app shell
- `TextCleanerApp.swift` — `@main`.
- `AppDelegate.swift` — status item, hotkey registration, owns the three
  controllers, dock-icon activation policy, the native Accessibility prompt.
  Picker hotkeys call `toggle()` (second press dismisses).
- `Info.plist` — `CFBundleDisplayName`/`CFBundleName` = TextMagician;
  bundle id = `$(PRODUCT_BUNDLE_IDENTIFIER)` = `com.caristi.TextMagician`;
  `LSMinimumSystemVersion` = `$(MACOSX_DEPLOYMENT_TARGET)` (= 12.0, set in the
  Xcode target, not in the repo).

Transformations popup
- `PopupWindowController.swift` — the main popup + a sibling preview/edit
  panel. Drag-by-titlebar, resign/close, **global click-outside monitor**,
  the ⌘T Fonts-panel handoff, paste. `effectiveSource(for:)` chooses the
  clipboard flavor per action.
- `PopupView.swift` — SwiftUI view, `PopupViewModel`, `ActionShortcutKey`
  (1–9 then a–z), and the compat shims **`onChangeCompat`** and
  **`AutomaticScrollIndicatorsIfAvailable`** (see §6).
- `PreviewView.swift`, `RichTextView.swift` — preview pane and the NSTextView
  wrapper used for inline editing (bold/italic/Fonts panel).

Pickers (Unicode + Emoji share one controller/view)
- `CharacterPickerController.swift` — `PickerPanel`, pin logic, drag, global
  click monitor, `toggle()`, `FirstMouseHostingView`. Two instances in
  `AppDelegate` with different catalogs/recents.
- `CharacterPickerView.swift` — SwiftUI view + `CharacterPickerModel`.
- `CharacterCatalog.swift`, `EmojiCatalog.swift` — the section catalogs.

Text processing
- `TextAction.swift` — `TextActionKind` enum (order = default popup order),
  `TextAction` struct (title/icon + `transform`), and **`TextTransforms`**
  (camelCase, snakeCase, **`latexToUnicode`**). Icons use `displayIcon` to
  substitute SF-Symbols-4 glyphs on macOS 12 (see §6).
- `TextStyler.swift` — the Unicode "font" style engine (math alphabets with
  Letterlike-block "holes", combining marks, upside-down, fullwidth, vaporwave,
  small caps, Cherokee/Squiggle tables, reverse, line-break/tab tricks).
- `URLCleaner.swift` — strips tracking params; special-cases Facebook group
  `multi_permalinks` reconstruction and **Amazon** canonicalization to
  `/dp/<ASIN>`.

Settings & infra
- `AppSettings.swift` — `ObservableObject` over UserDefaults: action
  preferences (order + enabled), separator anchors, the three shortcuts,
  recents, theme, launch-at-login, **migrations** (see §7).
- `SettingsView.swift` / `SettingsWindowController.swift` — Preferences window
  (drag-reorder list via `ReorderDropTarget`, ⌥-click to toggle separators).
- `PasteSimulator.swift` — clipboard read/write + synthetic ⌘V.
- `HotKeyManager.swift` — Carbon `RegisterEventHotKey` registry by name.
- `HotKeySettings.swift` — popup hotkey persistence (default `⌃⌥⌘V`).
- `KeyboardShortcut.swift`, `ShortcutRecorder.swift` — shortcut model + recorder.
- `PopupTheme.swift` — 8 themes (`system/light/dark/midnight/ocean/forest/sunset/mono`).
- `WindowDragHandle.swift` — the NSView that drives window dragging + hand cursor.
- `AppIcon.swift` — the app icon drawn in code (`AppIcon.make()`), also the
  source for `Scripts/build-app-icon.swift`.

Tests: `TextCleanerTests/URLCleanerTests.swift` — URL cleaning **and** the
LaTeX→Unicode tests (`LaTeXUnicodeTests` lives in that file on purpose, to
avoid a manual test-target add).

Ignore `WinTextCleaner/` (a separate Tauri/Windows experiment, not part of
this app).

---

## 5. How a paste actually works (critical mental model)

`PasteSimulator`: snapshot the pasteboard → write the new content → post a
synthetic **⌘V** (`CGEvent`, `.maskCommand`, `cghidEventTap`) → restore the
original pasteboard after ~0.4 s. **Requires the Accessibility permission**
(TCC). The synthetic ⌘V **follows system keyboard focus**, so the paste only
works when the *target app* is frontmost and focused.

All popup/picker windows are **`.nonactivatingPanel`, `.floating`,
`hidesOnDeactivate = false`**. Because of the focus rule above, the
controllers:
- remember `previousFrontmost` on show,
- on commit, re-activate the target app (and, for the popup, `orderOut` the
  panel) and **delay** a beat before posting ⌘V so the activation settles.

Known non-bug: on one of the user's Macs "paste only produced a lone `v`".
That turned out to be **Screen Sharing stripping the modifier** from synthetic
events, *not* a code bug. Don't chase it in code.

---

## 6. macOS 12 compatibility (a principle the user cares about)

The app was lowered from Sonoma (14) to Monterey (12). **Rule the user stated
explicitly:** keep the *modern* API on the OS that has it, and fence the legacy
fallback behind `#available` — do **not** downgrade for everyone to a
deprecated API. Current gated spots:

- `onChangeCompat(of:perform:)` — 2-param `onChange` on macOS 14+, 1-param
  (deprecated there) only on 12–13. (One intentional deprecation warning lives
  in that helper.)
- `AutomaticScrollIndicatorsIfAvailable` — `.scrollIndicators` on 13+, no-op on 12.
- `SMAppService` (launch-at-login) gated to 13+; the toggle is hidden on 12
  via `AppSettings.supportsLaunchAtLogin`.
- Drag-reorder: `.draggable`/`.dropDestination` on 13+, `.onDrag`/`.onDrop`
  fallback on 12 (`ReorderDropTarget` + the `if #available` in `dragHandle`).
- SF Symbols: `TextAction.displayIcon` and `SettingsView.dragHandleSymbol`
  substitute SF-Symbols-4 (macOS 13) glyphs (`characters.uppercase/lowercase`,
  `line.3.horizontal`) with macOS-12 equivalents. **When adding an action
  icon, use a symbol that exists in macOS 12, or add it to that substitution.**
- Window activation uses `NSApp`/`NSRunningApplication.activate()` on 14+ with
  the `options:` form on older.

---

## 7. The action system & settings

- **Order:** the order of `TextActionKind.allCases` is the default popup order.
  Numeric/letter shortcuts (`1`–`9`, then `a`–`z`) follow the enabled list by
  position, not by action.
- **Enabled by default:** `defaultEnabled` returns `true` for everything; the
  popup scrolls and the user prunes in Settings.
- **Separators** are anchored to the action **above** them:
  `AppSettings.separatorAfterKinds : Set<TextActionKind>`. Default is
  `[.htmlToPlainText, .reverse]` (section-1 boundary sits after the HTML
  actions). ⌥-click a gap in Settings toggles one.
- **`decodePreferences`** decodes the saved list leniently and **inserts
  newly-shipped kinds at their canonical position** (right after the nearest
  preceding known kind), not at the bottom. So to place a new action, just put
  its `case` in the right spot in `TextActionKind` and existing users get it
  there too.
- **Migrations** run once in `AppSettings.init`, keyed by a bool flag in
  UserDefaults (e.g. `didMigrateHTMLSeparator`, which moved the old
  `.cleanURL` separator boundary to `.htmlToPlainText`). Add a new flag for any
  future one-shot migration; never mutate the user's set unconditionally.

### Adding a new text action — checklist
1. Add a `case` to `TextActionKind` at the desired position (before the
   section separator anchor if it belongs in section 1).
2. Add a `TextAction(kind:title:icon:)` row to `TextAction.all` (icon must
   render on macOS 12 — see §6).
3. Add the `case` to `transform(_:)`.
4. If it must read a specific clipboard flavor (like the HTML actions), set
   `prefersHTMLSource` (**on `TextActionKind`**, not `TextAction`) and the
   model's `effectiveSource(for:)` will route it.
5. Tests go in `URLCleanerTests.swift` (existing test file → no target edit).

### The three clipboard-normalization actions (recent work)
- **LaTeX → Unicode** (`latexToUnicode`): single-pass scanner that turns
  MathJax/KaTeX clipboard LaTeX back into Unicode — `\(\Lambda \)CDM` → `ΛCDM`,
  Greek/operators/arrows, `\frac{}{}`, `^`/`_` super/subscripts, `\vert`/`\Vert`
  bars, `\text{}` wrappers, spacing macros. It **eats the one trailing space
  after a command** (standard LaTeX; this is why `\Lambda )CDM` glues
  correctly). `$…$` is left alone (currency). Unknown commands are kept
  verbatim. Tables are built with `uniquingKeysWith` so a stray duplicate key
  can't trap at launch.
- **HTML → Rich Text / HTML → Plain Text**: read the clipboard's `.html`
  flavor *specifically* (`PasteSimulator.readHTMLAttributed`), via
  `model.htmlSource` + `prefersHTMLSource`, so they work even when a richer
  flavor (RTF) is also present. `HTML → Plain Text` overlaps with
  `Remove formatting` only when no RTF is present.

---

## 8. Pin / dismiss behavior (pickers)

- **Pin** (top-right of each picker): keeps the window floating so the user can
  insert several glyphs and alternate with normal typing. While pinned the
  panel yields keyboard focus (`becomesKeyOnlyIfNeeded = true`) and outside
  clicks are ignored. `commitPinned` calls `NSApp.deactivate()` + reactivates
  the target before the ⌘V so the glyph lands in the target app, not our own
  search field (which is force-defocused). `FirstMouseHostingView` makes the
  first click on a non-key pinned window insert rather than just focus.
- **Dismiss:** click outside = Esc (a global `addGlobalMonitorForEvents`
  mouse-down monitor, since a non-activating panel doesn't reliably resign
  key). It closes with `reactivating: false` so focus stays in the app the user
  clicked. Re-pressing the hotkey toggles the window closed — the way out of a
  pinned window.

---

## 9. Distribution (now done locally)

Signing + notarization + DMG, all from the user's Mac:

1. **Sign:** Developer ID Application, Hardened Runtime on. (The user is an
   Apple Developer; direct distribution, not App Store.)
2. **Archive** with destination **"Any Mac"** to get the universal binary;
   verify with `lipo -info <app>/Contents/MacOS/TextCleaner` → `x86_64 arm64`.
3. **notarytool credentials are per-Mac** (not iCloud-synced). On the local
   Mac run once:
   `xcrun notarytool store-credentials "<profile>" --apple-id … --team-id … --password <app-specific-password>`
   (app-specific password from appleid.apple.com; avoid smart quotes; store in
   the **login** keychain). Then pass `<profile>` to the DMG script.
4. **`Scripts/make-dmg.sh <exported-.app> <notary-profile>`** — verifies
   signature/staple, builds the DMG with an /Applications symlink, bundles the
   guides (`USAGE.md`→"User Guide", `USAGE.it.md`→"Guida d'uso"), notarizes +
   staples the DMG, and emits both `TextMagician-<version>.dmg` and a
   versionless **`TextMagician.dmg`**.
5. **Release:** upload the versionless `TextMagician.dmg` to the GitHub Release
   — the Pages download button points at
   `releases/latest/download/TextMagician.dmg`, which only redirects if an
   asset with that exact name exists.

`Scripts/build-app-icon.swift` regenerates `TextCleaner/AppIcon.icns` (a
gitignored artifact).

DMG transfer note: the user keeps **Gatekeeper disabled** on all their Macs.
**WhatsApp corrupts the DMG** — use email / AirDrop / the GitHub Release.

---

## 10. GitHub Pages

- Static site at `docs/index.html`, served from **branch `main`, folder
  `/docs`**. Screenshots in `docs/Screenshots/` (must live inside `/docs` or
  Pages 404s them). `docs/README.md` documents the publish/release flow.
- The hero CTA scrolls to the in-page install instructions (`#install`); the
  real download button is inside that box.
- Advertised compatibility was updated to macOS 12 + universal.

---

## 11. Known gotchas (quick recall)

- New `.swift` file → manual *Compile Sources* add in Xcode (§3).
- SF Symbols: avoid SF-Symbols-4 (macOS 13) names unless gated (§6).
- Dictionary literals with many entries → build with `uniquingKeysWith` to
  avoid a duplicate-key launch trap (see `latexCommands`).
- A property used from SwiftUI on a `TextAction` must exist on `TextAction`;
  several metadata props live on `TextActionKind` and are reached via
  `action.kind.…`.
- notarytool "No Keychain password item found" → re-run `store-credentials`
  on this Mac, no smart quotes, login keychain.

---

## 12. Current state

- `main` is at the latest work (as of this handover, HEAD = the "LaTeX →
  Unicode: support \vert and \Vert" commit). All features described above are
  merged and pushed.
- **Stale:** the root `README.md` still says "macOS 14+ (Sonoma, Sequoia,
  Tahoe)" — update it to macOS 12 Monterey + universal to match reality.
- **GitHub side (user action):** delete the stray `claude/*` branches; confirm
  `main` is the default branch and Pages points at `main` + `/docs`.
- **Possible next work the user has floated / that's open:**
  - LaTeX converter spacing: a symbol-command immediately before an operator
    (`\vert =`, `\cdot`) glues them (`|=`, `⋅‖`) because LaTeX space-eating is
    intentional. Optional improvement: re-insert a space when a converted
    symbol is followed by a relation/operator.
  - More LaTeX: accents (`\hat`, `\vec`, `\bar`), `\mathbb{R}`→ℝ blackboard
    bold, nested `\frac`.
  - Formatting-preserving LaTeX conversion (currently plain-text output).
  - Pin feature: the search-then-switch-apps edge case for the paste target.

---

## 13. Commit conventions

- Work on `main`. Branch only if the user asks; never push to another branch
  without explicit permission.
- `git push -u origin main`; retry network failures a few times with backoff.
- Do **not** open a PR unless the user asks.
- End commit messages with the `Co-Authored-By: Claude …` line your harness
  provides for your session (and the session link line if given). Never add a
  model marketing name anywhere committed.
