import AppKit
import Carbon.HIToolbox

/// Reads the current clipboard (plain text, falling back to RTF), applies a
/// transformation, writes the result back to the pasteboard, simulates a ⌘V
/// keystroke so the frontmost app receives a paste, and finally restores the
/// original clipboard contents.
enum PasteSimulator {
    /// Delay after posting ⌘V before restoring the original clipboard.
    /// The receiving app needs time to read the pasteboard.
    private static let restoreDelay: TimeInterval = 0.4

    static func run(action: TextAction) {
        let pasteboard = NSPasteboard.general
        guard let original = readText(from: pasteboard), !original.isEmpty else {
            NSSound.beep()
            return
        }

        let transformed = action.transform(original)
        let snapshot = snapshotItems(of: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(transformed, forType: .string)

        sendCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            restore(items: snapshot, to: pasteboard)
        }
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

    private static func snapshotItems(of pb: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        guard let items = pb.pasteboardItems else { return [] }
        return items.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    private static func restore(items: [[NSPasteboard.PasteboardType: Data]], to pb: NSPasteboard) {
        guard !items.isEmpty else { return }
        pb.clearContents()
        let rebuilt: [NSPasteboardItem] = items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        pb.writeObjects(rebuilt)
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
