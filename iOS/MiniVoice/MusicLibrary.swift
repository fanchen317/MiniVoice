import AVFoundation
import Combine
import CoreFoundation
import CryptoKit
import Foundation
import UIKit

@MainActor
final class MusicLibrary: ObservableObject {
    @Published private(set) var folders: [MusicFolder] = []
    @Published private(set) var songs: [Song] = []
    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var recentIDs: [String] = []
    @Published private(set) var playlists: [MusicPlaylist] = []
    @Published private(set) var importedLyrics: [String: String] = [:]
    @Published var includesSubfolders = true {
        didSet { UserDefaults.standard.set(includesSubfolders, forKey: "includesSubfolders") }
    }
    @Published private(set) var isScanning = false
    @Published private(set) var scanCount = 0
    @Published var errorMessage: String?

    private var scanTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        folders = Self.decode([MusicFolder].self, key: "folders") ?? []
        songs = (try? Data(contentsOf: Self.indexURL)).flatMap { try? JSONDecoder().decode([Song].self, from: $0) } ?? []
        favorites = Set(defaults.stringArray(forKey: "favorites") ?? [])
        recentIDs = defaults.stringArray(forKey: "recentIDs") ?? []
        playlists = Self.decode([MusicPlaylist].self, key: "playlists") ?? []
        importedLyrics = (try? Data(contentsOf: Self.lyricsURL)).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        includesSubfolders = defaults.object(forKey: "includesSubfolders") as? Bool ?? true
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        defaults.set(try? encoder.encode(value), forKey: key)
    }

    private static var indexURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MiniVoice/library-index.json")
    }

    private static var lyricsURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MiniVoice/imported-lyrics.json")
    }

    private func saveIndex(_ songs: [Song]) {
        let destination = Self.indexURL
        guard let data = try? JSONEncoder().encode(songs) else { return }
        try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: destination, options: .atomic)
    }

    func restoreAndScan() { if !folders.isEmpty { rescan() } }

    func addFolder(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            let id = url.standardizedFileURL.path
            guard !folders.contains(where: { $0.id == id }) else { return }
            folders.append(MusicFolder(id: id, name: url.lastPathComponent, bookmark: bookmark))
            save(folders, key: "folders")
            rescan()
        } catch {
            errorMessage = "无法保存文件夹访问权限：\(error.localizedDescription)"
        }
    }

    func removeFolder(_ folder: MusicFolder) {
        folders.removeAll { $0.id == folder.id }
        save(folders, key: "folders")
        rescan()
    }

    func url(for song: Song) -> URL? {
        guard let root = folderURL(for: song) else { return nil }
        return root.appendingPathComponent(song.relativePath)
    }

    func folderURL(for song: Song) -> URL? {
        guard let folder = folders.first(where: { $0.id == song.folderID }) else { return nil }
        return LibraryScanner.resolve(folder)
    }

    func rescan() {
        scanTask?.cancel()
        let selectedFolders = folders
        let recursive = includesSubfolders
        isScanning = true
        scanCount = 0
        let worker = Task.detached(priority: .userInitiated) {
            LibraryScanner.scan(folders: selectedFolders, recursive: recursive)
        }
        scanTask = Task {
            let result = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled else { return }
            songs = result.songs.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            scanCount = songs.count
            isScanning = false
            saveIndex(songs)
            if !result.errors.isEmpty { errorMessage = result.errors.joined(separator: "\n") }
        }
    }

    func isFavorite(_ song: Song) -> Bool { favorites.contains(song.id) }

    func toggleFavorite(_ song: Song) {
        if !favorites.insert(song.id).inserted { favorites.remove(song.id) }
        defaults.set(Array(favorites), forKey: "favorites")
    }

    func clearArtworkCache() {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        rescan()
    }

    func lyrics(for song: Song?) -> String? {
        guard let song else { return nil }
        return importedLyrics[song.id] ?? song.lyrics
    }

    func importLyrics(from url: URL, for song: Song) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), data.count <= 1_048_576 else {
            errorMessage = "无法读取歌词文件，或文件超过 1 MB。"
            return
        }
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
                ?? String(data: data, encoding: gb18030),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "歌词文件为空或编码不受支持。"
            return
        }
        importedLyrics[song.id] = text
        let destination = Self.lyricsURL
        try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let stored = try? JSONEncoder().encode(importedLyrics) {
            try? stored.write(to: destination, options: .atomic)
        }
    }

    func recordPlayed(_ song: Song) {
        recentIDs.removeAll { $0 == song.id }
        recentIDs.insert(song.id, at: 0)
        recentIDs = Array(recentIDs.prefix(100))
        defaults.set(recentIDs, forKey: "recentIDs")
    }

    func createPlaylist(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        playlists.append(MusicPlaylist(id: UUID(), name: trimmed, songIDs: []))
        save(playlists, key: "playlists")
    }

    func deletePlaylist(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        save(playlists, key: "playlists")
    }

    func togglePlaylistSong(_ song: Song, playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        if let position = playlists[index].songIDs.firstIndex(of: song.id) {
            playlists[index].songIDs.remove(at: position)
        } else {
            playlists[index].songIDs.append(song.id)
        }
        save(playlists, key: "playlists")
    }
}

