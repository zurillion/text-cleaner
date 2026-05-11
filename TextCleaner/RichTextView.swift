import AppKit
import SwiftUI

/// SwiftUI wrapper around `NSTextView` with rich-text editing enabled.
/// Same component is used for both the preview pane (`isEditable=false`)
/// and the edit pane (`isEditable=true`) — only the editable flag and
/// the onChange callback differ.
///
/// With `isRichText = true` + `allowsEditingTextAttributes = true`, the
/// underlying `NSTextView` natively responds to `toggleBold:`,
/// `toggleItalic:`, `toggleUnderline:` and friends. The popup controller
/// fires those selectors via the responder chain on ⌘B / ⌘I / ⌘U.
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

        let textView = NSTextView()
        textView.isRichText = true
        textView.allowsEditingTextAttributes = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.usesInspectorBar = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = NSColor(theme.foreground)
        textView.insertionPointColor = NSColor(theme.foreground)
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
        textView.textColor = NSColor(theme.foreground)
        textView.insertionPointColor = NSColor(theme.foreground)

        // Replace the text only if the binding value is genuinely new
        // (i.e., not the result of the user typing into this same view).
        // Otherwise we'd kill the selection on every keystroke.
        if !attributedString.isEqual(to: context.coordinator.lastValue) {
            let storage = textView.textStorage
            let savedSelection = textView.selectedRange()
            storage?.setAttributedString(attributedString)
            let clamped = NSRange(
                location: min(savedSelection.location, attributedString.length),
                length: 0
            )
            textView.setSelectedRange(clamped)
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
            let snapshot = (textView.attributedString().copy() as? NSAttributedString)
                ?? NSAttributedString(attributedString: textView.attributedString())
            lastValue = snapshot
            parent.onChange?(snapshot)
        }
    }
}
