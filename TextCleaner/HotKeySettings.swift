import AppKit
import Carbon.HIToolbox
import Foundation

extension Notification.Name {
    static let hotKeyChanged = Notification.Name("TextCleaner.hotKeyChanged")
}

enum HotKeySettings {
    private static let storageKey = "TextCleaner.hotKey"

    static var defaultShortcut: KeyboardShortcut {
        KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_V),
            modifierFlags: [.control, .option, .command]
        )
    }

    static var current: KeyboardShortcut {
        get {
            if let data = UserDefaults.standard.data(forKey: storageKey),
               let decoded = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
                return decoded
            }
            return defaultShortcut
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
            NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
        }
    }
}
