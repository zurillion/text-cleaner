import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Manages the floating popup panel, plus a sibling preview panel:
///   - Main panel hosts the action list; non-activating, key by default.
///   - Preview panel is built lazily, shown to the right when toggled.
///     Becomes key only in edit mode so its TextEditor receives input.
/// Routes keyboard events from both panels to a shared `PopupViewModel`.
final class PopupWindowController {
    private var mainPanel: PopupPanel?
    private var previewPanel: PreviewPanel?
    private var model: PopupViewModel?

    private var resignObservers: [NSObjectProtocol] = []
    private var editingKeyMonitor: Any?
    private weak var previousFrontmost: NSRunningApplication?

    // Suppresses the resign-key auto-close during programmatic key handoffs
    // between the main and preview panels.
    private var ignoreResign = false

    private let previewGap: CGFloat = 12

    deinit {
        for observer in resignObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        removeEditingKeyMonitor()
    }

    // MARK: - Public

    func show() {
        if mainPanel == nil { build() }
        guard let mainPanel = mainPanel, let model = model else { return }

        previousFrontmost = NSWorkspace.shared.frontmostApplication

        model.sourceAttributed = PasteSimulator.readSourceAttributed()
        model.selectedIndex = 0
        model.showsPreview = false
        model.isEditing = false
        model.editedAttributed = NSAttributedString()

        previewPanel?.orderOut(nil)
        applyThemeAppearance()

        positionPanels()
        mainPanel.makeKeyAndOrderFront(nil)
    }

    private func applyThemeAppearance() {
        let appearance = AppSettings.shared.theme.nsAppearance
        mainPanel?.appearance = appearance
        previewPanel?.appearance = appearance
    }

    func close() {
        ignoreResign = true
        previewPanel?.orderOut(nil)
        mainPanel?.orderOut(nil)
        removeEditingKeyMonitor()
        model?.isEditing = false
        model?.showsPreview = false
        DispatchQueue.main.async { [weak self] in
            self?.ignoreResign = false
        }
    }

    // MARK: - Build

    private func build() {
        let actions = TextAction.all
        let model = PopupViewModel(actions: actions)
        self.model = model

        let popupView = PopupView(
            model: model,
            settings: AppSettings.shared
        ) { [weak self] action in
            self?.commitAction(action)
        }
        let mainPanel = makePanel(
            style: PopupPanel.self,
            initialSize: NSSize(width: 340, height: 320),
            rootView: popupView
        )
        mainPanel.onMoveUp     = { [weak model] in model?.moveUp() }
        mainPanel.onMoveDown   = { [weak model] in model?.moveDown() }
        mainPanel.onConfirm    = { [weak self] in self?.confirmSelection() }
        mainPanel.onCancel     = { [weak self] in self?.handleEscape() }
        mainPanel.onNumber     = { [weak self, weak model] num in
            guard let model = model, num >= 1, num <= model.actions.count else { return }
            self?.commitAction(model.actions[num - 1])
        }
        mainPanel.onTogglePreview = { [weak self] in self?.togglePreview() }
        mainPanel.onBeginEdit     = { [weak self] in self?.beginEdit() }

        registerResignObserver(for: mainPanel)
        self.mainPanel = mainPanel
    }