private enum LibraryScanner {
    static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "flac", "wav", "aiff", "aif", "caf"]

    static func resolve(_ folder: MusicFolder) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: folder.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    static func scan(folders: [MusicFolder], recursive: Bool) -> (songs: [Song], errors: [String]) {
        var songs: [Song] = []
        var errors: [String] = []
        var seenPaths = Set<String>()
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .contentModificationDateKey]
        for folder in folders {
            if Task<Never, Never>.isCancelled { break }
            guard let root = resolve(folder) else {
                errors.append("无法打开 \(folder.name)，请重新选择文件夹。")
                continue
            }
            let accessing = root.startAccessingSecurityScopedResource()
            defer { if accessing { root.stopAccessingSecurityScopedResource() } }
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles], errorHandler: { _, _ in true }) else {
                errors.append("无法读取 \(folder.name)。")
                continue
            }
            for case let url as URL in enumerator {
                if Task<Never, Never>.isCancelled { break }
                let values = try? url.resourceValues(forKeys: Set(keys))
                if values?.isDirectory == true {
                    if !recursive { enumerator.skipDescendants() }
                    continue
                }
                guard values?.isRegularFile == true,
                      audioExtensions.contains(url.pathExtension.lowercased()) else { continue }
                let rootPath = root.standardizedFileURL.path
                let path = url.standardizedFileURL.path
                guard path.hasPrefix(rootPath + "/") else { continue }
                guard seenPaths.insert(path).inserted else { continue }
                let relativePath = String(path.dropFirst(rootPath.count + 1))
                songs.append(readSong(url: url, folderID: folder.id, relativePath: relativePath, modified: values?.contentModificationDate))
            }
        }
        return (songs, errors)
    }

    private static func readSong(url: URL, folderID: String, relativePath: String, modified: Date?) -> Song {
        let asset = AVURLAsset(url: url)
        let metadata = asset.commonMetadata
        func common(_ key: String) -> String? {
            metadata.first { $0.commonKey?.rawValue == key }?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let stem = url.deletingPathExtension().lastPathComponent
        let parts = stem.components(separatedBy: " - ")
        let fallbackTitle = parts.count >= 3 ? parts.dropFirst(2).joined(separator: " - ") : stem
        let fallbackArtist = parts.count >= 3 ? parts[1] : "未知歌手"
        let title = common("title").flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTitle
        let artist = common("artist").flatMap { $0.isEmpty ? nil : $0 } ?? fallbackArtist
        let album = common("albumName").flatMap { $0.isEmpty ? nil : $0 } ?? "未知专辑"
        let duration = asset.duration.seconds
        let fingerprint = folderID + "/" + relativePath
        let imageName = SHA256.hash(data: Data((fingerprint + String(modified?.timeIntervalSince1970 ?? 0)).utf8))
            .map { String(format: "%02x", $0) }.joined() + ".jpg"
        let artworkFile = prepareArtwork(asset: asset, url: url, imageName: imageName)
        return Song(id: fingerprint, folderID: folderID, relativePath: relativePath,
                    title: title, artist: artist, album: album,
                    duration: duration.isFinite && duration > 0 ? duration : 0,
                    artworkFile: artworkFile, lyrics: readLyrics(asset: asset, url: url))
    }

    private static func cacheDirectory() -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func prepareArtwork(asset: AVURLAsset, url: URL, imageName: String) -> String? {
        let destination = cacheDirectory().appendingPathComponent(imageName)
        if FileManager.default.fileExists(atPath: destination.path) { return destination.path }
        var source = asset.commonMetadata.first { $0.commonKey?.rawValue == "artwork" }?.dataValue.flatMap(UIImage.init(data:))
        if source == nil {
            let parent = url.deletingLastPathComponent()
            let stem = url.deletingPathExtension().lastPathComponent
            for name in [stem, "cover", "folder", "front", "album"] {
                for ext in ["jpg", "jpeg", "png"] {
                    let candidate = parent.appendingPathComponent(name).appendingPathExtension(ext)
                    if let image = UIImage(contentsOfFile: candidate.path) { source = image; break }
                }
                if source != nil { break }
            }
        }
        guard let source else { return nil }
        let scale = min(1, 640 / max(source.size.width, source.size.height))
        let size = CGSize(width: max(1, source.size.width * scale), height: max(1, source.size.height * scale))
        let image = UIGraphicsImageRenderer(size: size).image { _ in source.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        try? data.write(to: destination, options: .atomic)
        return destination.path
    }

    private static func readLyrics(asset: AVURLAsset, url: URL) -> String? {
        let items = asset.availableMetadataFormats.flatMap { asset.metadata(forFormat: $0) }
        if let embedded = items.first(where: { item in
            let key = item.key.map { String(describing: $0).lowercased() } ?? ""
            let identifier = item.identifier?.rawValue.lowercased() ?? ""
            return key.contains("lyr") || key.contains("uslt") || identifier.contains("lyr") || identifier.contains("uslt")
        })?.stringValue, !embedded.isEmpty { return embedded }
        let stem = url.deletingPathExtension().lastPathComponent
        let parent = url.deletingLastPathComponent()
        let candidates = [parent.appendingPathComponent("lrc").appendingPathComponent(stem).appendingPathExtension("lrc"),
                          parent.appendingPathComponent(stem).appendingPathExtension("lrc")]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            guard let data = try? Data(contentsOf: candidate), data.count <= 1_048_576 else { continue }
            if let value = String(data: data, encoding: .utf8) { return value }
            if let value = String(data: data, encoding: .utf16) { return value }
            let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
            if let value = String(data: data, encoding: gb18030) { return value }
        }
        return nil
    }
}
