import AppKit
// Android's no-background system icon canvas is 288dp. Render the same
// 88dp visible mark as the native loading page, at xxxhdpi (4x).
let source = NSImage(contentsOfFile: CommandLine.arguments[1])!
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1152, pixelsHigh: 1152, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: 1152, height: 1152).fill(using: .copy)
source.draw(in: NSRect(x: 400, y: 400, width: 352, height: 352))
NSGraphicsContext.restoreGraphicsState()
// Guard the actual exported alpha geometry, not just XML dimensions.
precondition(bitmap.colorAt(x: 0, y: 0)!.alphaComponent == 0)
precondition(bitmap.colorAt(x: 400, y: 400)!.alphaComponent == 0)
precondition(bitmap.colorAt(x: 576, y: 576)!.alphaComponent > 0.99)
precondition(bitmap.pixelsWide == 1152 && bitmap.pixelsHigh == 1152)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
