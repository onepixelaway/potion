import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    let background = NSBezierPath(roundedRect: NSRect(x: 65, y: 65, width: 894, height: 894), xRadius: 195, yRadius: 195)
    NSColor(calibratedRed: 0.35, green: 0.42, blue: 0.28, alpha: 1).setFill(); background.fill()
    let circle = NSBezierPath(ovalIn: NSRect(x: 175, y: 175, width: 674, height: 674))
    NSColor.white.withAlphaComponent(0.07).setFill(); circle.fill()
    let flask = NSBezierPath()
    flask.move(to: NSPoint(x: 420, y: 748)); flask.line(to: NSPoint(x: 604, y: 748)); flask.line(to: NSPoint(x: 604, y: 585))
    flask.curve(to: NSPoint(x: 739, y: 350), controlPoint1: NSPoint(x: 604, y: 545), controlPoint2: NSPoint(x: 739, y: 428))
    flask.curve(to: NSPoint(x: 650, y: 264), controlPoint1: NSPoint(x: 739, y: 291), controlPoint2: NSPoint(x: 713, y: 264))
    flask.line(to: NSPoint(x: 374, y: 264))
    flask.curve(to: NSPoint(x: 285, y: 350), controlPoint1: NSPoint(x: 311, y: 264), controlPoint2: NSPoint(x: 285, y: 291))
    flask.curve(to: NSPoint(x: 420, y: 585), controlPoint1: NSPoint(x: 285, y: 428), controlPoint2: NSPoint(x: 420, y: 545))
    flask.close()
    NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.86, alpha: 1).setFill(); flask.fill()
    let liquid = NSBezierPath(); liquid.move(to: NSPoint(x: 375, y: 432))
    liquid.curve(to: NSPoint(x: 649, y: 432), controlPoint1: NSPoint(x: 480, y: 386), controlPoint2: NSPoint(x: 552, y: 478))
    liquid.curve(to: NSPoint(x: 650, y: 330), controlPoint1: NSPoint(x: 700, y: 356), controlPoint2: NSPoint(x: 684, y: 330))
    liquid.line(to: NSPoint(x: 374, y: 330)); liquid.curve(to: NSPoint(x: 375, y: 432), controlPoint1: NSPoint(x: 340, y: 330), controlPoint2: NSPoint(x: 324, y: 356)); liquid.close()
    NSColor(calibratedRed: 0.58, green: 0.65, blue: 0.43, alpha: 1).setFill(); liquid.fill()
    NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.86, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 397, y: 730, width: 230, height: 49), xRadius: 18, yRadius: 18).fill()
    let sparkle = NSBezierPath(); sparkle.move(to: NSPoint(x: 738, y: 745)); sparkle.line(to: NSPoint(x: 756, y: 697)); sparkle.line(to: NSPoint(x: 804, y: 679)); sparkle.line(to: NSPoint(x: 756, y: 661)); sparkle.line(to: NSPoint(x: 738, y: 613)); sparkle.line(to: NSPoint(x: 720, y: 661)); sparkle.line(to: NSPoint(x: 672, y: 679)); sparkle.line(to: NSPoint(x: 720, y: 697)); sparkle.close(); sparkle.fill()
    image.unlockFocus()
    let data = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
    let names: [String]
    switch size {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for name in names { try data.write(to: root.appendingPathComponent(name)) }
}
