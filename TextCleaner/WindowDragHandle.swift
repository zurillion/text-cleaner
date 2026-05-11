import AppKit
import SwiftUI

/// SwiftUI wrapper around a custom NSView that drives a window-drag
/// gesture. The view:
///   - shows an "open hand" cursor while the mouse hovers over it
///     (via `addCursorRect`),
///   - pushes the "closed hand" cursor on mouse down and pops it on
///     mouse up,
///   - reports the *screen* mouse location (NSEvent.mouseLocation) to
///     the controller for began / changed / ended, so the controller can
///     reposition windows using absolute coordinates regardless of how
///     those windows themselves move during the drag.
struct WindowDragHandle: NSViewRepresentable {
    let onBegan: (NSPoint) -> Void
    let onChanged: (NSPoint) -> Void
    let onEnded: () -> Void

    func makeNSView(context: Context) -> WindowDragHandleView {
        let view = WindowDragHandleView()
        view.onBegan = onBegan
        view.onChanged = onChanged
        view.onEnded = onEnded
        return view
    }

    func updateNSView(_ nsView: WindowDragHandleView, context: Context) {
        nsView.onBegan = onBegan
        nsView.onChanged = onChanged
        nsView.onEnded = onEnded
    }
}

final class WindowDragHandleView: NSView {
    var onBegan: ((NSPoint) -> Void)?
    var onChanged: ((NSPoint) -> Void)?
    var onEnded: (() -> Void)?

    private var dragStart: NSPoint?
    private var firedBegan = false
    private var dragging = false

    override func resetCursorRects() {
        super.resetCursorRects()
        // While dragging, suppress the openHand cursor rect: the window
        // moves under the mouse and the system keeps re-asserting the rect's
        // cursor at every cursor update, which would clobber the
        // closedHand we pushed in mouseDown.
        if !dragging {
            addCursorRect(bounds, cursor: .openHand)
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        firedBegan = false
        dragging = true
        window?.invalidateCursorRects(for: self)
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        if !firedBegan {
            firedBegan = true
            onBegan?(start)
        }
        onChanged?(NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStart != nil else { return }
        NSCursor.pop()
        dragStart = nil
        dragging = false
        window?.invalidateCursorRects(for: self)
        if firedBegan {
            firedBegan = false
            onEnded?()
        }
    }
}
