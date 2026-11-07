import AppKit

// Export the existing vector brand to Windows ICO/DIB frames; no artwork fork.
@main
struct WindowsIconGenerator {
    static func main() throws {
        let sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
        func u16(_ value: Int) -> Data {
            var number = UInt16(value).littleEndian
            return withUnsafeBytes(of: &number) { Data($0) }
        }
        func u32(_ value: Int) -> Data {
            var number = UInt32(value).littleEndian
            return withUnsafeBytes(of: &number) { Data($0) }
        }
        var frames: [Data] = []
        for size in sizes {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                          colorSpaceName: .deviceRGB, bytesPerRow: size * 4, bitsPerPixel: 32)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            BrandIcon.image(size: CGFloat(size), appIcon: true).draw(in: NSRect(x: 0, y: 0, width: size, height: size))
            NSGraphicsContext.restoreGraphicsState()
            let maskStride = ((size + 31) / 32) * 4
            var dib = u32(40) + u32(size) + u32(size * 2) + u16(1) + u16(32)
            dib += u32(0) + u32(size * size * 4 + maskStride * size)
            dib += u32(0) + u32(0) + u32(0) + u32(0)
            var mask = Data(repeating: 0, count: maskStride * size)
            for y in (0..<size).reversed() {
                for x in 0..<size {
                    let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                    func byte(_ value: CGFloat) -> UInt8 { UInt8(max(0, min(255, (value * 255).rounded()))) }
                    dib.append(contentsOf: [byte(color.blueComponent), byte(color.greenComponent), byte(color.redComponent), byte(color.alphaComponent)])
                    if color.alphaComponent == 0 {
                        mask[(size - 1 - y) * maskStride + x / 8] |= UInt8(0x80 >> (x % 8))
                    }
                }
            }
            dib += mask
            frames.append(dib)
        }
        var result = u16(0) + u16(1) + u16(sizes.count)
        var offset = 6 + sizes.count * 16
        for (size, frame) in zip(sizes, frames) {
            result.append(contentsOf: [UInt8(size % 256), UInt8(size % 256), 0, 0])
            result += u16(1) + u16(32) + u32(frame.count) + u32(offset)
            offset += frame.count
        }
        for frame in frames { result += frame }
        try result.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
    }
}
