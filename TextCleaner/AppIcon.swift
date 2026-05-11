import AppKit

/// Programmatically renders the app icon from an SF Symbol over a gradient
/// rounded-square background. Avoids checking binary icon assets into git.
enum AppIcon {
    static func make(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        drawBackground(size: size)
        drawSymbol(size: size)

        image.unlockFocus()
        return image
    }

    private static func drawBackground(size: CGFloat) {
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let cornerRadius = size * 0.225  // matches macOS Big Sur+ icon mask
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.addClip()

        let gradient = NSGradient(colors: [
            NSColor(srgbRed: 0.40, green: 0.45, blue: 0.95, alpha: 1.0),
            NSColor(srgbRed: 0.62, green: 0.30, blue: 0.85, alpha: 1.0),
        ])!
        gradient.draw(in: rect, angle: 135)

        // Subtle inner highlight along the top edge.
        let highlight = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.18),
            NSColor.white.withAlphaComponent(0.0),
        ])!
        highlight.draw(in: rect, angle: 270)
    }

    private static func drawSymbol(size: CGFloat) {
        guard let base = NSImage(
            systemSymbolName: "wand.and.sparkles",
            accessibilityDescription: nil
        ) else { return }

        let pointSize = size * 0.55
        var config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        if #available(macOS 12.0, *) {
            config = config.applying(.init(paletteColors: [.white]))
        }
        let symbol = base.withSymbolConfiguration(config) ?? base

        let drawn = symbol.size
        let rect = NSRect(
            x: (size - drawn.width) / 2,
            y: (size - drawn.height) / 2,
            width: drawn.width,
            height: drawn.height
        )
        symbol.draw(in: rect)
    }
}
