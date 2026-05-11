import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Manages the floating popup panel: builds an NSPanel that doesn't steal
/// activation from the front app, hosts the SwiftUI popup view, and routes
/// keyboard events to the view model.
final class PopupWindowController {
    private var panel: PopupPanel?
    private var model: PopupViewModel?
    private var resignObserver: NSObjectProtocol?

    deinit {
        if let observer = resignObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func show() {
        if panel == nil { build() }
        guard let panel = panel, let model = model else { return }
        model.selectedIndex = 0
        positionPanel(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func build() {
        let actions = TextAction.all
        let model = PopupViewModel(actions: actions)
        self.model = model

        let view = PopupView(model: model) { [weak self] action in
            self?.commit(action: action)
        }
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let panel = PopupPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 280),
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
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

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

        panel.onMoveUp     = { [weak model] in model?.moveUp() }
        panel.onMoveDown   = { [weak model] in model?.moveDown() }
        panel.onConfirm    = { [weak self, weak model] in
            guard let model = model else { return }
            let idx = max(0, min(model.selectedIndex, model.actions.count - 1))
            self?.commit(action: model.actions[idx])
        }
        panel.onCancel     = { [weak self] in self?.close() }
        panel.onNumber     = { [weak self, weak model] num in
            guard let model = model, num >= 1, num <= model.actions.count else { return }
            self?.commit(action: model.actions[num - 1])
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.close()
        }

        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        panel.layoutIfNeeded()
        let size = panel.frame.size
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.15
        )
        panel.setFrameOrigin(origin)
    }

    private func commit(action: TextAction) {
        close()
        // Give the front app a moment to regain key focus before pasting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            PasteSimulator.run(action: action)
        }
    }
}

final class PopupPanel: NSPanel {
    var onMoveUp:   (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onConfirm:  (() -> Void)?
    var onCancel:   (() -> Void)?
    var onNumber:   ((Int) -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_UpArrow:
            onMoveUp?()
        case kVK_DownArrow:
            onMoveDown?()
        case kVK_Return, kVK_ANSI_KeypadEnter:
            onConfirm?()
        case kVK_Escape:
            onCancel?()
        default:
            if let chars = event.charactersIgnoringModifiers,
               chars.count == 1,
               let digit = Int(chars),
               (1...9).contains(digit) {
                onNumber?(digit)
            } else {
                super.keyDown(with: event)
            }
        }
    }
}
