import AppKit
import SwiftUI

/// Hosts the SettingsView in a regular NSWindow. We bypass SwiftUI's
/// `Settings` scene because it interacts poorly with apps that toggle
/// between `.regular` and `.accessory` activation policies.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let hosting = NSHostingController(
            rootView: SettingsView().environmentObject(AppSettings.shared)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "TextMagic Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 500, height: 560))
        window.center()
        self.init(window: window)
        window.delegate = self
    }

    func show() {
        guard let window = window else { return }
        // The Launch-at-login state lives in the system, not in our
        // UserDefaults — re-read it now so the toggle reflects any
        // change the user made in System Settings → Login Items while
        // the app was running.
        AppSettings.shared.refreshLaunchAtLogin()
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
