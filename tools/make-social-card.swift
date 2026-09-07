import AppKit
import Foundation

// Renders the 1200 x 630 social preview (site/og.png): cream ground, the mascot, and the headline.
// Run from the repo root: swift tools/make-social-card.swift

let ink = NSColor(red: 0.106, green: 0.106, blue: 0.122, alpha: 1)
let cream = NSColor(red: 1.0, green: 0.973, blue: 0.933, alpha: 1)
let mint = NSColor(red: 0.239, green: 0.961, blue: 0.706, alpha: 1)
let lemon = NSColor(red: 1.0, green: 0.886, blue: 0.302, alpha: 1)

let width = 1200, height = 630
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Ground with a faint dot grid
cream.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
ink.withAlphaComponent(0.10).setFill()
for x in stride(from: 12, to: width, by: 22) {
    for y in stride(from: 12, to: height, by: 22) {
        NSBezierPath(ovalIn: NSRect(x: CGFloat(x), y: CGFloat(y), width: 2.4, height: 2.4)).fill()
    }
}

// Sticker card
let cardRect = NSRect(x: 70, y: 90, width: 1060, height: 450)
ink.setFill()
NSBezierPath(roundedRect: cardRect.offsetBy(dx: 12, dy: -12), xRadius: 36, yRadius: 36).fill()
NSColor(red: 1, green: 0.992, blue: 0.973, alpha: 1).setFill()
let card = NSBezierPath(roundedRect: cardRect, xRadius: 36, yRadius: 36)
card.fill()
ink.setStroke(); card.lineWidth = 5; card.stroke()

// Mascot (left)
let cx: CGFloat = 300, cy: CGFloat = 315
let blob = NSBezierPath(ovalIn: NSRect(x: cx - 140, y: cy - 125, width: 280, height: 250))
mint.setFill(); blob.fill(); blob.lineWidth = 6; blob.stroke()
for ex in [cx - 48, cx + 48] {
    let eye = NSBezierPath(ovalIn: NSRect(x: ex - 36, y: cy - 12, width: 72, height: 72))
    NSColor.white.setFill(); eye.fill(); eye.lineWidth = 4; eye.stroke()
    let pupil = NSBezierPath(ovalIn: NSRect(x: ex - 4, y: cy + 8, width: 28, height: 28))
    ink.setFill(); pupil.fill()
}
let smile = NSBezierPath()
smile.appendArc(withCenter: NSPoint(x: cx, y: cy - 30), radius: 42, startAngle: 200, endAngle: 340, clockwise: false)
smile.lineWidth = 7; smile.lineCapStyle = .round; smile.stroke()

// Text (right)
let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byWordWrapping
let titleFont = NSFont.systemFont(ofSize: 56, weight: .heavy)
let rounded = NSFont(descriptor: titleFont.fontDescriptor.withDesign(.rounded) ?? titleFont.fontDescriptor, size: 56) ?? titleFont
let title = NSAttributedString(string: "Nine hours at a screen. Your eyes and back pay for it.",
                               attributes: [.font: rounded, .foregroundColor: ink, .paragraphStyle: paragraph])
title.draw(in: NSRect(x: 500, y: 250, width: 590, height: 280))

let subFont = NSFont.systemFont(ofSize: 28, weight: .medium)
let subRounded = NSFont(descriptor: subFont.fontDescriptor.withDesign(.rounded) ?? subFont.fontDescriptor, size: 28) ?? subFont
let sub = NSAttributedString(string: "Nudgie · free for Mac · eyes, walk, water, posture, stretch",
                             attributes: [.font: subRounded, .foregroundColor: ink.withAlphaComponent(0.75), .paragraphStyle: paragraph])
sub.draw(in: NSRect(x: 500, y: 168, width: 590, height: 80))

// Lemon "FREE" tag
let tagRect = NSRect(x: 500, y: 118, width: 118, height: 44)
lemon.setFill()
let tag = NSBezierPath(roundedRect: tagRect, xRadius: 22, yRadius: 22)
tag.fill(); tag.lineWidth = 4; tag.stroke()
let tagFont = NSFont.systemFont(ofSize: 22, weight: .heavy)
let tagText = NSAttributedString(string: "FREE", attributes: [.font: tagFont, .foregroundColor: ink])
tagText.draw(at: NSPoint(x: 528, y: 126))

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: "site/og.png"))
print("Wrote site/og.png (\(png.count) bytes)")
