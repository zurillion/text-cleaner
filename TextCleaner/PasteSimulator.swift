import AppKit
import Carbon.HIToolbox

/// Reads/writes the clipboard as `NSAttributedString`, preserving any RTF
/// formatting. `paste(attributed:)` decides at write time whether the
/// outgoing text carries non-trivial styling — if it does, both RTF and
/// plain are placed on the pasteboard so the receiver can pick. Otherwise
/// only plain text is written.
enum PasteSimulator {
    /// Delay after posting ⌘V before restoring the original clipboard.
    private static let restoreDelay: TimeInterval = 0.4

    // MARK: - Read

    static func readSourceAttributed() -> NSAttributedString {
        let pb = NSPasteboard.general
        if let data = pb.data(forType: .rtfd),
           let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtfd],
                documentAttributes: nil) {
            return attr
        }
        if let data = pb.data(forType: .rtf),
           let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil) {
            return attr
        }
        if let data = pb.data(forType: .html),
           let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil) {
            return attr
        }
        if let plain = pb.string(forType: .string), !plain.isEmpty {
            return NSAttributedString(string: plain)
        }
        return NSAttributedString()
    }

    // MARK: - Paste

    static func paste(attributed: NSAttributedString) {
        guard attributed.length > 0 else {
            NSSound.beep()
            return
        }
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotItems(of: pasteboard)

        pasteboard.clearContents()
        writeAttributed(attributed, to: pasteboard)

        sendCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            restore(items: snapshot, to: pasteboard)
        }
    }

    private static func writeAttributed(_ attributed: NSAttributedString, to pb: NSPasteboard) {
        let plain = attributed.string

        if hasFormatting(attributed) {
            let range = NSRange(location: 0, length: attributed.length)
            if let rtfData = try? attributed.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) {
                pb.setData(rtfData, forType: .rtf)
            }
            pb.setString(plain, forType: .string)
        } else {
            pb.setString(plain, forType: .string)
        }
    }

    /// Heuristic: any explicit bold/italic font trait, underline,
    /// strikethrough, link or non-default color counts as formatting.
    private static func hasFormatting(_ attr: NSAttributedString) -> Bool {
        guard attr.length > 0 else { return false }
        let fullRange = NSRange(location: 0, length: attr.length)
        var formatted = false

        attr.enumerateAttributes(in: fullRange, options: []) { attrs, _, stop in
            if let font = attrs[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.bold) || traits.contains(.italic) {
                    formatted = true; stop.pointee = true; return
                }
            }
            if let style = attrs[.underlineStyle] as? Int, style != 0 {
                formatted = true; stop.pointee = true; return
            }
            if let style = attrs[.strikethroughStyle] as? Int, style != 0 {
                formatted = true; stop.pointee = true; return
            }
            if attrs[.link] != nil {
                formatted = true; stop.pointee = true; return
            }
            if let color = attrs[.foregroundColor] as? NSColor,
               !colorIsDefault(color) {
                formatted = true; stop.pointee = true; return
            }
            if attrs[.backgroundColor] != nil {
                formatted = true; stop.pointee = true; return
            }
        }
        return formatted
    }

    private static func colorIsDefault(_ color: NSColor) -> Bool {
        // Compare against the named system text colors. These all resolve via
        // the catalog and don't have stable RGB components, so check identity
        // / catalog name first.
        if color == NSColor.labelColor { return true }
        if color == NSColor.textColor  { return true }
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return false }
        // Black with full alpha is the rich-text editor default in TextEdit.
        if abs(rgb.redComponent)   < 0.01,
           abs(rgb.greenComponent) < 0.01,
           abs(rgb.blueComponent)  < 0.01,
           abs(rgb.alphaComponent - 1) < 0.01 {
            return true
        }
        return false
    }

    // MARK: - Snapshot / restore

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

    // MARK: - Cmd-V

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
