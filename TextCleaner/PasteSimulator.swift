import AppKit
import Carbon.HIToolbox

/// Two responsibilities:
///   - `readSourceText` snapshots the clipboard into a plain string the popup
///     can use to drive previews and transformations.
///   - `paste(text:)` puts a string on the clipboard, posts a synthetic ⌘V,
///     and then restores the original pasteboard contents so the user's
///     clipboard appears untouched.
enum PasteSimulator {
    /// Delay after posting ⌘V before restoring the original clipboard.
    /// The receiving app needs time to read the pasteboard.
    private static let restoreDelay: TimeInterval = 0.4

    static func readSourceText() -> String? {
        readText(from: NSPasteboard.general)
    }

    static func paste(text: String) {
        guard !text.isEmpty else {
            NSSound.beep()
            return
        }
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotItems(of: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        sendCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            restore(items: snapshot, to: pasteboard)
        }
    }

    // MARK: - Private

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
