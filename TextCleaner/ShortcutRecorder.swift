import AppKit
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.shortcut = shortcut
        view.onChange = { shortcut = $0 }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        nsView.shortcut = shortcut
        nsView.needsDisplay = true
    }
}

final class ShortcutRecorderView: NSView {
    var shortcut: KeyboardShortcut?
    var onChange: ((KeyboardShortcut) -> Void)?

    private var recording = false {
        didSet { needsDisplay = true }
    }
    private var localMonitor: Any?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let insets = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: insets, xRadius: 5, yRadius: 5)
        NSColor.textBackgroundColor.setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = recording ? 2 : 1
        path.stroke()

        let title: String
        if recording {
            title = "Press shortcut…"
        } else if let shortcut = shortcut {
            title = shortcut.displayString
        } else {
            title = "Click to record"
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
        ]
        let str = title as NSString
        let size = str.size(withAttributes: attrs)
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        str.draw(at: point, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        startRecording()
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        return super.resignFirstResponder()
    }

    private func startRecording() {
        guard !recording else { return }
        recording = true
        // Local monitor lets us capture combinations like ⌘V without the
        // window menu intercepting them first.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.recording else { return event }
            if event.type == .keyDown {
                return self.handleKeyDown(event)
            }
            return event
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let allowedMods: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let mods = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .intersection(allowedMods)

        // Escape with no modifiers cancels recording.
        if Int(event.keyCode) == kVK_Escape && mods.isEmpty {
            stopRecording()
            return nil
        }

        guard !mods.isEmpty else {
            NSSound.beep()
            return nil
        }

        let new = KeyboardShortcut(keyCode: UInt32(event.keyCode), modifierFlags: mods)
        shortcut = new
        onChange?(new)
        stopRecording()
        return nil
    }
}

// Local helper since this file uses kVK_Escape without importing Carbon.
private let kVK_Escape = 0x35
