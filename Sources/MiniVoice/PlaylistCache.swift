import AppKit
import Foundation

struct CachedTrack: Codable, Sendable {
    var path: String
    var title: String
    var artist: String
    var album: String
    var lyrics: String
    var duration: Double
    var artwork: Data?

    @MainActor init(track: Track, root: URL) {
        path = String(track.url.path.dropFirst(root.path.count + 1))
        title = track.title; artist = track.artist; album = track.album; lyrics = track.lyrics; duration = track.duration
        if let image = track.artwork {
            let side = 256
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
            NSGraphicsContext.restoreGraphicsState()
            artwork = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        }
    }

    @MainActor func track(root: URL) -> Track? {
        guard !path.hasPrefix("/"), !path.split(separator: "/").contains(".."), duration.isFinite, duration > 0 else { return nil }
        return Track(url: root.appendingPathComponent(path), title: title, artist: artist, album: album, lyrics: lyrics,
                     artwork: artwork.flatMap(NSImage.init(data:)), duration: duration)
    }
}

struct PlaylistCache: Codable, Sendable {
    static let filename = ".minivoice-playlist.json"
    var version = 1
    var recursive: Bool
    var updatedAt = Date()
    var tracks: [CachedTrack]

    static func read(root: URL, recursive: Bool) throws -> PlaylistCache {
        let cache = try JSONDecoder().decode(Self.self, from: Data(contentsOf: root.appendingPathComponent(filename)))
        guard cache.version == 1, cache.recursive == recursive else { throw CocoaError(.fileReadCorruptFile) }
        return cache
    }
    func write(root: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: root.appendingPathComponent(Self.filename), options: .atomic)
    }
}
