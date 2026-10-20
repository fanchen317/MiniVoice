import AppKit

/// Vector artwork inspired by the supplied MiniVoice brand reference.
/// The same paths drive the Dock icon and both menu bar variants.
enum BrandIcon {
    static func image(size: CGFloat, appIcon: Bool, monochrome: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            context.scaleBy(x: rect.width / 512, y: rect.height / 512)
            if appIcon {
                let background = NSBezierPath(roundedRect: NSRect(x: 24, y: 24, width: 464, height: 464), xRadius: 108, yRadius: 108)
                NSGradient(starting: NSColor(srgbRed: 0.70, green: 0.98, blue: 0.74, alpha: 1),
                           ending: NSColor(srgbRed: 0.25, green: 0.82, blue: 0.39, alpha: 1))?.draw(in: background, angle: 75)
                context.translateBy(x: 32, y: 32)
                context.scaleBy(x: 0.88, y: 0.88)
            }
            let ink = monochrome ? NSColor.black : (appIcon ? NSColor.white : NSColor(srgbRed: 0.26, green: 0.81, blue: 0.38, alpha: 1))
            ink.setFill(); ink.setStroke()
            let note = NSBezierPath()
            note.move(to: NSPoint(x: 166, y: 344))
            note.curve(to: NSPoint(x: 169, y: 316), controlPoint1: NSPoint(x: 185, y: 343), controlPoint2: NSPoint(x: 173, y: 326))
            note.line(to: NSPoint(x: 144, y: 204))
            note.curve(to: NSPoint(x: 166, y: 168), controlPoint1: NSPoint(x: 138, y: 183), controlPoint2: NSPoint(x: 145, y: 176))
            note.line(to: NSPoint(x: 340, y: 119))
            note.curve(to: NSPoint(x: 382, y: 139), controlPoint1: NSPoint(x: 364, y: 113), controlPoint2: NSPoint(x: 376, y: 117))
            note.curve(to: NSPoint(x: 427, y: 360), controlPoint1: NSPoint(x: 400, y: 208), controlPoint2: NSPoint(x: 423, y: 311))
            note.curve(to: NSPoint(x: 394, y: 419), controlPoint1: NSPoint(x: 434, y: 393), controlPoint2: NSPoint(x: 417, y: 412))
            note.curve(to: NSPoint(x: 326, y: 395), controlPoint1: NSPoint(x: 359, y: 434), controlPoint2: NSPoint(x: 333, y: 423))
            note.curve(to: NSPoint(x: 387, y: 335), controlPoint1: NSPoint(x: 315, y: 362), controlPoint2: NSPoint(x: 357, y: 337))
            note.curve(to: NSPoint(x: 392, y: 316), controlPoint1: NSPoint(x: 399, y: 336), controlPoint2: NSPoint(x: 396, y: 325))
            note.line(to: NSPoint(x: 365, y: 184))
            note.curve(to: NSPoint(x: 342, y: 167), controlPoint1: NSPoint(x: 362, y: 170), controlPoint2: NSPoint(x: 355, y: 165))
            note.line(to: NSPoint(x: 192, y: 207))
            note.curve(to: NSPoint(x: 182, y: 226), controlPoint1: NSPoint(x: 181, y: 210), controlPoint2: NSPoint(x: 179, y: 216))
            note.line(to: NSPoint(x: 207, y: 353))
            note.curve(to: NSPoint(x: 174, y: 429), controlPoint1: NSPoint(x: 215, y: 390), controlPoint2: NSPoint(x: 199, y: 417))
            note.curve(to: NSPoint(x: 111, y: 408), controlPoint1: NSPoint(x: 143, y: 445), controlPoint2: NSPoint(x: 116, y: 434))
            note.curve(to: NSPoint(x: 166, y: 344), controlPoint1: NSPoint(x: 101, y: 380), controlPoint2: NSPoint(x: 129, y: 346))
            note.close(); note.fill()
            func stroke(_ points: [NSPoint], width: CGFloat) {
                let path = NSBezierPath(); path.lineWidth = width; path.lineCapStyle = .round; path.lineJoinStyle = .round
                path.move(to: points[0]); for point in points.dropFirst() { path.line(to: point) }; path.stroke()
            }
            stroke([NSPoint(x: 224, y: 333), NSPoint(x: 218, y: 260), NSPoint(x: 251, y: 297), NSPoint(x: 263, y: 251), NSPoint(x: 287, y: 306)], width: 20)
            stroke([NSPoint(x: 298, y: 240), NSPoint(x: 331, y: 300), NSPoint(x: 351, y: 226)], width: 20)
            let swoosh = NSBezierPath(); swoosh.lineWidth = 15; swoosh.lineCapStyle = .round
            swoosh.move(to: NSPoint(x: 87, y: 389)); swoosh.curve(to: NSPoint(x: 104, y: 357), controlPoint1: NSPoint(x: 87, y: 376), controlPoint2: NSPoint(x: 94, y: 363)); swoosh.stroke()
            for (x, y, width, height, angle) in [(323.0, 53.0, 26.0, 46.0, -8.0), (369, 55, 27, 50, 32), (399, 103, 44, 26, -16)] {
                context.saveGState(); context.translateBy(x: x + width / 2, y: y + height / 2); context.rotate(by: angle * .pi / 180)
                NSBezierPath(ovalIn: NSRect(x: -width / 2, y: -height / 2, width: width, height: height)).fill(); context.restoreGState()
            }
            context.restoreGState()
            return true
        }
        image.isTemplate = monochrome
        return image
    }
}
