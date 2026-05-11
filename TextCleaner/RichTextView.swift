import AppKit
import SwiftUI

/// SwiftUI wrapper around `NSTextView` with rich-text editing enabled.
/// Same component is used for both the preview pane (`isEditable=false`)
/// and the edit pane (`isEditable=true`) — only the editable flag and
/// the onChange callback differ.
///
/// With `isRichText = true`, the underlying `NSTextView` preserves
/// per-character attributes from RTF. The default text color follows
/// the `NSAppearance` we set from the popup theme, so unattributed
/// characters remain readable on dark themes without forcing an
/// override that would clobber explicit colors in the attributed
/// string.
struct RichTextView: NSViewRepresentable {
    let attributedString: NSAttributedString
    let isEditable: Bool
    let theme: PopupTheme
    let onChange: ((NSAttributedString) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.appearance = theme.nsAppearance

        let textView = NSTextView()
        textView.isRichText = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.usesInspectorBar = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.font = .systemFont(ofSize: 13)
        textView.appearance = theme.nsAppearance
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator

        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.lastValue = attributedString
        textView.textStorage?.setAttributedString(attributedString)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.isEditable = isEditable
        textView.appearance = theme.nsAppearance
        scrollView.appearance = theme.nsAppearance

        // Only push a new value into the storage when the binding actually
        // changed; otherwise we'd wipe attributes and the user's selection
        // on every re-render.
        if !attributedString.isEqual(to: context.coordinator.lastValue) {
            let storage = textView.textStorage
            let savedSelection = textView.selectedRange()
            storage?.setAttributedString(attributedString)
            let clampedLoc = min(savedSelection.location, attributedString.length)
            textView.setSelectedRange(NSRange(location: clampedLoc, length: 0))
            context.coordinator.lastValue = attributedString
        }

        if isEditable,
           textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextView
        weak var textView: NSTextView?
        var lastValue: NSAttributedString = NSAttributedString()

        init(parent: RichTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let snapshot = NSAttributedString(attributedString: textView.attributedString())
            lastValue = snapshot
            parent.onChange?(snapshot)
        }
    }
}

// MARK: - Rich-text actions
//
// AppKit doesn't ship `toggleBold:` / `toggleItalic:` selectors that we can
// fire via the responder chain. The Format menu in TextEdit hangs off
// NSFontManager.addFontTrait: with the trait encoded in the menu item's
// tag. Rather than synthesising menu items, we toggle traits directly on
// the text view's storage / typing attributes.

enum RichTextActions {
    static func toggleBold(in textView: NSTextView) {
        toggleFontTrait(.boldFontMask, opposite: .unboldFontMask, in: textView)
    }

    static func toggleItalic(in textView: NSTextView) {
        toggleFontTrait(.italicFontMask, opposite: .unitalicFontMask, in: textView)
    }

    static func toggleUnderline(in textView: NSTextView) {
        let range = textView.selectedRange()
        let underlined = NSUnderlineStyle.single.rawValue

        if range.length == 0 {
            var attrs = textView.typingAttributes
            let style = (attrs[.underlineStyle] as? Int) ?? 0
            attrs[.underlineStyle] = (style == 0) ? underlined : 0
            textView.typingAttributes = attrs
            return
        }

        guard let storage = textView.textStorage else { return }

        var allUnderlined = true
        storage.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, _ in
            let style = (value as? Int) ?? 0
            if style == 0 { allUnderlined = false }
        }

        storage.beginEditing()
        if allUnderlined {
            storage.removeAttribute(.underlineStyle, range: range)
        } else {
            storage.addAttribute(.underlineStyle, value: underlined, range: range)
        }
        storage.endEditing()
        textView.didChangeText()
    }

    private static func toggleFontTrait(
        _ trait: NSFontTraitMask,
        opposite: NSFontTraitMask,
        in textView: NSTextView
    ) {
        let fm = NSFontManager.shared
        let range = textView.selectedRange()

        if range.length == 0 {
            var attrs = textView.typingAttributes
            let font = (attrs[.font] as? NSFont) ?? .systemFont(ofSize: 13)
            let hasTrait = fm.traits(of: font).contains(trait)
            let newFont = hasTrait
                ? fm.convert(font, toNotHaveTrait: trait)
                : fm.convert(font, toHaveTrait: trait)
            attrs[.font] = newFont
            textView.typingAttributes = attrs
            return
        }

        guard let storage = textView.textStorage else { return }

        var allHave = true
        storage.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            let font = (value as? NSFont) ?? .systemFont(ofSize: 13)
            if !fm.traits(of: font).contains(trait) { allHave = false }
        }

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let oldFont = (value as? NSFont) ?? .systemFont(ofSize: 13)
            let newFont = allHave
                ? fm.convert(oldFont, toNotHaveTrait: trait)
                : fm.convert(oldFont, toHaveTrait: trait)
            storage.addAttribute(.font, value: newFont, range: subRange)
        }
        storage.endEditing()
        textView.didChangeText()
        _ = opposite  // unused; kept for symmetry / future use
    }
}
