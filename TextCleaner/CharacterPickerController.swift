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
    private weak var previousFrontmost: NSRunningApplication?
    private var ignoreResign = false

    private let columns: Int = 12

    deinit {
        if let observer = resignObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func show() {
        if panel == nil { build() }
        guard let panel = panel, let model = model else { return }

        previousFrontmost = NSWorkspace.shared.frontmostApplication
        model.selectedIndex = 0
        model.hoverIndex = nil

        applyThemeAppearance()
        positionPanel()
        NSApp.unhideWithoutActivation()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        ignoreResign = true
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
            contentRect: NSRect(origin: .zero, size: NSSize(width: 460, height: 460)),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
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
        panel.setContentSize(hosting.fittingSize)

        panel.onMoveLeft   = { [weak model] in model?.moveLeft() }
        panel.onMoveRight  = { [weak model] in model?.moveRight() }
        panel.onMoveUp     = { [weak model, weak self] in
            guard let self = self else { return }
            model?.moveUp(columns: self.columns)
        }
        panel.onMoveDown   = { [weak model, weak self] in
            guard let self = self else { return }
            model?.moveDown(columns: self.columns)
        }
        panel.onConfirm    = { [weak self] in self?.commitCurrent() }
        panel.onCancel     = { [weak self] in self?.close() }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleResignCheck()
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

    private func positionPanel() {
        guard let panel = panel, let screen = NSScreen.main else { return }
        panel.layoutIfNeeded()
        let size = panel.frame.size
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.05
        )
        panel.setFrameOrigin(origin)
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
        let target = previousFrontmost
        ignoreResign = true
        panel?.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            if let target = target,
               target.bundleIdentifier != Bundle.main.bundleIdentifier {
                if #available(macOS 14.0, *) {
                    target.activate()
                } else {
                    target.activate(options: [.activateIgnoringOtherApps])
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                PasteSimulator.paste(attributed: NSAttributedString(string: character))
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.ignoreResign = false
        }
    }
}

// MARK: - Panel

final class PickerPanel: NSPanel {
    var onMoveLeft:  (() -> Void)?
    var onMoveRight: (() -> Void)?
    var onMoveUp:    (() -> Void)?
    var onMoveDown:  (() -> Void)?
    var onConfirm:   (() -> Void)?
    var onCancel:    (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_LeftArrow:  onMoveLeft?()
        case kVK_RightArrow: onMoveRight?()
        case kVK_UpArrow:    onMoveUp?()
        case kVK_DownArrow:  onMoveDown?()
        case kVK_Return, kVK_ANSI_KeypadEnter:
            onConfirm?()
        case kVK_Escape:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }
}
