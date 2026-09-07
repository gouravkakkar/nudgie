import AppKit

/// Nudgie's face at 18 pt as a template image, so it follows light and dark menu bars.
/// Frames are rendered once on the main thread and cached: a lazy drawing handler could be
/// invoked by AppKit off the main thread, which would trip the main-actor check in Swift 6.
enum MenuBarIcon {
    private static var cache: [IconState: NSImage] = [:]

    static func image(for state: IconState) -> NSImage {
        if let cached = cache[state] { return cached }
        let image = render(state)
        cache[state] = image
        return image
    }

    private static func render(_ state: IconState) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        defer { image.unlockFocus() }
        let rect = NSRect(x: 0, y: 0, width: 18, height: 18)
        do {
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let body = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 2.5))
            body.lineWidth = 1.8
            body.stroke()

            let eyeY = rect.midY + 1
            for x in [rect.midX - 3.2, rect.midX + 3.2] {
                switch state {
                case .blink, .zzz:
                    let line = NSBezierPath()
                    line.move(to: NSPoint(x: x - 1.5, y: eyeY))
                    line.line(to: NSPoint(x: x + 1.5, y: eyeY))
                    line.lineWidth = 1.5
                    line.lineCapStyle = .round
                    line.stroke()
                case .normal, .shh:
                    NSBezierPath(ovalIn: NSRect(x: x - 1.4, y: eyeY - 1.4, width: 2.8, height: 2.8)).fill()
                }
            }

            switch state {
            case .shh:
                // Lips pressed shut. At 18 pt a finger-over-the-lips just reads as a smudge
                // running out of the head, so the flat mouth carries the whole "quiet" idea.
                let lips = NSBezierPath()
                lips.move(to: NSPoint(x: rect.midX - 3, y: rect.midY - 3.5))
                lips.line(to: NSPoint(x: rect.midX + 3, y: rect.midY - 3.5))
                lips.lineWidth = 1.5
                lips.lineCapStyle = .round
                lips.stroke()
            case .zzz:
                let z = NSAttributedString(string: "z", attributes: [
                    .font: NSFont.systemFont(ofSize: 7, weight: .black),
                    .foregroundColor: NSColor.black,
                ])
                z.draw(at: NSPoint(x: rect.maxX - 6, y: rect.maxY - 8))
            case .normal, .blink:
                let smile = NSBezierPath()
                smile.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY - 1.5), radius: 3,
                                startAngle: 200, endAngle: 340, clockwise: false)
                smile.lineWidth = 1.5
                smile.lineCapStyle = .round
                smile.stroke()
            }
        }
        image.isTemplate = true
        return image
    }
}
