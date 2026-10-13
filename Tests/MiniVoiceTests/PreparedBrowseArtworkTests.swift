import AppKit
import XCTest
@testable import MiniVoice

final class PreparedBrowseArtworkTests: XCTestCase {
    @MainActor private func cover(_ color: NSColor, width: Int = 1200) -> Data {
        let image = NSImage(size: NSSize(width: width, height: 900), flipped: false) { rect in
            color.setFill(); rect.fill()
            NSColor.black.setFill(); CGRect(x: 40, y: 40, width: 100, height: 80).fill()
            return true
        }
        return NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
    }

    @MainActor func testPreparedCoverPersistsAndLoadsWithoutAudioOrDetailCache() async throws {
        let original = cover(.systemOrange, width: Int.random(in: 1100...1600))
        let key = try ResourceCache.saveArtwork(original)
        let browse = ResourceCache.url(key, kind: "Artwork/Browse")
        let detail = ResourceCache.url(key, kind: "Artwork/Detail")
        defer {
            for file in [browse, detail, ResourceCache.url(key, kind: "Artwork/List")] {
                try? FileManager.default.removeItem(at: file)
            }
        }
        let missingAudio = URL(fileURLWithPath: "/no-audio-\(UUID()).mp3")
        let firstWorker = BrowseArtworkWorker { _, _ in XCTFail("Valid detail should not need extraction"); return nil }
        let firstResult = await firstWorker.preparedData(key, source: missingAudio)
        let first = try XCTUnwrap(firstResult)
        XCTAssertEqual(try OnlineArtworkSearch.inspectedImage(first).width, 512)
        try FileManager.default.removeItem(at: detail)
        let freshWorker = BrowseArtworkWorker { _, _ in XCTFail("Prepared local cover must survive detail eviction"); return nil }
        let restoredResult = await freshWorker.preparedData(key, source: missingAudio)
        let restored = try XCTUnwrap(restoredResult)
        XCTAssertEqual(first, restored)
        let catalog = PreparedBrowseArtwork()
        catalog.replace([key: restored])
        XCTAssertEqual(catalog.image(key)?.size.width, 512)
    }

    @MainActor func testCatalogReflectsCoverReplacementAndRemoval() throws {
        let catalog = PreparedBrowseArtwork()
        let old = cover(.systemRed, width: 1100), new = cover(.systemBlue, width: 1500)
        let oldKey = ResourceCache.key(old), newKey = ResourceCache.key(new)
        catalog.replace([oldKey: old])
        XCTAssertEqual(catalog.image(oldKey)?.size.width, 1100)
        catalog.merge([newKey: new])
        XCTAssertEqual(catalog.image(newKey)?.size.width, 1500)
        catalog.replace([newKey: new])
        XCTAssertFalse(catalog.contains(oldKey))
        XCTAssertNil(catalog.image(oldKey))
        XCTAssertNotNil(catalog.image(newKey))
        catalog.replace([:])
        XCTAssertNil(catalog.image(newKey))
    }

    @MainActor func testCachedScanFinishesOnlyAfterHighResolutionArtworkIsPrepared() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PreparedScan-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = cover(.systemPink, width: Int.random(in: 1601...1900))
        let key = try ResourceCache.saveArtwork(original)
        var row = CachedTrack(track: Track(url: root.appendingPathComponent("song.mp3"), title: "Song",
                            artist: "Artist", album: "Album", lyrics: "", artwork: nil, duration: 10), root: root)
        row.artworkKey = key
        try PlaylistCache(recursive: true, tracks: [row]).write(root: root)
        let suite = "PreparedScan-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: PlaylistCache.indexURL(root: root))
            for kind in ["Artwork/List", "Artwork/Detail", "Artwork/Browse"] {
                try? FileManager.default.removeItem(at: ResourceCache.url(key, kind: kind))
            }
        }
        let library = MusicLibrary(defaults: defaults, scanOnLaunch: false)
        library.addFolders([root])
        for _ in 0..<300 where library.isImporting { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(library.isImporting)
        XCTAssertEqual(library.tracks.count, 1)
        XCTAssertTrue(PreparedBrowseArtwork.shared.contains(key))
        XCTAssertEqual(PreparedBrowseArtwork.shared.image(key)?.size.width, 512)
        let loader = ListArtworkLoader()
        loader.load(key: key, source: root.appendingPathComponent("song.mp3"), browse: true)
        XCTAssertEqual(loader.image?.size.width, 512, "First presentation must not wait for lazy loading")
    }
}
