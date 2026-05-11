import AppKit
import SwiftUI

extension NSAttributedString.Key {
    /// Marks `.foregroundColor` attributes that `RichTextThemer` injected
    /// to make plain text readable on a themed background. These markers
    /// are stripped before the value is reported back to the view model,
    /// so the user's "logical" content stays un-themed.
    static let popupInjectedColor = NSAttributedString.Key("TextCleanerInjectedColor")
}

/// SwiftUI wrapper around `NSTextView` with rich-text editing enabled.
/// Same component is used for both the preview pane (`isEditable=false`)
/// and the edit pane (`isEditable=true`) — only the editable flag and
/// the onChange callback differ.
///
/// We bypass the usual `NSColor.textColor` / NSAppearance plumbing for
/// the default text color (it wasn't propagating reliably through
/// `NSHostingView`) and instead inject a concrete color from the theme
/// onto runs that don't already carry one. The injection is tagged with
/// `.popupInjectedColor` so we can strip it back out on the way to the
/// view model.
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
        textView.insertionPointColor = NSColor(theme.foreground)
        textView.appearance = theme.nsAppearance
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator

        scrollView.documentView = textView

        let defaultColor = NSColor(theme.foreground)
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: defaultColor,
            .popupInjectedColor: true,
        ]

        let themed = RichTextThemer.apply(attributedString, color: defaultColor)
        context.coordinator.textView = textView
        context.coordinator.lastInputValue = attributedString
        context.coordinator.lastTheme = theme
        textView.textStorage?.setAttributedString(themed)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.isEditable = isEditable
        textView.appearance = theme.nsAppearance
        textView.insertionPointColor = NSColor(theme.foreground)
        scrollView.appearance = theme.nsAppearance

        let defaultColor = NSColor(theme.foreground)
        var typing = textView.typingAttributes
        typing[.foregroundColor] = defaultColor
        typing[.popupInjectedColor] = true
        textView.typingAttributes = typing

        let themeChanged = context.coordinator.lastTheme != theme
        let contentChanged = !attributedString.isEqual(to: context.coordinator.lastInputValue)

        // Push to storage when the binding actually changed OR when the
        // theme changed (so previously-injected colors update). Otherwise
        // we'd kill the user's selection on every keystroke.
        if contentChanged || themeChanged {
            let themed = RichTextThemer.apply(attributedString, color: defaultColor)
            let storage = textView.textStorage
            let savedSelection = textView.selectedRange()
            storage?.setAttributedString(themed)
            let clampedLoc = min(savedSelection.location, themed.length)
            textView.setSelectedRange(NSRange(location: clampedLoc, length: 0))
            context.coordinator.lastInputValue = attributedString
            context.coordinator.lastTheme = theme
        }

        if isEditable, textView.window?.firstResponder !== textView {
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
        var lastInputValue: NSAttributedString = NSAttributedString()
        var lastTheme: PopupTheme? = nil

        init(parent: RichTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let snapshot = NSAttributedString(attributedString: textView.attributedString())
            let stripped = RichTextThemer.strip(snapshot)
            lastInputValue = stripped
            parent.onChange?(stripped)
        }
    }
}

// MARK: - Theme injection / stripping

enum RichTextThemer {
    /// Adds `.foregroundColor = color` (plus the `popupInjectedColor`
    /// marker) to runs of `input` that don't already carry a foreground
    /// color. Existing colors are left alone.
    static func apply(_ input: NSAttributedString, color: NSColor) -> NSAttributedString {
        guard input.length > 0 else { return input }
        let mut = NSMutableAttributedString(attributedString: input)
        let range = NSRange(location: 0, length: mut.length)
        mut.enumerateAttribute(.foregroundColor, in: range, options: []) { value, runRange, _ in
            if value == nil {
                mut.addAttribute(.foregroundColor, value: color, range: runRange)
                mut.addAttribute(.popupInjectedColor, value: true, range: runRange)
            }
        }
        return mut
    }

    /// Removes the `.foregroundColor` from runs flagged as theme-injected
    /// (and removes the marker itself). User-set colors are untouched.
    static func strip(_ input: NSAttributedString) -> NSAttributedString {
        guard input.length > 0 else { return input }
        let mut = NSMutableAttributedString(attributedString: input)
        let range = NSRange(location: 0, length: mut.length)
        var dirty = false
        mut.enumerateAttribute(.popupInjectedColor, in: range, options: []) { value, runRange, _ in
            if (value as? Bool) == true {
                mut.removeAttribute(.foregroundColor, range: runRange)
                mut.removeAttribute(.popupInjectedColor, range: runRange)
                dirty = true
            }
        }
        return dirty ? mut : input
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
        toggleFontTrait(.boldFontMask, in: textView)
    }

    static func toggleItalic(in textView: NSTextView) {
        toggleFontTrait(.italicFontMask, in: textView)
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

    private static func toggleFontTrait(_ trait: NSFontTraitMask, in textView: NSTextView) {
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
    }
}
