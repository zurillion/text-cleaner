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

    // Drag state — set when the user starts moving the main popup by its
    // title bar; we keep absolute references so the math doesn't drift as
    // the panels themselves move during the drag.
    private var dragStartScreenLocation: NSPoint?
    private var dragStartMainOrigin: NSPoint?
    private var dragStartPreviewOrigin: NSPoint?

    // Suppresses the resign-key auto-close during programmatic key handoffs
    // between the main and preview panels.
    private var ignoreResign = false

    private let previewGap: CGFloat = 12
    private let defaultPreviewSize = NSSize(width: 420, height: 320)

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
        // Forget any user resize from the previous session.
        previewPanel?.setContentSize(defaultPreviewSize)
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
            settings: AppSettings.shared,
            onSelect: { [weak self] action in self?.commitAction(action) },
            onDragBegan: { [weak self] loc in self?.handleMainDragBegan(at: loc) },
            onDragChanged: { [weak self] loc in self?.handleMainDragChanged(at: loc) },
            onDragEnded: { [weak self] in self?.handleMainDragEnded() }
        )
        let mainPanel = makePanel(
            style: PopupPanel.self,
            initialSize: NSSize(width: 340, height: 320),
            rootView: popupView
        )
        // Don't let a click on the title-bar drag handle steal key from
        // the preview while the user is editing. The panel still becomes
        // key explicitly via makeKeyAndOrderFront on show()/hidePreview().
        mainPanel.becomesKeyOnlyIfNeeded = true
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
        mainPanel.customShortcut  = { [weak self] event in
            guard let self = self,
                  AppSettings.shared.centerShortcut.matches(event)
            else { return false }
            self.recenterHorizontally()
            return true
        }

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
            if key === self.mainPanel || key === self.previewPanel {
                return
            }
            // The system font / color panels can briefly become key while
            // the user interacts with them. Stay open.
            if key is NSFontPanel || key is NSColorPanel {
                return
            }
            self.close()
        }
    }

    private func buildPreviewPanelIfNeeded() -> PreviewPanel? {
        if let previewPanel = previewPanel { return previewPanel }
        guard let model = model else { return nil }

        let previewView = PreviewView(
            model: model,
            settings: AppSettings.shared,
            onCancel: { [weak self] in self?.cancelEdit() },
            onConfirm: { [weak self] in self?.confirmEdit() },
            onBeginEdit: { [weak self] in self?.beginEdit() }
        )
        let panel = makePanel(
            style: PreviewPanel.self,
            initialSize: defaultPreviewSize,
            rootView: previewView
        )
        panel.styleMask.insert(.resizable)
        panel.minSize = NSSize(width: 320, height: 220)
        panel.setContentSize(defaultPreviewSize)
        panel.twin = mainPanel
        panel.isInEditMode = { [weak self] in
            self?.model?.isEditing ?? false
        }
        registerResignObserver(for: panel)
        registerLiveResizeObserver(for: panel)
        self.previewPanel = panel
        return panel
    }

    private func registerLiveResizeObserver(for window: NSWindow) {
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.handlePreviewResizeEnded()
        }
        resignObservers.append(observer)
    }

    private func handlePreviewResizeEnded() {
        guard let model = model, !model.isEditing else { return }
        // After a resize the preview is key; hand focus back to main so the
        // popup-level keys keep working without going through the forwarding
        // path in PreviewPanel.keyDown.
        ignoreResign = true
        mainPanel?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            self?.ignoreResign = false
        }
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

    /// Places the preview panel to the right of the main popup at main's
    /// current position, without moving the main panel. Used when the
    /// preview is toggled on after the user has dragged the main popup
    /// away from the default centered position.
    private func positionPreviewNextToMain() {
        guard let mainPanel = mainPanel,
              let previewPanel = previewPanel,
              let screen = NSScreen.main else { return }
        mainPanel.layoutIfNeeded()
        previewPanel.layoutIfNeeded()

        let mainFrame = mainPanel.frame
        let pSize = previewPanel.frame.size
        let visible = screen.visibleFrame

        // Prefer to the right; if it would clip off-screen, flip to the
        // left of the main panel. If still clipped, fall back to right.
        var previewX = mainFrame.maxX + previewGap
        if previewX + pSize.width > visible.maxX - 8 {
            let leftCandidate = mainFrame.minX - previewGap - pSize.width
            if leftCandidate >= visible.minX + 8 {
                previewX = leftCandidate
            }
        }

        let previewY = mainFrame.maxY - pSize.height
        previewPanel.setFrameOrigin(NSPoint(x: previewX, y: previewY))
    }

    /// Re-centers the main/preview composition along X only, preserving
    /// each panel's current Y. Used after a drag that ends with the
    /// preview open: the user can move the popup vertically, but the
    /// composition snaps back to horizontal center so the preview stays
    /// on-screen.
    private func recenterHorizontally() {
        guard let mainPanel = mainPanel,
              let model = model,
              let screen = NSScreen.main else { return }

        mainPanel.layoutIfNeeded()
        let mainSize = mainPanel.frame.size
        let mainY = mainPanel.frame.origin.y
        let visible = screen.visibleFrame

        let showingPreview = model.showsPreview
        let previewSize = previewPanel?.frame.size ?? .zero
        let totalWidth = showingPreview
            ? mainSize.width + previewGap + previewSize.width
            : mainSize.width

        var leftEdge = visible.midX - totalWidth / 2
        leftEdge = max(visible.minX + 8, min(leftEdge, visible.maxX - totalWidth - 8))

        mainPanel.setFrameOrigin(NSPoint(x: leftEdge, y: mainY))

        if showingPreview, let previewPanel = previewPanel {
            let previewY = previewPanel.frame.origin.y
            let previewX = leftEdge + mainSize.width + previewGap
            previewPanel.setFrameOrigin(NSPoint(x: previewX, y: previewY))
        }
    }

    // MARK: - Drag handling

    private func handleMainDragBegan(at screenLocation: NSPoint) {
        dragStartScreenLocation = screenLocation
        dragStartMainOrigin = mainPanel?.frame.origin
        dragStartPreviewOrigin = previewPanel?.frame.origin
    }

    private func handleMainDragChanged(at screenLocation: NSPoint) {
        guard let start = dragStartScreenLocation,
              let mainOrigin = dragStartMainOrigin else { return }
        let dx = screenLocation.x - start.x
        let dy = screenLocation.y - start.y

        mainPanel?.setFrameOrigin(NSPoint(
            x: mainOrigin.x + dx,
            y: mainOrigin.y + dy
        ))
        if let previewOrigin = dragStartPreviewOrigin {
            previewPanel?.setFrameOrigin(NSPoint(
                x: previewOrigin.x + dx,
                y: previewOrigin.y + dy
            ))
        }
    }

    private func handleMainDragEnded() {
        dragStartScreenLocation = nil
        dragStartMainOrigin = nil
        dragStartPreviewOrigin = nil
        // No auto re-centering. The user can re-center on demand via the
        // configurable center shortcut (AppSettings.centerShortcut).

        // Restore the editor as key/first-responder if we were editing.
        // mainPanel.becomesKeyOnlyIfNeeded should already prevent the
        // drag from stealing key, but this is the safety net.
        guard let model = model, model.isEditing else { return }
        ignoreResign = true
        previewPanel?.makeKeyAndOrderFront(nil)
        if let textView = findRichTextView() {
            previewPanel?.makeFirstResponder(textView)
        }
        DispatchQueue.main.async { [weak self] in
            self?.ignoreResign = false
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
        positionPreviewNextToMain()
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
        positionPreviewNextToMain()

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

            // ⌘B / ⌘I / ⌘U toggle font traits on the selection (AppKit
            // doesn't expose toggle selectors we could fire via the
            // responder chain). ⌘T summons the system Fonts panel, which
            // then targets the text view's first responder.
            if event.modifierFlags.contains(.command),
               event.modifierFlags.intersection([.option, .control]).isEmpty {
                switch Int(event.keyCode) {
                case kVK_ANSI_B:
                    if let textView = self.findRichTextView() {
                        RichTextActions.toggleBold(in: textView)
                    }
                    return nil
                case kVK_ANSI_I:
                    if let textView = self.findRichTextView() {
                        RichTextActions.toggleItalic(in: textView)
                    }
                    return nil
                case kVK_ANSI_U:
                    if let textView = self.findRichTextView() {
                        RichTextActions.toggleUnderline(in: textView)
                    }
                    return nil
                case kVK_ANSI_T:
                    // NSFontPanel's default level is normalWindow (0) and
                    // its default frame may be empty before its first show,
                    // so a bare orderFront often leaves it behind us or
                    // off-screen. Center if it has never been positioned,
                    // raise the level to ours (.floating), and use
                    // makeKeyAndOrderFront to guarantee visibility.
                    //
                    // Suppress the auto-close while the key window
                    // transitions from preview → fontPanel; otherwise
                    // scheduleResignCheck can run on a runloop where
                    // NSApp.keyWindow hasn't settled yet and tear the
                    // popup down before the panel is actually key.
                    if let panel = NSFontManager.shared.fontPanel(true) {
                        panel.level = .floating
                        if !panel.isVisible {
                            panel.center()
                        }
                        self.ignoreResign = true
                        panel.makeKeyAndOrderFront(nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                            self?.ignoreResign = false
                        }
                    }
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
    /// Inspected before any keyDown switch. If it returns true the event
    /// is considered consumed (used for the user-configurable center
    /// shortcut, defined in AppSettings).
    var customShortcut: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if customShortcut?(event) == true { return }
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
    /// When set, popup-level keys (Space / Tab / arrows / digits / Return /
    /// Escape) received by the preview panel are forwarded to the main
    /// panel's keyDown so the popup keeps working even after the user
    /// clicks or resizes the preview and it became key.
    weak var twin: PopupPanel?
    var isInEditMode: () -> Bool = { false }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if !isInEditMode(), let twin = twin {
            twin.keyDown(with: event)
            return
        }
        super.keyDown(with: event)
    }
}
