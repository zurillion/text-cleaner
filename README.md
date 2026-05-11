# Text Cleaner

A lightweight macOS menu bar utility that transforms the clipboard and pastes
the result into the active app. Triggered by a global hotkey (default
`⌃⌥⌘V`), it shows a floating popup with keyboard‑ and mouse‑navigable
actions; selecting one rewrites the clipboard, simulates `⌘V`, and then
restores the original clipboard contents.

Built with SwiftUI for macOS 14+ (Sonoma, Sequoia, Tahoe).

## Features

- Global hotkey (default `⌃⌥⌘V`), configurable in Settings.
- Floating popup with three navigation modes:
  - `↑` / `↓` to move the highlight, `Return` to confirm.
  - `1`–`9` to pick an item directly.
  - Mouse hover + click.
- `Esc` or click outside the popup cancels.
- Reads plain text or RTF/RTFD/HTML from the clipboard, applies the
  transformation, pastes the plain text via simulated `⌘V`, then restores
  the previous clipboard so other apps don't see the change.
- Built-in actions: Remove formatting, UPPERCASE, lowercase, camelCase,
  snake_case.
- Optional Dock icon (default ON) rendered programmatically, with a
  right‑click menu mirroring the menu bar item.
- 8 selectable popup themes.
- Settings window with a live shortcut recorder.

## Project layout

```
TextCleaner.xcodeproj           Xcode project
TextCleaner/
  TextCleanerApp.swift          App entry
  AppDelegate.swift             Lifecycle, status item, hotkey wiring,
                                Dock menu, Accessibility prompt
  AppIcon.swift                 Programmatic Dock icon
  AppSettings.swift             Observable user prefs (Dock toggle, theme)
  HotKeyManager.swift           Carbon RegisterEventHotKey wrapper
  KeyboardShortcut.swift        Shortcut model + display string
  HotKeySettings.swift          UserDefaults persistence
  TextAction.swift              Actions + transformations
  PopupTheme.swift              Theme palette
  PopupView.swift               SwiftUI popup UI
  PopupWindowController.swift   NSPanel host, key routing
  PasteSimulator.swift          Clipboard snapshot/restore + Cmd-V
  SettingsView.swift            Settings UI
  SettingsWindowController.swift  Hosts SettingsView in a custom NSWindow
  ShortcutRecorder.swift        NSView-based shortcut recorder
  Info.plist
  TextCleaner.entitlements
```

## Building

```sh
open TextCleaner.xcodeproj
```

Then build and run with `⌘R`.

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

## First launch / permissions

The first time you trigger an action, macOS prompts to grant
**Accessibility** permission, which is needed to post the simulated `⌘V`
keystroke to other apps.

System Settings → Privacy & Security → Accessibility → enable
*Text Cleaner*.

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
