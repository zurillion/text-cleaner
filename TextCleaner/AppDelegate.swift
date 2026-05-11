import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyManager: HotKeyManager?
    private var popupController: PopupWindowController?
    private var settingsController: SettingsWindowController?
    private var statusItem: NSStatusItem?

    func applicationWillFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        rerouteAppMenuSettingsItem()

        hotKeyManager = HotKeyManager { [weak self] in
            self?.showPopup()
        }
        hotKeyManager?.register(with: HotKeySettings.current)

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(hotKeyChanged),
                       name: .hotKeyChanged, object: nil)
        nc.addObserver(self, selector: #selector(dockIconPreferenceChanged),
                       name: .dockIconPreferenceChanged, object: nil)
    }

    /// SwiftUI's `Settings` scene injects a "Settings…" item into the app
    /// menu. We use a custom settings window instead, so we redirect that
    /// menu item (and ⌘,) to our handler.
    private func rerouteAppMenuSettingsItem() {
        guard let appMenu = NSApp.mainMenu?.item(at: 0)?.submenu else { return }
        for item in appMenu.items {
            guard let selector = item.action else { continue }
            let name = NSStringFromSelector(selector)
            if name == "showSettingsWindow:" || name == "showPreferencesWindow:" {
                item.target = self
                item.action = #selector(openSettings)
                item.keyEquivalent = ","
                item.keyEquivalentModifierMask = .command
            }
        }
    }

    @objc private func hotKeyChanged() {
        hotKeyManager?.register(with: HotKeySettings.current)
    }

    @objc private func dockIconPreferenceChanged() {
        applyActivationPolicy()
    }

    private func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy =
            AppSettings.shared.showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "wand.and.sparkles",
            accessibilityDescription: "Text Cleaner"
        )
        let menu = NSMenu()
        let showItem = menu.addItem(
            withTitle: "Show Cleaner…",
            action: #selector(showPopupFromMenu),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(.separator())
        let settingsItem = menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Text Cleaner",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
        statusItem = item
    }

    @objc private func showPopupFromMenu() {
        showPopup()
    }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
        }
        settingsController?.show()
    }

    private func showPopup() {
        if popupController == nil {
            popupController = PopupWindowController()
        }
        popupController?.show()
    }
}
