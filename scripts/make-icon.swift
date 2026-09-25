import AppKit
// Usage: swift scripts/make-icon.swift scripts/icon-logo.pdf Resources/Assets.xcassets/AppIcon.appiconset
// The logo is a potrace vector of the cube artwork, so every size renders crisp edges.
let source = NSImage(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))!
let root = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
/// Point sizes in the icon set; each is written at 1x and, from half its pixel size, at 2x.
let pointSizes = [16, 32, 128, 256, 512]
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    // Pre-Tahoe fallback (macOS 26 uses Resources/AppIcon.icon): white tile on Apple's 824pt grid, with a soft drop shadow.
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 20 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -8 * scale)
    shadow.set()
    NSColor.white.setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.black.withAlphaComponent(0.08).setStroke(); tile.lineWidth = 2; tile.stroke()
    let logo: CGFloat = 620
    source.draw(in: NSRect(x: 512 - logo / 2, y: 512 - logo / 2, width: logo, height: logo), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    let names = [size / 2, size].filter(pointSizes.contains).map { points in
        "icon_\(points)x\(points)\(points == size ? "" : "@2x").png"
    }
    for name in names { try data.write(to: root.appendingPathComponent(name)) }
}
