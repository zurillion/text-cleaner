import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyManager: HotKeyManager?
    private var popupController: PopupWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        hotKeyManager = HotKeyManager { [weak self] in
            self?.showPopup()
        }
        hotKeyManager?.register(with: HotKeySettings.current)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotKeyChanged),
            name: .hotKeyChanged,
            object: nil
        )
    }

    @objc private func hotKeyChanged() {
        hotKeyManager?.register(with: HotKeySettings.current)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "wand.and.sparkles",
            accessibilityDescription: "Text Cleaner"
        )
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Show Cleaner…",
            action: #selector(showPopupFromMenu),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self
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
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    private func showPopup() {
        if popupController == nil {
            popupController = PopupWindowController()
        }
        popupController?.show()
    }
}
