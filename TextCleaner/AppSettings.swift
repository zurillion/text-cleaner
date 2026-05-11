import Foundation
import Combine

extension Notification.Name {
    static let dockIconPreferenceChanged = Notification.Name("TextCleaner.dockIconChanged")
}

/// Observable store for user preferences other than the hotkey
/// (which lives in `HotKeySettings` because it predates this store).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let showDockIcon = "TextCleaner.showDockIcon"
        static let popupTheme   = "TextCleaner.popupTheme"
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

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Key.showDockIcon: true,
            Key.popupTheme:   PopupTheme.system.rawValue,
        ])
        self.showDockIcon = defaults.bool(forKey: Key.showDockIcon)
        let raw = defaults.string(forKey: Key.popupTheme) ?? PopupTheme.system.rawValue
        self.theme = PopupTheme(rawValue: raw) ?? .system
    }
}
