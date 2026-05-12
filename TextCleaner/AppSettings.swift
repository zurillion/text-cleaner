import AppKit
import Carbon.HIToolbox
import Combine
import Foundation

extension Notification.Name {
    static let dockIconPreferenceChanged = Notification.Name("TextCleaner.dockIconChanged")
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
        static let showDockIcon       = "TextCleaner.showDockIcon"
        static let popupTheme         = "TextCleaner.popupTheme"
        static let centerShortcut     = "TextCleaner.centerShortcut"
        static let actionPreferences  = "TextCleaner.actionPreferences"
    }

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

    @Published var actionPreferences: [ActionPreference] {
        didSet {
            if let data = try? JSONEncoder().encode(actionPreferences) {
                UserDefaults.standard.set(data, forKey: Key.actionPreferences)
            }
        }
    }

    static var defaultCenterShortcut: KeyboardShortcut {
        KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_C),
            modifierFlags: [.option]
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

        if let data = defaults.data(forKey: Key.actionPreferences) {
            self.actionPreferences = Self.decodePreferences(from: data)
        } else {
            self.actionPreferences = Self.defaultActionPreferences
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
