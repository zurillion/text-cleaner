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
- **Branch: `main` only.** `main` is the sole branch on GitHub and the
  default. Work on it directly; branch only if the user explicitly asks.
- **Repo stays PUBLIC.**
- **No LICENSE file** yet (user: "per ora lascia così").
- **Never** put a model identifier (e.g. "Opus", "claude-…") into commits,
  PR text, code comments or any committed artifact. Keep it to chat only.
- Action names stay **in English** everywhere, including the Italian guide.
- The user communicates in **Italian**; reply in Italian.

---

## 3. Local build, run & test

Development is **local**. The user works in Xcode (**⌘B** build, **⌘R** run,
**⌘U** tests). The agent builds, runs and tests the same project from the
command line with `xcodebuild`. Build after every non-trivial change: the
compiler catches what a read-through misses (e.g. a property defined on the
enum but called on the struct).

- **Fresh clone:** run `swift Scripts/build-app-icon.swift` once before the
  first build. It generates `TextCleaner/AppIcon.icns`, which is gitignored
  but copied by the target's *Copy AppIcon* phase. Without it the build fails.
- **Agent commands** (from the repo root; `build/` is gitignored):
  - Build the copy the user runs:
    `xcodebuild -project TextCleaner.xcodeproj -scheme TextCleaner -configuration Debug -derivedDataPath build build`
    → `build/Build/Products/Debug/TextCleaner.app`.
  - Run it: `open build/Build/Products/Debug/TextCleaner.app`. First check
    `pgrep -f "TextCleaner.app/Contents/MacOS/TextCleaner"` and quit any old
    instance, because two instances fight over the hotkeys. Rebuild and
    relaunch before asking the user to try a change.
  - Tests:
    `xcodebuild test -project TextCleaner.xcodeproj -scheme TextCleaner -destination 'platform=macOS,arch=arm64' -derivedDataPath build/test-dd`.
    The separate derived data leaves the user's copy in `build/` alone. About
    10 s once warm.
  - Universal check: build with
    `-configuration Release -destination 'generic/platform=macOS'`, then
    `lipo -info …/TextCleaner.app/Contents/MacOS/TextCleaner` → `x86_64 arm64`.
- **Signing** is automatic (team `64W93FA2AN`, "Apple Development") and works
  from the command line with no extra flags. The designated requirement stays
  the same across rebuilds, so the Accessibility grant survives them.
- **Same bundle id:** a debug build reads and writes the user's **real**
  preferences, and one-shot migrations run on them.
- **The Xcode project is tracked:** `project.pbxproj`, the workspace data and
  the shared scheme (`xcshareddata/xcschemes/TextCleaner.xcscheme`). Per-user
  `xcuserdata` stays ignored. There is **no `project.yml`/XcodeGen**: the
  `.xcodeproj` is the source of truth.

  > **Adding a NEW `.swift` file to the app:** the `TextCleaner` target uses
  > classic groups, so the file must be registered in its *Compile Sources*
  > phase or it won't compile ("Cannot find X in scope"). In
  > `project.pbxproj` that means four consistent UUID-keyed entries: a
  > `PBXFileReference`, a `PBXBuildFile`, the `PBXGroup` child and the
  > `Sources` phase entry. Build right after the edit to check it.
  >
  > **New test files need nothing:** `TextCleanerTests/` is a synchronized
  > folder, so every `.swift` file in it is compiled into the test target.

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
  target's build settings in `project.pbxproj`).

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

Tests: the `TextCleanerTests` unit-test target, hosted by the app
(`@testable import TextCleaner`), compiles every file in `TextCleanerTests/`.
`URLCleanerTests.swift` holds the URL-cleaning tests and `LaTeXUnicodeTests`;
new test files can go next to it. Because the tests are hosted, the app
launches during a test run (status item, hotkeys). The test target's
deployment target is 14.0 because Xcode 27's XCTest is built for macOS 14;
the app itself stays at 12.0.

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
  (deprecated there) only on 12–13. The build is warning-free: the 1-param
  form is deprecated only from macOS 14, above the deployment target.
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
5. Add tests in `TextCleanerTests/`, in an existing file or a new one (new
   files are picked up automatically, see §3).

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

### Stack mode (pinned popup)
- Pin button in the popup title bar / `⌘P`. While pinned, a click or badge
  key **pushes** the action onto `PopupViewModel.stack` (a
  `TransformationStack`, in `PopupView.swift`) instead of pasting; `→`
  pushes the highlighted one; `↩` pastes `stackResult`; `⌘Z` / `⇧⌘Z`
  undo/redo. ⌘ keys are claimed in `PopupPanel.performKeyEquivalent`
  (the main menu's Edit ▸ Undo would otherwise eat ⌘Z); ⌘-letters never
  trigger action shortcuts.
- Each layer stores its own result; layers are LIFO. An edit (`⇥`, then
  `⇧↩`) is pushed as an `.edit` layer holding the edited snapshot, so
  removing layers from the middle is deliberately unsupported.
- `result(applying:)` feeds an action the stack top, or its preferred
  clipboard flavor while the stack is empty; HTML actions are disabled
  (`isAvailable`) above the first layer.
- The stack column is an overlay on the popup's leading padding, so the
  list decides the height; `updateMainPanelWidth()` grows the panel to the
  left so the list and preview don't move. Unpinning keeps the stack
  (`showsStack`); `show()` resets it; the hotkey closes a pinned popup;
  outside clicks / resign-key don't. The main panel accepts first mouse.
- Tests: `TextCleanerTests/TransformationStackTests.swift`.

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
   Apple Developer; direct distribution, not App Store.) The Developer ID
   certificate must be in the keychain of the Mac that builds the release;
   check with `security find-identity -v -p codesigning`.
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

- New `.swift` file in the app → must be in the `TextCleaner` target's
  *Compile Sources* phase (§3). New files in `TextCleanerTests/` are picked up
  automatically.
- Fresh clone fails on a missing `AppIcon.icns` → run
  `swift Scripts/build-app-icon.swift` (§3).
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

- All features described above are on `main`. The `.xcodeproj` and its
  shared scheme are tracked, so a fresh clone builds once the icon is
  generated (§3).
- The `TextCleanerTests` unit-test target (36 tests) runs with ⌘U or
  `xcodebuild test`.
- **GitHub side:** `main` is the only branch and the default. Verify Pages
  still serves `main` + `/docs` (the live site works, so it's configured).
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
- End commit messages with `Co-Authored-By: Claude <noreply@anthropic.com>`,
  plus the session link line if your harness gives one. If the harness's line
  includes a model name, drop it: no model name goes into anything committed
  (§2).
