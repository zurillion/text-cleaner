import AppKit
import Carbon.HIToolbox

/// Reads the current clipboard (plain text, falling back to RTF), applies a
/// transformation, writes the result back to the pasteboard, and then
/// simulates a ⌘V keystroke so the frontmost app receives a paste.
enum PasteSimulator {
    static func run(action: TextAction) {
        let pasteboard = NSPasteboard.general
        guard let original = readText(from: pasteboard), !original.isEmpty else {
            NSSound.beep()
            return
        }

        let transformed = action.transform(original)

        pasteboard.clearContents()
        pasteboard.setString(transformed, forType: .string)

        sendCommandV()
    }

    private static func readText(from pb: NSPasteboard) -> String? {
        if let plain = pb.string(forType: .string), !plain.isEmpty {
            return plain
        }
        if let rtfData = pb.data(forType: .rtf),
           let attr = try? NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil) {
            return attr.string
        }
        if let rtfdData = pb.data(forType: .rtfd),
           let attr = try? NSAttributedString(
                data: rtfdData,
                options: [.documentType: NSAttributedString.DocumentType.rtfd],
                documentAttributes: nil) {
            return attr.string
        }
        if let html = pb.data(forType: .html),
           let attr = try? NSAttributedString(
                data: html,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil) {
            return attr.string
        }
        return nil
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        up?.flags = .maskCommand

        let tap = CGEventTapLocation.cghidEventTap
        down?.post(tap: tap)
        up?.post(tap: tap)
    }
}