    private func registerResignObserver(for window: NSWindow) {
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleResignCheck()
        }
        resignObservers.append(observer)
    }

    /// Called when any of our panels resigns key. We defer the check by one
    /// runloop so that if focus is moving from main → preview (or vice versa)
    /// the new key window is in place before we inspect.
    private func scheduleResignCheck() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.ignoreResign else { return }
            let key = NSApp.keyWindow
            if key !== self.mainPanel && key !== self.previewPanel {
                self.close()
            }
        }
    }

    private func buildPreviewPanelIfNeeded() -> PreviewPanel? {
        if let previewPanel = previewPanel { return previewPanel }
        guard let model = model else { return nil }

        let previewView = PreviewView(
            model: model,
            settings: AppSettings.shared,
            onCancel: { [weak self] in self?.cancelEdit() },
            onConfirm: { [weak self] in self?.confirmEdit() }
        )
        let panel = makePanel(
            style: PreviewPanel.self,
            initialSize: NSSize(width: 400, height: 280),
            rootView: previewView
        )
        registerResignObserver(for: panel)
        self.previewPanel = panel
        return panel
    }

    // MARK: - Panel factory

    private func makePanel<P: NSPanel, V: View>(
        style: P.Type,
        initialSize: NSSize,
        rootView: V
    ) -> P {
        let panel = P(
            contentRect: NSRect(origin: .zero, size: initialSize),
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

        let hosting = NSHostingView(rootView: rootView)
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
        return panel
    }

    // MARK: - Positioning

    private func positionPanels() {
        guard let mainPanel = mainPanel, let model = model,
              let screen = NSScreen.main else { return }

        mainPanel.layoutIfNeeded()
        let mainSize = mainPanel.frame.size
        let visible = screen.visibleFrame

        let showingPreview = model.showsPreview
        let previewSize = previewPanel?.frame.size ?? .zero

        let totalWidth = showingPreview
            ? mainSize.width + previewGap + previewSize.width
            : mainSize.width

        var leftEdge = visible.midX - totalWidth / 2
        leftEdge = max(visible.minX + 8, min(leftEdge, visible.maxX - totalWidth - 8))

        let topY = visible.midY + mainSize.height / 2 + visible.height * 0.10
        let mainOrigin = NSPoint(
            x: leftEdge,
            y: topY - mainSize.height
        )
        mainPanel.setFrameOrigin(mainOrigin)

        if showingPreview, let previewPanel = previewPanel {
            previewPanel.layoutIfNeeded()
            let pSize = previewPanel.frame.size
            let previewOrigin = NSPoint(
                x: mainOrigin.x + mainSize.width + previewGap,
                y: mainOrigin.y + mainSize.height - pSize.height
            )
            previewPanel.setFrameOrigin(previewOrigin)
        }
    }

    // MARK: - Preview / edit toggles

    private func togglePreview() {
        guard let model = model else { return }
        if model.isEditing { return }
        model.showsPreview.toggle()
        if model.showsPreview {
            showPreview()
        } else {
            hidePreview()
        }
    }

    private func showPreview() {
        guard let panel = buildPreviewPanelIfNeeded() else { return }
        applyThemeAppearance()
        positionPanels()
        ignoreResign = true
        panel.orderFront(nil)
        DispatchQueue.main.async { [weak self] in
            self?.ignoreResign = false
        }
    }

    private func hidePreview() {
        ignoreResign = true
        previewPanel?.orderOut(nil)
        mainPanel?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            self?.ignoreResign = false
        }
    }

    private func beginEdit() {
        guard let model = model else { return }
        if !model.showsPreview {
            model.showsPreview = true
            _ = buildPreviewPanelIfNeeded()
        }
        applyThemeAppearance()
        model.editedAttributed = model.currentPreviewAttributed
        model.isEditing = true
        positionPanels()

        ignoreResign = true
        previewPanel?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            self?.ignoreResign = false
        }
        installEditingKeyMonitor()
    }

    private func cancelEdit() {
        guard let model = model else { return }
        removeEditingKeyMonitor()
        model.isEditing = false
        model.editedAttributed = NSAttributedString()
        // Per spec: Annulla / Esc closes the preview entirely.
        model.showsPreview = false
        ignoreResign = true
        previewPanel?.orderOut(nil)
        mainPanel?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            self?.ignoreResign = false
        }
    }

    private func confirmEdit() {
        guard let model = model else { return }
        let attributed = model.editedAttributed
        removeEditingKeyMonitor()
        pasteAndClose(attributed: attributed)
    }

    private func confirmSelection() {
        guard let model = model else { return }
        guard model.actions.indices.contains(model.selectedIndex) else { return }
        commitAction(model.actions[model.selectedIndex])
    }

    private func commitAction(_ action: TextAction) {
        guard let model = model else { return }
        let attributed = action.transform(model.sourceAttributed)
        pasteAndClose(attributed: attributed)
    }

    private func handleEscape() {
        guard let model = model else { return }
        if model.showsPreview {
            cancelEdit()
        } else {
            close()
        }
    }

    // MARK: - Editing key monitor

    private func installEditingKeyMonitor() {
        removeEditingKeyMonitor()
        editingKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  let model = self.model,
                  model.isEditing,
                  event.window === self.previewPanel
            else { return event }

            // Toggle rich-text attributes on ⌘B / ⌘I / ⌘U. AppKit doesn't
            // expose toggle selectors for bold / italic, so we operate on
            // the text view's storage directly via RichTextActions.
            if event.modifierFlags.contains(.command),
               event.modifierFlags.intersection([.option, .control]).isEmpty,
               let textView = self.findRichTextView() {
                switch Int(event.keyCode) {
                case kVK_ANSI_B:
                    RichTextActions.toggleBold(in: textView)
                    return nil
                case kVK_ANSI_I:
                    RichTextActions.toggleItalic(in: textView)
                    return nil
                case kVK_ANSI_U:
                    RichTextActions.toggleUnderline(in: textView)
                    return nil
                default:
                    break
                }
            }

            switch Int(event.keyCode) {
            case kVK_Return, kVK_ANSI_KeypadEnter:
                if event.modifierFlags.contains(.shift) {
                    DispatchQueue.main.async { self.confirmEdit() }
                    return nil
                }
                return event
            case kVK_Escape:
                DispatchQueue.main.async { self.cancelEdit() }
                return nil
            default:
                return event
            }
        }
    }

    private func removeEditingKeyMonitor() {
        if let monitor = editingKeyMonitor {
            NSEvent.removeMonitor(monitor)
            editingKeyMonitor = nil
        }
    }

    private func findRichTextView() -> NSTextView? {
        guard let root = previewPanel?.contentView else { return nil }
        return firstTextView(in: root)
    }

    private func firstTextView(in view: NSView) -> NSTextView? {
        if let tv = view as? NSTextView { return tv }
        for sub in view.subviews {
            if let found = firstTextView(in: sub) { return found }
        }
        return nil
    }

    // MARK: - Paste

    private func pasteAndClose(attributed: NSAttributedString) {
        let target = previousFrontmost
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if let target = target,
               target.bundleIdentifier != Bundle.main.bundleIdentifier {
                if #available(macOS 14.0, *) {
                    target.activate()
                } else {
                    target.activate(options: [.activateIgnoringOtherApps])
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                PasteSimulator.paste(attributed: attributed)
            }
        }
    }
}

// MARK: - Panels

final class PopupPanel: NSPanel {
    var onMoveUp:        (() -> Void)?
    var onMoveDown:      (() -> Void)?
    var onConfirm:       (() -> Void)?
    var onCancel:        (() -> Void)?
    var onNumber:        ((Int) -> Void)?
    var onTogglePreview: (() -> Void)?
    var onBeginEdit:     (() -> Void)?

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
        case kVK_Space:
            onTogglePreview?()
        case kVK_Tab:
            onBeginEdit?()
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

final class PreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
