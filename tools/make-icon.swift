import AppKit
import Foundation

// Renders Nudgie's face into every size iconutil needs and writes Resources/Nudgie.icns.

let ink = NSColor(red: 0.106, green: 0.106, blue: 0.122, alpha: 1)
let cream = NSColor(red: 1.0, green: 0.973, blue: 0.933, alpha: 1)
let mint = NSColor(red: 0.239, green: 0.961, blue: 0.706, alpha: 1)

func draw(size s: CGFloat) {
    let background = NSBezierPath(roundedRect: NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88),
                                  xRadius: s * 0.2, yRadius: s * 0.2)
    cream.setFill(); background.fill()
    ink.setStroke(); background.lineWidth = s * 0.03; background.stroke()

    let blob = NSBezierPath(ovalIn: NSRect(x: s * 0.2, y: s * 0.2, width: s * 0.6, height: s * 0.56))
    mint.setFill(); blob.fill()
    blob.lineWidth = s * 0.03; blob.stroke()

    for x in [s * 0.4, s * 0.6] {
        let white = NSBezierPath(ovalIn: NSRect(x: x - s * 0.08, y: s * 0.44, width: s * 0.16, height: s * 0.16))
        NSColor.white.setFill(); white.fill()
        white.lineWidth = s * 0.02; white.stroke()
        let pupil = NSBezierPath(ovalIn: NSRect(x: x, y: s * 0.49, width: s * 0.06, height: s * 0.06))
        ink.setFill(); pupil.fill()
    }

    let smile = NSBezierPath()
    smile.appendArc(withCenter: NSPoint(x: s * 0.5, y: s * 0.42), radius: s * 0.08,
                    startAngle: 200, endAngle: 340, clockwise: false)
    smile.lineWidth = s * 0.025
    smile.lineCapStyle = .round
    smile.stroke()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(size: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: "build/Nudgie.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in sizes {
    try png(pixels: pixels).write(to: iconset.appendingPathComponent("\(name).png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/Nudgie.icns"]
try iconutil.run()
iconutil.waitUntilExit()
if iconutil.terminationStatus != 0 {
    FileHandle.standardError.write("iconutil failed with \(iconutil.terminationStatus)\n".data(using: .utf8)!)
    exit(1)
}
print("Wrote Resources/Nudgie.icns")
