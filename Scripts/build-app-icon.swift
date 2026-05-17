#!/usr/bin/env swift
//
// build-app-icon.swift
//
// Renders the app icon defined in TextCleaner/AppIcon.swift into a
// static AppIcon.icns at all sizes required by macOS so the Finder
// (and the rest of the system) shows it as the bundle's icon.
//
// NSApp.applicationIconImage = … only overrides the Dock icon while
// the app runs; the Finder reads the icon from the .icns inside the
// bundle's Resources/, declared via CFBundleIconFile in Info.plist.
//
// Run:
//   swift Scripts/build-app-icon.swift
//
// Output:
//   TextCleaner/AppIcon.icns
//
// Wire it up in Xcode (once):
//   1. Drag TextCleaner/AppIcon.icns into the project navigator. In
//      the dialog tick "Copy items if needed" off, tick the
//      TextCleaner target on.
//   2. Info.plist already declares CFBundleIconFile = AppIcon.
//   3. (Optional) Add this script as a Run Script build phase so
//      the icon regenerates on every build:
//         swift "${SRCROOT}/Scripts/build-app-icon.swift"
//      Put it before "Copy Bundle Resources" so the regenerated
//      file is picked up.

import AppKit
import Foundation

// MARK: - Drawing (keep in sync with TextCleaner/AppIcon.swift)

private func drawBackground(in rect: NSRect, size: CGFloat) {
    let cornerRadius = size * 0.225  // matches macOS Big Sur+ icon mask
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()

    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.40, green: 0.45, blue: 0.95, alpha: 1.0),
        NSColor(srgbRed: 0.62, green: 0.30, blue: 0.85, alpha: 1.0),
    ])!
    gradient.draw(in: rect, angle: 135)

    let highlight = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.18),
        NSColor.white.withAlphaComponent(0.0),
    ])!
    highlight.draw(in: rect, angle: 270)
}

private func drawSymbol(size: CGFloat) {
    guard let base = NSImage(
        systemSymbolName: "wand.and.sparkles",
        accessibilityDescription: nil
    ) else { return }

    let pointSize = size * 0.55
    var config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    config = config.applying(.init(paletteColors: [.white]))
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

private func renderIcon(pixelSize: Int) -> NSBitmapImageRep {
    let s = CGFloat(pixelSize)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    drawBackground(in: rect, size: s)
    drawSymbol(size: s)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// MARK: - Export

let scriptURL = URL(fileURLWithPath: #file)
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputDir = repoRoot.appendingPathComponent("TextCleaner")
let iconsetDir = outputDir.appendingPathComponent("AppIcon.iconset")
let icnsURL = outputDir.appendingPathComponent("AppIcon.icns")

let sizes: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

do {
    try? FileManager.default.removeItem(at: iconsetDir)
    try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

    for (size, name) in sizes {
        let rep = renderIcon(pixelSize: size)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            fputs("error: failed to encode \(name)\n", stderr)
            exit(1)
        }
        try png.write(to: iconsetDir.appendingPathComponent(name))
    }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    task.arguments = ["-c", "icns", "-o", icnsURL.path, iconsetDir.path]
    try task.run()
    task.waitUntilExit()

    try? FileManager.default.removeItem(at: iconsetDir)

    if task.terminationStatus != 0 {
        fputs("error: iconutil exited with code \(task.terminationStatus)\n", stderr)
        exit(1)
    }

    print("Wrote \(icnsURL.path)")
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
