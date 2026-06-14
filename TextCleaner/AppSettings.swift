import AppKit
import Carbon.HIToolbox
import Combine
import Foundation
import ServiceManagement

extension Notification.Name {
    static let dockIconPreferenceChanged = Notification.Name("TextCleaner.dockIconChanged")
    static let pickerHotKeyChanged = Notification.Name("TextCleaner.pickerHotKeyChanged")
    static let emojiPickerHotKeyChanged = Notification.Name("TextCleaner.emojiPickerHotKeyChanged")
}

/// User-overridable configuration for one of the built-in actions:
/// which kind it is, and whether it appears in the popup. The list
/// order in `AppSettings.actionPreferences` is the popup display
/// order, so numeric shortcuts (1, 2, …) follow it automatically.
struct ActionPreference: Codable, Equatable, Hashable, Identifiable {
    let kind: TextActionKind
    var enabled: Bool
    var id: TextActionKind { kind }
}

/// Observable store for user preferences other than the global hotkey
/// (which lives in `HotKeySettings` because it predates this store).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let showDockIcon              = "TextCleaner.showDockIcon"
        static let popupTheme                = "TextCleaner.popupTheme"
        static let centerShortcut            = "TextCleaner.centerShortcut"
        static let actionPreferences         = "TextCleaner.actionPreferences"
        static let pickerShortcut            = "TextCleaner.pickerShortcut"
        static let emojiPickerShortcut       = "TextCleaner.emojiPickerShortcut"
        static let recentPickedCharacters    = "TextCleaner.recentPickedCharacters"
        static let recentPickedEmojis        = "TextCleaner.recentPickedEmojis"
        static let separatorAfterKinds       = "TextCleaner.separatorAfterKinds"
    }

    /// How many entries the picker's Recent section keeps. Pushing a
    /// new pick beyond this drops the oldest entry.
    static let recentCharactersLimit = 15

    @Published var showDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDockIcon, forKey: Key.showDockIcon)
            NotificationCenter.default.post(name: .dockIconPreferenceChanged, object: nil)
        }
    }

    @Published var theme: PopupTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Key.popupTheme)
        }
    }

    @Published var centerShortcut: KeyboardShortcut {
        didSet {
            if let data = try? JSONEncoder().encode(centerShortcut) {
                UserDefaults.standard.set(data, forKey: Key.centerShortcut)
            }
        }
    }

    /// Global hotkey that opens the Unicode picker window.
    @Published var pickerShortcut: KeyboardShortcut {
        didSet {
            if let data = try? JSONEncoder().encode(pickerShortcut) {
                UserDefaults.standard.set(data, forKey: Key.pickerShortcut)
            }
            NotificationCenter.default.post(name: .pickerHotKeyChanged, object: nil)
        }
    }

    /// Global hotkey that opens the Emoji picker window.
    @Published var emojiPickerShortcut: KeyboardShortcut {
        didSet {
            if let data = try? JSONEncoder().encode(emojiPickerShortcut) {
                UserDefaults.standard.set(data, forKey: Key.emojiPickerShortcut)
            }
            NotificationCenter.default.post(name: .emojiPickerHotKeyChanged, object: nil)
        }
    }

    /// Characters the user most recently picked from the Unicode
    /// picker, newest first, capped at `recentCharactersLimit`.
    /// Persisted as a plain `[String]` in UserDefaults.
    @Published var recentPickedCharacters: [String] {
        didSet {
            UserDefaults.standard.set(recentPickedCharacters, forKey: Key.recentPickedCharacters)
        }
    }

    /// Emojis the user most recently picked, newest first, capped at
    /// `recentCharactersLimit`. Kept separate from the Unicode list so
    /// the two pickers don't pollute each other's Recent section.
    @Published var recentPickedEmojis: [String] {
        didSet {
            UserDefaults.standard.set(recentPickedEmojis, forKey: Key.recentPickedEmojis)
        }
    }

    /// LRU-style record: pull the pick to the front and drop the
    /// oldest if we're past the limit.
    func recordPickedCharacter(_ character: String) {
        recentPickedCharacters = Self.promoting(character, in: recentPickedCharacters)
    }

    func recordPickedEmoji(_ emoji: String) {
        recentPickedEmojis = Self.promoting(emoji, in: recentPickedEmojis)
    }

    private static func promoting(_ pick: String, in list: [String]) -> [String] {
        var next = list
        next.removeAll { $0 == pick }
        next.insert(pick, at: 0)
        if next.count > recentCharactersLimit {
            next = Array(next.prefix(recentCharactersLimit))
        }
        return next
    }

    @Published var actionPreferences: [ActionPreference] {
        didSet {
            if let data = try? JSONEncoder().encode(actionPreferences) {
                UserDefaults.standard.set(data, forKey: Key.actionPreferences)
            }
        }
    }

    /// Kinds that have a visual separator drawn immediately after them,
    /// both in the Settings list and (between enabled actions) in the
    /// popup. Anchoring a separator to the action above it means it
    /// survives reordering and enable/disable without bookkeeping.
    @Published var separatorAfterKinds: Set<TextActionKind> {
        didSet {
            UserDefaults.standard.set(
                separatorAfterKinds.map(\.rawValue),
                forKey: Key.separatorAfterKinds
            )
        }
    }

    func toggleSeparator(afterKind kind: TextActionKind) {
        if separatorAfterKinds.contains(kind) {
            separatorAfterKinds.remove(kind)
        } else {
            separatorAfterKinds.insert(kind)
        }
    }

    /// Mirrors `SMAppService.mainApp.status`. We don't persist this to
    /// UserDefaults because the system already tracks the registration
    /// — the source of truth is SMAppService itself, queried at init.
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue, !suppressLaunchAtLoginSync else { return }
            applyLaunchAtLogin(newValue: launchAtLogin, previous: oldValue)
        }
    }

    private var suppressLaunchAtLoginSync = false

    static var defaultCenterShortcut: KeyboardShortcut {
        KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_C),
            modifierFlags: [.option]
        )
    }

    static var defaultPickerShortcut: KeyboardShortcut {
        KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_U),
            modifierFlags: [.control, .option, .command]
        )
    }

    static var defaultEmojiPickerShortcut: KeyboardShortcut {
        KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_E),
            modifierFlags: [.control, .option, .command]
        )
    }

    static var defaultActionPreferences: [ActionPreference] {
        TextActionKind.allCases.map { ActionPreference(kind: $0, enabled: $0.defaultEnabled) }
    }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Key.showDockIcon: true,
            Key.popupTheme:   PopupTheme.system.rawValue,
        ])
        self.showDockIcon = defaults.bool(forKey: Key.showDockIcon)
        let raw = defaults.string(forKey: Key.popupTheme) ?? PopupTheme.system.rawValue
        self.theme = PopupTheme(rawValue: raw) ?? .system

        if let data = defaults.data(forKey: Key.centerShortcut),
           let decoded = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
            self.centerShortcut = decoded
        } else {
            self.centerShortcut = Self.defaultCenterShortcut
        }

        if let data = defaults.data(forKey: Key.pickerShortcut),
           let decoded = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
            self.pickerShortcut = decoded
        } else {
            self.pickerShortcut = Self.defaultPickerShortcut
        }

        if let data = defaults.data(forKey: Key.emojiPickerShortcut),
           let decoded = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
            self.emojiPickerShortcut = decoded
        } else {
            self.emojiPickerShortcut = Self.defaultEmojiPickerShortcut
        }

        self.recentPickedCharacters =
            defaults.stringArray(forKey: Key.recentPickedCharacters) ?? []
        self.recentPickedEmojis =
            defaults.stringArray(forKey: Key.recentPickedEmojis) ?? []

        if let data = defaults.data(forKey: Key.actionPreferences) {
            self.actionPreferences = Self.decodePreferences(from: data)
        } else {
            self.actionPreferences = Self.defaultActionPreferences
        }

        self.separatorAfterKinds = Set(
            (defaults.stringArray(forKey: Key.separatorAfterKinds) ?? [])
                .compactMap(TextActionKind.init(rawValue:))
        )

        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Refreshes `launchAtLogin` from the system. Call this when the
    /// Settings window comes to the front so the toggle reflects any
    /// changes the user made in System Settings → Login Items while
    /// the app was running.
    func refreshLaunchAtLogin() {
        let actual = SMAppService.mainApp.status == .enabled
        if actual != launchAtLogin {
            suppressLaunchAtLoginSync = true
            launchAtLogin = actual
            suppressLaunchAtLoginSync = false
        }
    }

    private func applyLaunchAtLogin(newValue: Bool, previous: Bool) {
        let service = SMAppService.mainApp
        do {
            if newValue {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status != .notRegistered {
                    try service.unregister()
                }
            }
        } catch {
            NSLog("TextMagician: failed to update launch-at-login: \(error)")
            // Roll back the published value without re-entering didSet.
            suppressLaunchAtLoginSync = true
            launchAtLogin = previous
            suppressLaunchAtLoginSync = false
        }
    }

    /// Decodes the saved list leniently: unknown kinds are dropped and
    /// any kinds present in `TextActionKind.allCases` but missing from
    /// the saved list are appended at their `defaultEnabled` state. This
    /// way adding a built-in action in code doesn't wipe the user's
    /// existing customisations, and newly added Unicode styles arrive
    /// disabled rather than flooding the popup of an existing user.
    private static func decodePreferences(from data: Data) -> [ActionPreference] {
        struct Raw: Codable { let kind: String; var enabled: Bool }
        let raws = (try? JSONDecoder().decode([Raw].self, from: data)) ?? []
        let stored: [ActionPreference] = raws.compactMap { raw in
            guard let kind = TextActionKind(rawValue: raw.kind) else { return nil }
            return ActionPreference(kind: kind, enabled: raw.enabled)
        }
        let known = Set(stored.map(\.kind))
        let missing = TextActionKind.allCases
            .filter { !known.contains($0) }
            .map { ActionPreference(kind: $0, enabled: $0.defaultEnabled) }
        return stored + missing
    }
}
