# TextMagician

A lightweight macOS menu bar utility that transforms the clipboard and pastes
the result into the active app. Triggered by a global hotkey (default
`⌃⌥⌘V`), it shows a floating popup with keyboard‑ and mouse‑navigable
actions; selecting one rewrites the clipboard, simulates `⌘V`, and then
restores the original clipboard contents.

Built with SwiftUI and AppKit for macOS 12 Monterey and later, as a
universal binary (Apple Silicon and Intel).

## Features

- Global hotkey (default `⌃⌥⌘V`), configurable in Settings.
- Floating popup with three navigation modes:
  - `↑` / `↓` to move the highlight, `Return` to confirm.
  - `1`–`9` then `a`–`z` to pick an item directly by its badge.
  - Mouse hover + click.
- `Esc` or click outside the popup cancels.
- Reads plain text or RTF/RTFD/HTML from the clipboard, applies the
  transformation, pastes the plain text via simulated `⌘V`, then restores
  the previous clipboard so other apps don't see the change.
- Built-in actions: Remove formatting, UPPERCASE, lowercase, camelCase,
  snake_case, Clean URL (strips tracking parameters like `utm_*`,
  `fbclid`, `gclid`, Facebook `__cft__*`/`__tn__*`, Amazon
  `pf_rd_*`/`pd_rd_*`, etc., with host-specific rules for YouTube,
  Twitter/X, Instagram, LinkedIn, TikTok, Spotify, Reddit, and Amazon).
  Facebook group "multi-permalinks" feed links are rebuilt into the
  canonical `/groups/<id>/posts/<id>/` direct link, and Amazon product
  links collapse to `/dp/<ASIN>`.
- Clipboard clean-up: LaTeX → Unicode (turns MathJax/KaTeX math such as
  `\(\Lambda \)CDM` back into `ΛCDM`), HTML → Rich Text and
  HTML → Plain Text.
- 25 Unicode text styles (bold, italic, double-struck, monospace, script,
  fraktur, strikethrough, small caps, fullwidth, upside down…), Reverse,
  and line-break/tab helpers.
- A searchable Unicode character picker (default `⌃⌥⌘U`) and an Emoji
  picker (default `⌃⌥⌘E`), each with recents and a pin to insert several
  characters in a row.
- Optional Dock icon (default ON) rendered programmatically, with a
  right‑click menu mirroring the menu bar item.
- 8 selectable popup themes.
- Settings window with a live shortcut recorder.

## Project layout

```
TextCleaner.xcodeproj              Xcode project (shared scheme: TextCleaner)
TextCleaner/
  TextCleanerApp.swift             App entry
  AppDelegate.swift                Lifecycle, status item, hotkey wiring,
                                   Dock menu, Accessibility prompt
  AppIcon.swift                    Programmatic app icon
  AppSettings.swift                Observable user prefs (actions, shortcuts,
                                   theme, recents, launch at login)
  HotKeyManager.swift              Carbon RegisterEventHotKey wrapper
  KeyboardShortcut.swift           Shortcut model + display string
  HotKeySettings.swift             Popup hotkey persistence
  TextAction.swift                 Actions + transformations
  TextStyler.swift                 Unicode text styles
  URLCleaner.swift                 Tracking-parameter stripping for Clean URL
  PopupTheme.swift                 Theme palette
  PopupView.swift                  SwiftUI popup UI
  PopupWindowController.swift      NSPanel host, key routing, paste
  PreviewView.swift                Preview pane
  RichTextView.swift               NSTextView wrapper for inline editing
  CharacterPickerController.swift  Unicode/Emoji picker panel, pinning
  CharacterPickerView.swift        Picker UI
  CharacterCatalog.swift           Unicode picker catalog
  EmojiCatalog.swift               Emoji picker catalog
  PasteSimulator.swift             Clipboard snapshot/restore + Cmd-V
  SettingsView.swift               Settings UI
  SettingsWindowController.swift   Hosts SettingsView in a custom NSWindow
  ShortcutRecorder.swift           NSView-based shortcut recorder
  WindowDragHandle.swift           Window dragging handle
  Info.plist
  TextCleaner.entitlements
TextCleanerTests/                  Unit tests (URL cleaning, LaTeX → Unicode)
Scripts/
  build-app-icon.swift             Generates TextCleaner/AppIcon.icns
  make-dmg.sh                      Builds the notarized release DMG
docs/                              GitHub Pages site
```

## Building

Requires Xcode 16 or later.

Before the first build, generate the app icon. `TextCleaner/AppIcon.icns`
is gitignored, but the target copies it into the app bundle, so the build
fails without it:

```sh
swift Scripts/build-app-icon.swift
```

Then open the project and build and run with `⌘R`:

```sh
open TextCleaner.xcodeproj
```

The first time you build, set a signing team to keep the binary's code
signature stable across rebuilds:

1. Select the `TextCleaner` project in the Project Navigator.
2. In the project editor pane, select the `TextCleaner` target.
3. Open the **Signing & Capabilities** tab.
4. Tick **Automatically manage signing** and pick your team in the
   **Team** dropdown (a free Personal Team works).

Without a stable team, every rebuild produces a slightly different
signature and macOS revokes the Accessibility permission you granted
to the previous build.

### Tests

Run the unit tests with `⌘U` in Xcode, or from the command line:

```sh
xcodebuild test -project TextCleaner.xcodeproj -scheme TextCleaner -destination 'platform=macOS'
```

The tests live in `TextCleanerTests/`. Any Swift file added to that
folder is compiled into the test target automatically. The tests run
inside the app, so TextMagician launches briefly during a test run.

## First launch / permissions

The first time you trigger an action, macOS prompts to grant
**Accessibility** permission, which is needed to post the simulated `⌘V`
keystroke to other apps.

System Settings → Privacy & Security → Accessibility → enable
*TextMagician*.

If the hotkey doesn't fire, check System Settings → Keyboard →
Keyboard Shortcuts for a conflict with the default `⌃⌥⌘V`, or change
the shortcut in the app's Settings window.

## Notes on design

- Global hotkey uses Carbon's `RegisterEventHotKey`, still the recommended
  approach on modern macOS for non‑sandboxed utilities. It works without
  Accessibility permission.
- The popup is an `NSPanel` with `.nonactivatingPanel`, so opening it
  doesn't deactivate the front app. The previously frontmost app is also
  remembered explicitly and re‑activated right before posting `⌘V`, which
  makes paste reliable even when the Dock icon is visible.
- After posting `⌘V`, the simulator restores every original pasteboard
  item (plain text, RTF, HTML, images, etc.) so the user's clipboard
  appears untouched.
- App sandbox is disabled in the entitlements — required to post events
  to other apps via the HID event tap.
