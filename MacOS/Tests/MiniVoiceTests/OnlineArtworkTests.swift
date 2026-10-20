import XCTest
import ImageIO
@testable import MiniVoice

final class OnlineArtworkTests: XCTestCase {
    func testAppleUsesLargeArtworkAndValidatesImageHost() throws {
        let payload = Data(#"{"results":[{"collectionId":1,"collectionName":"Album","artistName":"Artist","artworkUrl100":"http://is1-ssl.mzstatic.com/image/thumb/Music/cover/100x100bb.jpg"},{"collectionId":2,"collectionName":"Other","artistName":"Artist","artworkUrl100":"https://example.com/100x100bb.jpg"}]}"#.utf8)
        let result = try XCTUnwrap(OnlineArtworkSearch.parseApple(payload).first)
        XCTAssertEqual(try OnlineArtworkSearch.parseApple(payload).count, 1)
        XCTAssertEqual(result.imageURL.absoluteString, "https://is1-ssl.mzstatic.com/image/thumb/Music/cover/3000x3000bb.jpg")
        XCTAssertEqual(result.score(album: "album", artist: "artist"), 160)
    }

    func testNetEaseUsesOriginalInsteadOfThumbnail() throws {
        let payload = Data(#"{"code":200,"result":{"albums":[{"id":1,"name":"专辑","artist":{"name":"歌手"},"picUrl":"http://p1.music.126.net/path/cover.jpg?param=100y100"}]}}"#.utf8)
        let result = try XCTUnwrap(OnlineArtworkSearch.parseNetEase(payload).first)
        XCTAssertEqual(result.imageURL.absoluteString, "https://p1.music.126.net/path/cover.jpg")
        XCTAssertTrue(result.thumbnailURL.absoluteString.contains("param=160y160"))
        XCTAssertEqual(result.artist, "歌手")
        XCTAssertThrowsError(try OnlineArtworkSearch.parseNetEase(Data(#"{"code":403}"#.utf8)))
    }

    func testReportsActualPixelsAndRejectsNonImageData() throws {
        let pixels = Data(repeating: 255, count: 8 * 6 * 4)
        let provider = try XCTUnwrap(CGDataProvider(data: pixels as CFData))
        let image = try XCTUnwrap(CGImage(width: 8, height: 6, bitsPerComponent: 8, bitsPerPixel: 32,
                                       bytesPerRow: 8 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let downloaded = try OnlineArtworkSearch.inspectedImage(data as Data)
        XCTAssertEqual(downloaded.width, 8)
        XCTAssertEqual(downloaded.height, 6)
        XCTAssertThrowsError(try OnlineArtworkSearch.inspectedImage(Data("<html>Not an image</html>".utf8)))
    }

    func testLiveHighResolutionArtworkWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["MINIVOICE_TEST_ONLINE"] == "1" else {
            throw XCTSkip("Set MINIVOICE_TEST_ONLINE=1 to query public cover services")
        }
        let results = try await OnlineArtworkSearch.search(title: "Numb", artist: "Linkin Park", album: "Meteora")
        XCTAssertEqual(Set(results.map(\.id)).count, results.count)
        for source in ["Apple Music", "网易云", "QQ 音乐", "酷狗音乐"] {
            let candidate = try XCTUnwrap(results.first { $0.source == source })
            let image = try await OnlineArtworkSearch.download(candidate)
            // Some QQ releases have a 700px original; verify we downloaded the
            // original rather than promising pixels the source does not have.
            if source == "QQ 音乐" { XCTAssertGreaterThan(min(image.width, image.height), 180) }
            else { XCTAssertGreaterThanOrEqual(min(image.width, image.height), 1000) }
            print("COVER: \(source) \(candidate.album) \(image.width)×\(image.height)")
        }
    }
}
