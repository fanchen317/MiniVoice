import AppKit
import Foundation
import CryptoKit

struct FileStamp: Codable, Sendable, Equatable {
    let size: Int64
    let modified: Double
    static func read(_ url: URL) -> Self? {
        guard let a = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = a[.size] as? NSNumber, let date = a[.modificationDate] as? Date else { return nil }
        return Self(size: size.int64Value, modified: date.timeIntervalSince1970)
    }
}

struct CachedTrack: Codable, Sendable {
    var path: String
    var title: String
    var artist: String
    var album: String
    var lyrics: String?
    var duration: Double
    var artwork: Data?
    var artworkKey: String?
    var lyricsKey: String?
    var stamp: FileStamp?
    var sidecarStamp: FileStamp?

    @MainActor init(track: Track, root: URL, includeArtwork: Bool = true) {
        path = String(track.url.path.dropFirst(root.path.count + 1))
        title = track.title; artist = track.artist; album = track.album; duration = track.duration
        lyrics = track.resourcesLoaded ? track.lyrics : nil
        artwork = track.resourcesLoaded && includeArtwork ? track.artwork?.tiffRepresentation : nil
        artworkKey = track.resourcesLoaded && track.artwork == nil ? nil : track.artworkKey
        lyricsKey = track.lyricsKey
        // Copying a lightweight index row must not certify stale metadata as fresh.
        stamp = track.resourcesLoaded ? FileStamp.read(track.url) : track.sourceStamp
        sidecarStamp = track.resourcesLoaded ? FileStamp.read(LyricsStorage.sidecarURL(for: track.url)) : track.lyricSourceStamp
    }

    /// Avoid full-cover TIFF encoding on the UI thread when selecting/scanning a song.
    @MainActor static func snapshot(track: Track, root: URL) async throws -> CachedTrack {
        let metadata = CachedTrack(track: track, root: root, includeArtwork: false)
        guard track.resourcesLoaded, let image = track.artwork else { return metadata }
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw TagWriteError.artworkEncodingFailed }
        let transferable = CachedArtwork(cg)
        return try await Task.detached {
            var result = metadata
            guard let data = NSBitmapImageRep(cgImage: transferable.image).representation(using: .png, properties: [:]) else {
                throw TagWriteError.artworkEncodingFailed
            }
            result.artwork = data
            return result
        }.value
    }

    @MainActor func track(root: URL) -> Track? {
        guard !path.hasPrefix("/"), !path.split(separator: "/").contains(".."), duration.isFinite, duration > 0 else { return nil }
        let url = root.appendingPathComponent(path)
        var track = Track(id: ResourceCache.trackID(url), url: url, title: title, artist: artist, album: album,
                          lyrics: "", artwork: nil, duration: duration)
        track.artworkKey = artworkKey; track.lyricsKey = lyricsKey; track.resourcesLoaded = false
        track.sourceStamp = stamp; track.lyricSourceStamp = sidecarStamp
        return track
    }

    func isCurrent(root: URL) -> Bool {
        let url = root.appendingPathComponent(path)
        return stamp != nil && stamp == FileStamp.read(url)
            && sidecarStamp == FileStamp.read(LyricsStorage.sidecarURL(for: url))
    }
    mutating func splitResources(previewOnly: Bool = false) throws {
        if let artwork { artworkKey = try ResourceCache.saveArtwork(artwork, includeDetail: !previewOnly) }
        if let lyrics { lyricsKey = try ResourceCache.saveLyrics(lyrics) }
        artwork = nil; lyrics = nil
    }
}

struct PlaylistCache: Codable, Sendable {
    static let filename = ".minivoice-playlist.json"
    var version = 2
    var recursive: Bool
    var updatedAt = Date()
    var tracks: [CachedTrack]

    static func read(root: URL, recursive: Bool) throws -> PlaylistCache {
        try ResourceCache.withDiskLock {
            let url = indexURL(root: root)
            if FileManager.default.fileExists(atPath: url.path) {
                let cache = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
                guard cache.version == 2, cache.recursive == recursive else { throw CocoaError(.fileReadCorruptFile) }
                return cache.validated(root: root)
            }
            var legacy = try JSONDecoder().decode(Self.self, from: Data(contentsOf: root.appendingPathComponent(filename)))
            guard legacy.version == 1, legacy.recursive == recursive else { throw CocoaError(.fileReadCorruptFile) }
            for i in legacy.tracks.indices {
                try legacy.tracks[i].splitResources(previewOnly: true)
                let audio = root.appendingPathComponent(legacy.tracks[i].path)
                if let stamp = FileStamp.read(audio), stamp.modified <= legacy.updatedAt.timeIntervalSince1970 {
                    legacy.tracks[i].stamp = stamp
                }
                legacy.tracks[i].sidecarStamp = FileStamp.read(LyricsStorage.sidecarURL(for: audio))
            }
            legacy.version = 2
            try legacy.writeUnlocked(root: root)
            return legacy.validated(root: root)
        }
    }
    func write(root: URL) throws {
        try ResourceCache.withDiskLock { try writeUnlocked(root: root) }
    }
    static func indexURL(root: URL) -> URL {
        CacheStorage.indexes.appendingPathComponent("\(ResourceCache.key(root.path)).json")
    }
    private func validated(root: URL) -> Self {
        var result = self
        var seen = Set<String>()
        result.tracks = tracks.filter {
            !$0.path.hasPrefix("/") && !$0.path.split(separator: "/").contains("..")
                && $0.duration.isFinite && $0.duration > 0
                && seen.insert(root.appendingPathComponent($0.path).standardizedFileURL.path).inserted
        }
        return result
    }
    private func writeUnlocked(root: URL) throws {
        var cache = self
        cache.version = 2
        for i in cache.tracks.indices { try cache.tracks[i].splitResources() }
        try ResourceCache.atomicWrite(JSONEncoder().encode(cache), to: Self.indexURL(root: root))
    }
    @discardableResult
    static func update(root: URL, recursive: Bool, entry: CachedTrack) throws -> CachedTrack? {
        try ResourceCache.withDiskLock {
            // A late worker must neither certify an older file nor recreate a removed row.
            guard entry.isCurrent(root: root) else { return nil }
            var cache = try read(root: root, recursive: recursive)
            guard let i = cache.tracks.firstIndex(where: { $0.path == entry.path }) else { return nil }
            var saved = entry
            try saved.splitResources()
            guard entry.isCurrent(root: root) else { return nil }
            cache.tracks[i] = saved
            cache.updatedAt = Date()
            try cache.writeUnlocked(root: root)
            return saved
        }
    }
}
