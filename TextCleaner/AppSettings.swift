import AppKit
import Carbon.HIToolbox
import Combine
import Foundation

extension Notification.Name {
    static let dockIconPreferenceChanged = Notification.Name("TextCleaner.dockIconChanged")
}

/// Observable store for user preferences other than the global hotkey
/// (which lives in `HotKeySettings` because it predates this store).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let showDockIcon   = "TextCleaner.showDockIcon"
        static let popupTheme     = "TextCleaner.popupTheme"
        static let centerShortcut = "TextCleaner.centerShortcut"
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

    static var defaultCenterShortcut: KeyboardShortcut {
        KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_C),
            modifierFlags: [.option]
        )
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
    }
}
