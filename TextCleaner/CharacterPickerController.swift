import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Owns the floating panel for a glyph picker (Unicode characters or
/// emojis — same UI, different catalog). Mirrors the pattern established
/// by `PopupWindowController`: a borderless non-activating NSPanel
/// hosting a SwiftUI view, with global resign-key auto-close and a paste
/// handoff that reactivates the previous frontmost app.
final class CharacterPickerController {
    private let catalog: [CharacterSection]
    private let loadRecents: () -> [String]
    private let recordPick: (String) -> Void

    private var panel: PickerPanel?
    private var model: CharacterPickerModel?
    private var resignObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private var globalClickMonitor: Any?
    private weak var previousFrontmost: NSRunningApplication?
    private var ignoreResign = false

    /// Pinned: the window stays open after a pick so several glyphs can
    /// be inserted in a row. While pinned, losing focus does nothing and
    /// the panel yields keyboard focus to the frontmost app.
    private var isPinned = false

    /// Absolute drag references, captured on drag-begin so the math
    /// doesn't drift as the panel moves under the cursor.
    private var dragStartScreenLocation: NSPoint?
    private var dragStartOrigin: NSPoint?
    /// Once the user drags the window we stop re-centering it after a
    /// resize — the drag is an explicit "leave it here".
    private var hasBeenDragged = false

    private let defaultSize = NSSize(width: 460, height: 460)

    /// - Parameters:
    ///   - catalog: the static sections rendered when the search field
    ///     is empty (and the universe the search filter runs over).
    ///   - loadRecents: closure that fetches the picker's persisted
    ///     recent picks. Called on each `show()` so changes from other
    ///     opens (or app launches) show up.
    ///   - recordPick: closure that pushes the just-committed glyph into
    ///     the recent list. Different pickers use different storage so
    ///     emoji picks don't end up in the Unicode picker's Recent and
    ///     vice versa.
    init(
        catalog: [CharacterSection],
        loadRecents: @escaping () -> [String],
        recordPick: @escaping (String) -> Void
    ) {
        self.catalog = catalog
        self.loadRecents = loadRecents
        self.recordPick = recordPick
    }

    deinit {
        for observer in [resignObserver, resizeObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
        removeKeyMonitor()
        removeGlobalClickMonitor()
    }

    /// Opens the picker, or closes it if it's already on screen. Bound to
    /// the global hotkey so a second press dismisses — the only way to
    /// dismiss while pinned (where outside clicks are intentionally
    /// ignored).
    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil { build() }
        guard let panel = panel, let model = model else { return }

        previousFrontmost = NSWorkspace.shared.frontmostApplication
        model.selectedIndex = 0
        model.hoverIndex = nil
        model.query = ""
        // Every fresh open starts unpinned, centered, key.
        isPinned = false
        model.isPinned = false
        hasBeenDragged = false
        panel.becomesKeyOnlyIfNeeded = false
        // Refresh recents from persisted settings each time the picker
        // opens — captures any picks made via earlier opens of this
        // app session and survives restarts.
        model.recents = loadRecents().map {
            CharacterCatalog.entry(for: $0, in: catalog)
        }

        applyThemeAppearance()
        recenter()
        NSApp.unhideWithoutActivation()
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        installGlobalClickMonitor()
    }

    /// - Parameter reactivating: when true, focus returns to the app the
    ///   picker was opened from (Esc, hotkey, commit). When the user
    ///   dismissed by clicking *into* another app, pass false so that
    ///   clicked app keeps focus instead of being yanked back.
    func close(reactivating: Bool = true) {
        guard panel?.isVisible == true else { return }
        ignoreResign = true
        removeKeyMonitor()
        removeGlobalClickMonitor()
        panel?.orderOut(nil)
        // Leave the panel ready for a clean, unpinned next open.
        isPinned = false
        model?.isPinned = false
        panel?.becomesKeyOnlyIfNeeded = false
        if reactivating { reactivatePreviousApp() }
        DispatchQueue.main.async { [weak self] in
            self?.ignoreResign = false
        }
    }

    private func reactivatePreviousApp() {
        guard let target = previousFrontmost,
              target.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        if #available(macOS 14.0, *) {
            target.activate()
        } else {
            target.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func applyThemeAppearance() {
        panel?.appearance = AppSettings.shared.theme.nsAppearance
    }

    // MARK: - Build

    private func build() {
        let model = CharacterPickerModel(sections: catalog)
        self.model = model

        let view = CharacterPickerView(
            model: model,
            settings: AppSettings.shared,
            onSelect: { [weak self] character in
                self?.commit(character: character)
            },
            onTogglePin: { [weak self] in self?.togglePin() },
            onDragBegan: { [weak self] loc in self?.handleDragBegan(at: loc) },
            onDragChanged: { [weak self] loc in self?.handleDragChanged(at: loc) },
            onDragEnded: { [weak self] in self?.handleDragEnded() }
        )

        let panel = PickerPanel(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.minSize = NSSize(width: 320, height: 260)

        let hosting = FirstMouseHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        panel.contentView = container
        panel.setContentSize(defaultSize)

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleResignCheck()
        }
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // A window the user has dragged keeps its position; only an
            // untouched, still-centered window re-centers after resize.
            guard let self = self, !self.hasBeenDragged else { return }
            self.recenter(animated: true)
        }

        self.panel = panel
    }

    private func scheduleResignCheck() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.ignoreResign else { return }
            // Pinned windows are meant to lose focus and keep floating, so
            // the user can type in the target app between picks.
            if self.isPinned { return }
            let key = NSApp.keyWindow
            if key === self.panel { return }
            // A resign means the user moved to another window/app; leave
            // focus there rather than reactivating where we opened from.
            self.close(reactivating: false)
        }
    }

    // MARK: - Drag

    private func handleDragBegan(at screenLocation: NSPoint) {
        dragStartScreenLocation = screenLocation
        dragStartOrigin = panel?.frame.origin
    }

    private func handleDragChanged(at screenLocation: NSPoint) {
        guard let start = dragStartScreenLocation,
              let origin = dragStartOrigin else { return }
        let dx = screenLocation.x - start.x
        let dy = screenLocation.y - start.y
        panel?.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
    }

    private func handleDragEnded() {
        if dragStartScreenLocation != nil { hasBeenDragged = true }
        dragStartScreenLocation = nil
        dragStartOrigin = nil
    }

    // MARK: - Pin

    private func togglePin() {
        guard let panel = panel else { return }
        isPinned.toggle()
        model?.isPinned = isPinned
        if isPinned {
            // Hand keyboard focus back to the frontmost app so the user can
            // keep typing there; with becomesKeyOnlyIfNeeded a glyph click
            // won't steal it back, so the synthetic ⌘V lands in that app.
            panel.becomesKeyOnlyIfNeeded = true
            reactivatePreviousApp()
        } else {
            // Reclaim keyboard focus for arrow / search / Esc navigation.
            panel.becomesKeyOnlyIfNeeded = false
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Click-outside monitor
    //
    // A non-activating floating panel doesn't reliably get a resign-key
    // notification for every outside click (the previously-active app can
    // stay active while our panel is merely key-in-app). A global mouse
    // monitor sees clicks destined for other apps directly, so "click
    // outside = dismiss" works regardless of the key-window dance. Mouse
    // global monitors need no extra entitlement.

    private func installGlobalClickMonitor() {
        removeGlobalClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self = self else { return }
            // Pinned windows survive outside clicks on purpose.
            if self.isPinned { return }
            // The click is landing in another app; let that app keep focus.
            self.close(reactivating: false)
        }
    }

    private func removeGlobalClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    // MARK: - Positioning

    private func recenter(animated: Bool = false) {
        guard let panel = panel, let screen = NSScreen.main else { return }
        panel.layoutIfNeeded()
        let size = panel.frame.size
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.05
        )
        panel.setFrame(
            NSRect(origin: origin, size: size),
            display: true,
            animate: animated
        )
    }

    // MARK: - Key monitor
    //
    // The picker's search field captures keyDown via SwiftUI's TextField,
    // so plain key handling on the panel wouldn't see arrows, Return or
    // Escape while the field is focused. A local NSEvent monitor sees
    // events before they reach the focused responder, so we can route
    // navigation keys to the model regardless of focus and still let
    // letters fall through to the field for the actual filter typing.

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  event.window === self.panel,
                  let model = self.model
            else { return event }

            switch Int(event.keyCode) {
            case kVK_LeftArrow:
                model.moveLeft();  return nil
            case kVK_RightArrow:
                model.moveRight(); return nil
            case kVK_UpArrow:
                model.moveUp();    return nil
            case kVK_DownArrow:
                model.moveDown();  return nil
            case kVK_Return, kVK_ANSI_KeypadEnter:
                self.commitCurrent()
                return nil
            case kVK_Escape:
                // If the user typed a query first, the natural mental
                // model is "Esc clears the search"; only the second Esc
                // closes the picker.
                if !(model.query.isEmpty) {
                    model.query = ""
                    return nil
                }
                self.close()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Commit

    private func commitCurrent() {
        guard let entry = model?.selectedEntry else {
            close()
            return
        }
        commit(character: entry.character)
    }

    private func commit(character: String) {
        recordPick(character)
        if isPinned {
            commitPinned(character: character)
        } else {
            // close() orders the panel out and reactivates previousFrontmost
            // synchronously; the small delay before paste lets that handoff
            // settle so the synthetic ⌘V lands in the target rather than
            // our app.
            close()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                PasteSimulator.paste(attributed: NSAttributedString(string: character))
            }
        }
    }

    /// Pinned pick: insert without closing. The panel is a non-activating
    /// palette, so normally it isn't key and the frontmost app receives
    /// the ⌘V directly — meaning the glyph lands wherever the user is
    /// currently typing, even if they've switched apps. The only time the
    /// panel holds key focus is right after using the search field; in
    /// that case hand focus back so the paste doesn't land in our panel.
    private func commitPinned(character: String) {
        if panel?.isKeyWindow == true {
            reactivatePreviousApp()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            PasteSimulator.paste(attributed: NSAttributedString(string: character))
        }
    }
}

// MARK: - Panel

final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// NSHostingView that delivers the first click even when its window isn't
/// key. A pinned picker is a non-key floating palette, so without this the
/// first glyph click would only "focus" the window and be swallowed,
/// forcing a second click to actually insert.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
