import AppKit

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for (name, pixels) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
                       ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
                       ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 512, y: CGFloat(pixels) / 512)
    let paper = NSBezierPath(roundedRect: NSRect(x: 55, y: 50, width: 402, height: 412), xRadius: 24, yRadius: 24)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23)
    shadow.shadowOffset = NSSize(width: 0, height: -8); shadow.shadowBlurRadius = 18; shadow.set()
    NSColor(srgbRed: 1, green: 0.93, blue: 0.59, alpha: 1).setFill(); paper.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(srgbRed: 0.96, green: 0.82, blue: 0.35, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 55, y: 376, width: 402, height: 86), xRadius: 24, yRadius: 24).fill()
    NSRect(x: 55, y: 376, width: 402, height: 50).fill()
    NSColor(srgbRed: 0.42, green: 0.33, blue: 0.12, alpha: 0.78).setFill()
    for (y, width) in [(310, 256), (253, 224), (196, 169)] {
        NSBezierPath(roundedRect: NSRect(x: 120, y: y, width: width, height: 13), xRadius: 6, yRadius: 6).fill()
    }
    NSColor(srgbRed: 0.93, green: 0.79, blue: 0.35, alpha: 1).setFill()
    let fold = NSBezierPath(); fold.move(to: NSPoint(x: 375, y: 50)); fold.line(to: NSPoint(x: 375, y: 132))
    fold.line(to: NSPoint(x: 457, y: 132)); fold.close(); fold.fill()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination + "/" + name + ".png"))
}
