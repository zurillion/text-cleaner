# Text Cleaner

A lightweight macOS menubar utility that transforms the clipboard and pastes the
result into the active app. Triggered by a global hotkey (default
`⌃⌥⌘V`), it shows a floating popup with keyboard‑ and mouse‑navigable
actions; selecting one rewrites the clipboard and simulates `⌘V`.

Built with SwiftUI for macOS 14+ (Sonoma, Sequoia, Tahoe).

## Features

- Global hotkey (default `⌃⌥⌘V`), configurable in Settings.
- Floating popup, no Dock icon (`LSUIElement`), menu bar item only.
- Three navigation modes:
  - `↑` / `↓` to move the highlight, `Return` to confirm.
  - `1`–`9` to pick an item directly.
  - Mouse hover + click.
- `Esc` or click outside the popup cancels.
- Reads plain text or RTF/RTFD/HTML from the clipboard, applies the
  transformation, and pastes the plain text back via simulated `⌘V`.
- Actions: Remove formatting, UPPERCASE, lowercase, camelCase, snake_case.
- Settings window with a shortcut recorder.

## Project layout

```
TextCleaner/
  TextCleanerApp.swift         App entry, Settings scene
  AppDelegate.swift            Lifecycle, status item, hotkey wiring
  HotKeyManager.swift          Carbon RegisterEventHotKey wrapper
  KeyboardShortcut.swift       Shortcut model + display string
  HotKeySettings.swift         UserDefaults persistence
  TextAction.swift             Actions + transformations
  PopupView.swift              SwiftUI popup UI
  PopupWindowController.swift  NSPanel host, key routing
  PasteSimulator.swift         Clipboard read/write + CGEvent ⌘V
  SettingsView.swift           Preferences UI
  ShortcutRecorder.swift       NSView-based shortcut recorder
  Info.plist
  TextCleaner.entitlements
project.yml                    XcodeGen project definition
```

## Building

The repository contains source files and an [XcodeGen](https://github.com/yonaskolb/XcodeGen)
spec rather than a checked‑in `.xcodeproj` (the project file is fragile and
better regenerated).

### Option 1 — XcodeGen (recommended)

```sh
brew install xcodegen
xcodegen generate
open TextCleaner.xcodeproj
```

Then build & run in Xcode (`⌘R`).

### Option 2 — Create the Xcode project manually

1. Xcode → File → New → Project → macOS → App.
2. Product name: `TextCleaner`, Interface: SwiftUI, Language: Swift.
3. Delete the auto‑generated `TextCleanerApp.swift` and `ContentView.swift`.
4. Drag the contents of `TextCleaner/` from this repo into the project (Copy
   items: off, Create groups).
5. In Target → Build Settings:
   - Set `Info.plist File` to `TextCleaner/Info.plist`.
   - Set `Code Signing Entitlements` to `TextCleaner/TextCleaner.entitlements`.
   - Set Deployment Target to macOS 14.0 or newer.
6. Build & run.

## First launch / permissions

The first time you trigger an action, macOS will prompt to grant **Accessibility**
permission (needed to post the simulated `⌘V` keystroke to other apps).

System Settings → Privacy & Security → Accessibility → enable *Text Cleaner*.

If the hotkey doesn't fire, check System Settings → Keyboard → Keyboard
Shortcuts for a conflict with the default `⌃⌥⌘V`, or change the shortcut in
the app's Settings window.

## Notes on design

- Global hotkey uses Carbon's `RegisterEventHotKey`, which is still the
  recommended approach on modern macOS for non‑sandboxed utilities and works
  without Accessibility permission.
- The popup is an `NSPanel` with `.nonactivatingPanel`, so opening it does not
  deactivate the front app. This way `⌘V` lands in the original frontmost
  window when an action is chosen.
- App sandbox is disabled in the entitlements — required because we need to
  post events to other apps via the HID event tap.
