import AppKit
import Carbon.HIToolbox
import Combine
import Foundation
import ServiceManagement

extension Notification.Name {
    static let dockIconPreferenceChanged = Notification.Name("TextCleaner.dockIconChanged")
    static let pickerHotKeyChanged = Notification.Name("TextCleaner.pickerHotKeyChanged")
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
        static let recentPickedCharacters    = "TextCleaner.recentPickedCharacters"
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

    /// Characters the user most recently picked, newest first, capped
    /// at `recentCharactersLimit`. Persisted as a plain `[String]` in
    /// UserDefaults.
    @Published var recentPickedCharacters: [String] {
        didSet {
            UserDefaults.standard.set(recentPickedCharacters, forKey: Key.recentPickedCharacters)
        }
    }

    /// LRU-style record: pull the pick to the front and drop the
    /// oldest if we're past the limit.
    func recordPickedCharacter(_ character: String) {
        var list = recentPickedCharacters
        list.removeAll { $0 == character }
        list.insert(character, at: 0)
        if list.count > Self.recentCharactersLimit {
            list = Array(list.prefix(Self.recentCharactersLimit))
        }
        recentPickedCharacters = list
    }

    @Published var actionPreferences: [ActionPreference] {
        didSet {
            if let data = try? JSONEncoder().encode(actionPreferences) {
                UserDefaults.standard.set(data, forKey: Key.actionPreferences)
            }
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

    static var defaultActionPreferences: [ActionPreference] {
        TextActionKind.allCases.map { ActionPreference(kind: $0, enabled: true) }
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

        self.recentPickedCharacters =
            defaults.stringArray(forKey: Key.recentPickedCharacters) ?? []

        if let data = defaults.data(forKey: Key.actionPreferences) {
            self.actionPreferences = Self.decodePreferences(from: data)
        } else {
            self.actionPreferences = Self.defaultActionPreferences
        }

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
    /// the saved list are appended (enabled). This way adding or
    /// removing a built-in action in code doesn't wipe the user's
    /// existing customisations.
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
            .map { ActionPreference(kind: $0, enabled: true) }
        return stored + missing
    }
}
