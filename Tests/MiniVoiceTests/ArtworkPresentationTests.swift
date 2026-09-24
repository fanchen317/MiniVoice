import AppKit
import XCTest
@testable import MiniVoice

final class ArtworkPresentationTests: XCTestCase {
    private func artwork(content: CGRect?) -> NSImage {
        let context = CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
        if let content {
            context.setFillColor(NSColor.red.cgColor)
            context.fill(content)
        }
        return NSImage(cgImage: context.makeImage()!, size: NSSize(width: 128, height: 128))
    }

    func testPairedWhiteMarginsRemovedWithoutCroppingContent() {
        let portrait = ArtworkPresentation.removingWhiteMargins(artwork(content: CGRect(x: 20, y: 0, width: 88, height: 128)))
        XCTAssertEqual(portrait.size.width, 88)
        XCTAssertEqual(portrait.size.height, 128)
        let landscape = ArtworkPresentation.removingWhiteMargins(artwork(content: CGRect(x: 0, y: 20, width: 128, height: 88)))
        XCTAssertEqual(landscape.size.width, 128)
        XCTAssertEqual(landscape.size.height, 88)
    }

    func testAmbiguousAndWhiteCoversAreUnchanged() {
        for rect in [nil, CGRect(x: 0, y: 0, width: 128, height: 128), CGRect(x: 20, y: 0, width: 108, height: 128)] {
            let source = artwork(content: rect)
            XCTAssertTrue(ArtworkPresentation.removingWhiteMargins(source) === source)
        }
    }
}
