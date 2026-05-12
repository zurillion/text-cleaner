import AppKit
import SwiftUI

/// SwiftUI wrapper around a custom NSView that drives a window-drag
/// gesture. The view:
///   - shows an "open hand" cursor while the mouse hovers over it,
///   - replaces it with the "closed hand" cursor on mouse down and
///     restores open-hand on mouse up,
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
    private var hoverPushed = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        // .activeAlways: tracking fires regardless of whether the panel
        // is key (we need this in edit mode, where the preview panel is
        // key and the main popup isn't).
        let area = NSTrackingArea(
            rect: bounds,
            options: [
                .mouseEnteredAndExited,
                .cursorUpdate,
                .activeAlways,
                .inVisibleRect,
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    // MARK: - Cursor management
    //
    // We use NSCursor.push/pop rather than NSCursor.set/cursorUpdate
    // alone: push leaves the cursor on a stack so SwiftUI's hosting and
    // other cursor consumers can't transparently override it. cursorUpdate
    // is kept as a safety net for the in-area movements.

    override func mouseEntered(with event: NSEvent) {
        pushHoverCursor()
    }

    override func mouseExited(with event: NSEvent) {
        popHoverCursor()
    }

    override func cursorUpdate(with event: NSEvent) {
        // Belt-and-suspenders: re-assert cursor on every cursorUpdate.
        if dragging {
            NSCursor.closedHand.set()
        } else {
            NSCursor.openHand.set()
        }
    }

    private func pushHoverCursor() {
        guard !hoverPushed, !dragging else { return }
        hoverPushed = true
        NSCursor.openHand.push()
    }

    private func popHoverCursor() {
        guard hoverPushed, !dragging else { return }
        hoverPushed = false
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        firedBegan = false
        dragging = true
        if hoverPushed {
            NSCursor.pop()
            hoverPushed = false
        }
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
        NSCursor.pop()  // closedHand
        dragStart = nil
        dragging = false
        // If the mouse is still inside our area, re-push openHand so
        // hovering after release continues to show the hand.
        if isMouseInside() {
            NSCursor.openHand.push()
            hoverPushed = true
        }
        if firedBegan {
            firedBegan = false
            onEnded?()
        }
    }

    private func isMouseInside() -> Bool {
        guard let window = window else { return false }
        let mouseInWindow = window.mouseLocationOutsideOfEventStream
        let local = convert(mouseInWindow, from: nil)
        return bounds.contains(local)
    }
}
