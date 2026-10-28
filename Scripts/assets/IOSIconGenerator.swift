import AppKit

/// Export the shared vector mark on an opaque, full-bleed iOS background.
@main
struct IOSIconGenerator {
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let pixels = 1024
        let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        BrandIcon.image(size: CGFloat(pixels), appIcon: true, fullBleed: true)
            .draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
        try bitmap.representation(using: .png, properties: [:])!.write(to: output)
    }
}
