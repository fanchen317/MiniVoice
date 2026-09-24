import AppKit

/// Display-only cleanup: never changes embedded artwork or files on disk.
enum ArtworkPresentation {
    @MainActor private static let cache = NSCache<NSImage, NSImage>()

    @MainActor static func image(for source: NSImage) -> NSImage {
        if let cached = cache.object(forKey: source) { return cached }
        let result = removingWhiteMargins(source)
        cache.countLimit = 160
        cache.setObject(result, forKey: source)
        return result
    }

    static func removingWhiteMargins(_ source: NSImage) -> NSImage {
        guard let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return source }
        let side = 128
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard rendered else { return source }
        func white(_ x: Int, _ y: Int) -> Bool {
            let i = (y * side + x) * 4
            let rgb = [pixels[i], pixels[i + 1], pixels[i + 2]]
            return pixels[i + 3] > 250 && rgb.min()! >= 238 && Int(rgb.max()!) - Int(rgb.min()!) <= 10
        }
        func column(_ x: Int) -> Bool { (0..<side).allSatisfy { white(x, $0) } }
        func row(_ y: Int) -> Bool { (0..<side).allSatisfy { white($0, y) } }
        var left = 0, right = 0, top = 0, bottom = 0
        while left < side / 3 && column(left) { left += 1 }
        while right < side / 3 && column(side - 1 - right) { right += 1 }
        while top < side / 3 && row(top) { top += 1 }
        while bottom < side / 3 && row(side - 1 - bottom) { bottom += 1 }
        // Only substantial, paired, approximately symmetrical margins qualify.
        // Reject all-white art and ambiguous edges rather than cropping content.
        if left < 4 || right < 4 || abs(left - right) > 3 || left >= side / 3 || right >= side / 3 {
            left = 0; right = 0
        }
        if top < 4 || bottom < 4 || abs(top - bottom) > 3 || top >= side / 3 || bottom >= side / 3 {
            top = 0; bottom = 0
        }
        guard left + right + top + bottom > 0 else { return source }
        let rect = CGRect(x: CGFloat(left) / CGFloat(side) * CGFloat(cg.width),
                          y: CGFloat(top) / CGFloat(side) * CGFloat(cg.height),
                          width: CGFloat(side - left - right) / CGFloat(side) * CGFloat(cg.width),
                          height: CGFloat(side - top - bottom) / CGFloat(side) * CGFloat(cg.height)).integral
        guard let cropped = cg.cropping(to: rect) else { return source }
        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    }
}
