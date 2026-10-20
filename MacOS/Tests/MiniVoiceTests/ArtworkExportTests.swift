import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import MiniVoice

final class ArtworkExportTests: XCTestCase {
    private func image() -> NSImage {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 384,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = NSSize(width: 128, height: 96)
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }

    func testLocalCoverExportPreservesPixelsInsteadOfPreviewSize() throws {
        let export = try ArtworkExport(image: image())
        let url = try export.fileURL(name: "Album / Cover: Test")
        let saved = try Data(contentsOf: url)
        let inspected = try OnlineArtworkSearch.inspectedImage(saved)
        XCTAssertEqual(inspected.width, 512)
        XCTAssertEqual(inspected.height, 384)
        XCTAssertEqual(url.pathExtension, "png")
        XCTAssertEqual(url.lastPathComponent, "Album Cover Test.png")
        XCTAssertEqual(try export.fileURL(name: "Album / Cover: Test"), url)
    }

    @MainActor func testOnlineCopyPreservesOriginalBytesAndSupportsImageAndFilePaste() throws {
        let bitmap = NSBitmapImageRep(data: image().tiffRepresentation!)!
        let original = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
        let export = try ArtworkExport(image: NSImage(data: original)!, originalData: original)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        try export.copy(name: "高清封面", to: pasteboard)
        XCTAssertEqual(pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.jpeg.identifier)), original)
        XCTAssertNotNil(pasteboard.data(forType: .tiff))
        let file = try XCTUnwrap(pasteboard.string(forType: .fileURL).flatMap(URL.init(string:)))
        XCTAssertEqual(file.pathExtension, "jpeg")
        XCTAssertEqual(try Data(contentsOf: file), original)
        XCTAssertFalse(pasteboard.readObjects(forClasses: [NSImage.self])?.isEmpty ?? true)
        XCTAssertFalse(pasteboard.readObjects(forClasses: [NSURL.self])?.isEmpty ?? true)
    }

    func testDragProvidesRealFileAndFullImageData() async throws {
        let export = try ArtworkExport(image: image())
        let provider = try export.itemProvider(name: "拖拽封面")
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(UTType.png.identifier))
        let loaded: Data = try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? ArtworkExport.ExportError.invalidImage) }
            }
        }
        XCTAssertEqual(loaded, export.data)
        let file: URL = try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.png.identifier) { url, error in
                if let url {
                    do {
                        let fileData = try Data(contentsOf: url)
                        XCTAssertEqual(fileData, export.data)
                        continuation.resume(returning: url)
                    } catch { continuation.resume(throwing: error) }
                } else { continuation.resume(throwing: error ?? ArtworkExport.ExportError.invalidImage) }
            }
        }
        XCTAssertEqual(file.pathExtension, "png")
    }
}
