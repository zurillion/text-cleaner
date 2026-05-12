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

    // Use a tracking area with .activeAlways instead of addCursorRect:
    // cursor rects only apply when the panel is the key window, so in
    // edit mode (where the preview panel is key) the main popup wouldn't
    // get the open-hand cursor on hover.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [
                .cursorUpdate,
                .mouseEnteredAndExited,
                .activeAlways,
                .inVisibleRect,
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func cursorUpdate(with event: NSEvent) {
        applyCursor()
    }

    // Belt-and-suspenders for the cursorUpdate path: when the mouse enters
    // the area (especially crossing in from another window whose first
    // responder is an NSTextView with its own I-beam cursor rect), set
    // the cursor explicitly so it doesn't stay stuck on I-beam.
    override func mouseEntered(with event: NSEvent) {
        applyCursor()
    }

    private func applyCursor() {
        if dragging {
            NSCursor.closedHand.set()
        } else {
            NSCursor.openHand.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        firedBegan = false
        dragging = true
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
        if firedBegan {
            firedBegan = false
            onEnded?()
        }
    }
}
