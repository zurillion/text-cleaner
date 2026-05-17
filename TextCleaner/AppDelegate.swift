import AppKit
import ApplicationServices
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyManager: HotKeyManager?
    private var popupController: PopupWindowController?
    private var pickerController: CharacterPickerController?
    private var settingsController: SettingsWindowController?
    private var statusItem: NSStatusItem?

    func applicationWillFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()
        NSApp.applicationIconImage = AppIcon.make()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        rerouteAppMenuSettingsItem()
        promptForAccessibilityIfNeeded()

        hotKeyManager = HotKeyManager()
        registerHotKeys()

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(hotKeyChanged),
                       name: .hotKeyChanged, object: nil)
        nc.addObserver(self, selector: #selector(pickerHotKeyChanged),
                       name: .pickerHotKeyChanged, object: nil)
        nc.addObserver(self, selector: #selector(dockIconPreferenceChanged),
                       name: .dockIconPreferenceChanged, object: nil)
    }

    private func registerHotKeys() {
        hotKeyManager?.register(name: "popup", shortcut: HotKeySettings.current) { [weak self] in
            self?.showPopup()
        }
        hotKeyManager?.register(name: "picker", shortcut: AppSettings.shared.pickerShortcut) { [weak self] in
            self?.showPicker()
        }
    }

    // MARK: - Dock interaction

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows: Bool
    ) -> Bool {
        if !hasVisibleWindows {
            openSettings()
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        buildActionMenu(includeQuit: false)
    }

    // MARK: - Notifications

    @objc private func hotKeyChanged() {
        hotKeyManager?.register(name: "popup", shortcut: HotKeySettings.current) { [weak self] in
            self?.showPopup()
        }
    }

    @objc private func pickerHotKeyChanged() {
        hotKeyManager?.register(name: "picker", shortcut: AppSettings.shared.pickerShortcut) { [weak self] in
            self?.showPicker()
        }
    }

    @objc private func dockIconPreferenceChanged() {
        applyActivationPolicy()
    }

    // MARK: - Helpers

    private func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy =
            AppSettings.shared.showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
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

    /// Triggers macOS's native Accessibility prompt if the permission is
    /// missing. Posting CGEvents to other apps silently fails without it.
    private func promptForAccessibilityIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "wand.and.sparkles",
            accessibilityDescription: "Text Cleaner"
        )
        item.menu = buildActionMenu(includeQuit: true)
        statusItem = item
    }

    private func buildActionMenu(includeQuit: Bool) -> NSMenu {
        let menu = NSMenu()
        let show = menu.addItem(
            withTitle: "Show Cleaner…",
            action: #selector(showPopupFromMenu),
            keyEquivalent: ""
        )
        show.target = self

        menu.addItem(.separator())

        let settings = menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self

        if includeQuit {
            menu.addItem(.separator())
            menu.addItem(
                withTitle: "Quit Text Cleaner",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        }
        return menu
    }

    // MARK: - Actions

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

    private func showPicker() {
        if pickerController == nil {
            pickerController = CharacterPickerController()
        }
        pickerController?.show()
    }
}
