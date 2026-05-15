import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Owns the floating panel for the Unicode picker. Mirrors the pattern
/// established by `PopupWindowController`: a borderless non-activating
/// NSPanel hosting a SwiftUI view, with global resign-key auto-close
/// and a paste handoff that reactivates the previous frontmost app.
final class CharacterPickerController {
    private var panel: PickerPanel?
    private var model: CharacterPickerModel?
    private var resignObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private weak var previousFrontmost: NSRunningApplication?
    private var ignoreResign = false

    private let defaultSize = NSSize(width: 460, height: 460)

    deinit {
        for observer in [resignObserver, resizeObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
        removeKeyMonitor()
    }

    func show() {
        if panel == nil { build() }
        guard let panel = panel, let model = model else { return }

        previousFrontmost = NSWorkspace.shared.frontmostApplication
        model.selectedIndex = 0
        model.hoverIndex = nil
        model.query = ""

        applyThemeAppearance()
        recenter()
        NSApp.unhideWithoutActivation()
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func close() {
        ignoreResign = true
        removeKeyMonitor()
        panel?.orderOut(nil)
        if let target = previousFrontmost,
           target.bundleIdentifier != Bundle.main.bundleIdentifier {
            if #available(macOS 14.0, *) {
                target.activate()
            } else {
                target.activate(options: [.activateIgnoringOtherApps])
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.ignoreResign = false
        }
    }

    private func applyThemeAppearance() {
        panel?.appearance = AppSettings.shared.theme.nsAppearance
    }

    // MARK: - Build

    private func build() {
        let model = CharacterPickerModel()
        self.model = model

        let view = CharacterPickerView(
            model: model,
            settings: AppSettings.shared,
            onSelect: { [weak self] character in
                self?.commit(character: character)
            }
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

        let hosting = NSHostingView(rootView: view)
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
            self?.recenter(animated: true)
        }

        self.panel = panel
    }

    private func scheduleResignCheck() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.ignoreResign else { return }
            let key = NSApp.keyWindow
            if key === self.panel { return }
            self.close()
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

// MARK: - Panel

final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
