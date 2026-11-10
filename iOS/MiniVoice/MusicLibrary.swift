import AVFoundation
import Combine
import CoreFoundation
import CryptoKit
import Foundation
import ImageIO
import Darwin
import UIKit
import MiniVoiceShared

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
    @Published private(set) var scanTotal = 0
    let scanSession = ScanBackgroundSession()
    @Published var errorMessage: String? {
        didSet { if let message = errorMessage, message != oldValue { IOSDiagnostics.shared.record(.failure, "library: " + message) } }
    }

    @Published private(set) var scanDetail = ""
    private var didRestore = false
    private var scanGeneration = UUID()
    private var maintenanceBusy = false
    private var inspectionGeneration = UUID()
    private var inspection: [String: Any] = ["running": false]
    private var aliases: [String: String] = [:]
    private var scanTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private lazy var indexWriter = LibraryIndexWriter(destination: Self.indexURL)
    private let folderAccess = FolderAccessRegistry()

    init() {
        folders = Self.decode([MusicFolder].self, key: "folders") ?? []
        songs = (try? Data(contentsOf: Self.indexURL)).flatMap { try? JSONDecoder().decode([Song].self, from: $0) } ?? []
        favorites = Set(defaults.stringArray(forKey: "favorites") ?? [])
        recentIDs = defaults.stringArray(forKey: "recentIDs") ?? []
        playlists = Self.decode([MusicPlaylist].self, key: "playlists") ?? []
        importedLyrics = (try? Data(contentsOf: Self.lyricsURL)).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        aliases = (try? Data(contentsOf: Self.aliasURL)).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        includesSubfolders = defaults.object(forKey: "includesSubfolders") as? Bool ?? true
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--mv-ui-fixture") {
            do { try prepareSimulatorFixture() } catch { errorMessage = "测试音乐生成失败：\(error.localizedDescription)" }
        }
        #endif
        folderAccess.update(bookmarks: folders.map { .init(id: $0.id, data: $0.bookmark) })
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

    nonisolated private static var checkpointURL: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MiniVoice/scan-checkpoint.json") }

    private static var aliasURL: URL { indexURL.deletingLastPathComponent().appendingPathComponent("artist-aliases.json") }
    static var artworkDirectory: URL { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Artwork", isDirectory: true) }

    private static var lyricsURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MiniVoice/imported-lyrics.json")
    }

    private func saveIndex(_ songs: [Song]) async throws {
        try await indexWriter.save { try JSONEncoder().encode(songs) }
    }

    func restoreAndScan() {
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--mv-ui-fixture") { return }
        #endif
        guard !didRestore || defaults.bool(forKey: "ios.scan.pending") && !isScanning else { return }
        didRestore = true
        if !folders.isEmpty { rescan(userInitiated: false) }
    }

    func addFolder(_ url: URL) {
        let local = folderAccess.isInsideLocalContainer(url)
        let accessing = !local && url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            guard local || accessing else { throw FolderAccessRegistry.Failure.denied }
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            let id = url.standardizedFileURL.path
            let folder = MusicFolder(id: id, name: url.lastPathComponent, bookmark: bookmark)
            if let index = folders.firstIndex(where: { $0.id == id }) { folders[index] = folder }
            else { folders.append(folder) }
            save(folders, key: "folders")
            folderAccess.update(bookmarks: folders.map { .init(id: $0.id, data: $0.bookmark) }, retryFailures: true)
            rescan()
        } catch {
            errorMessage = "无法保存文件夹访问权限：\(error.localizedDescription)"
        }
    }

    func removeFolder(_ folder: MusicFolder) {
        folders.removeAll { $0.id == folder.id }
        save(folders, key: "folders")
        folderAccess.update(bookmarks: folders.map { .init(id: $0.id, data: $0.bookmark) })
        rescan()
    }

    func folderAccessRequest(for song: Song) -> FolderAccessRegistry.Request? {
        guard let folder = folders.first(where: { $0.id == song.folderID }) else { return nil }
        return folderAccess.request(id: folder.id, bookmark: folder.bookmark)
    }

    func rescan() { rescan(userInitiated: true) }

    func rescan(userInitiated: Bool) {
        guard !maintenanceBusy else { errorMessage = "正在维护缓存，请稍后重扫"; return }
        if userInitiated { folderAccess.retryFailures() }
        let access = folderAccess
        let precedingScan = scanTask
        precedingScan?.cancel()
        inspectionGeneration = UUID()
        inspection = ["running": false, "checked": 0, "total": 0, "unavailable": [[String: String]]()]
        let generation = UUID()
        scanGeneration = generation
        let selectedFolders = folders
        let previous = songs
        let recursive = includesSubfolders
        IOSDiagnostics.shared.record(.event, "scan started folders=\(selectedFolders.count) recursive=\(recursive)")
        isScanning = true; scanCount = 0; scanTotal = 0; scanDetail = "正在查找音乐文件…"
        defaults.set(true, forKey: "ios.scan.pending")
        scanSession.begin(generation, userInitiated: userInitiated) { [weak self] in
            guard let self, self.scanGeneration == generation else { return }
            self.scanTask?.cancel(); self.isScanning = false
            self.scanDetail = "扫描已暂停，返回应用后可继续"
            IOSDiagnostics.shared.record(.event, "scan system execution expired or cancelled")
        }
        scanTask = Task {
            // Cancellation is cooperative; wait for the old file read to release its buffers.
            await precedingScan?.value
            guard !Task.isCancelled, scanGeneration == generation else { return }
            let worker = Task.detached(priority: .utility) { [weak self] in
                let checkpoint = (try? Data(contentsOf: Self.checkpointURL)).flatMap { try? JSONDecoder().decode([Song].self, from: $0) } ?? []
                return LibraryScanner.scan(folders: selectedFolders, recursive: recursive, previous: checkpoint + previous, access: access, checkpoint: { rows in
                    if let data = try? JSONEncoder().encode(rows) {
                        try? FileManager.default.createDirectory(at: Self.checkpointURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try? data.write(to: Self.checkpointURL, options: .atomic)
                    }
                }) { count, total, detail in
                    Task { @MainActor [weak self] in
                        guard let self, self.scanGeneration == generation, self.isScanning else { return }
                        self.scanCount = count; self.scanTotal = total; self.scanDetail = detail
                        self.scanSession.update(completed: count, total: total, detail: detail)
                    }
                }
            }
            let result = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled, scanGeneration == generation else { return }
            do { songs = try applyingAliases(result.songs).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } }
            catch { errorMessage = "歌手归并失败：\(error.localizedDescription)"; songs = result.songs }
            scanCount = songs.count; isScanning = false; scanDetail = "扫描完成 · \(songs.count) 首歌曲"
            IOSDiagnostics.shared.record(.event, "scan completed songs=\(songs.count) errors=\(result.errors.count)")
            do {
                try await saveIndex(songs)
                guard scanGeneration == generation else { return }
                defaults.set(false, forKey: "ios.scan.pending")
                // Keep this tiny unlink adjacent to the generation check; a new scan must not publish
                // a checkpoint between the check and deletion. Encoding and large writes run off-main.
                try? FileManager.default.removeItem(at: Self.checkpointURL)
            } catch {
                guard scanGeneration == generation else { return }
                errorMessage = "音乐索引保存失败：\(error.localizedDescription)"
                scanSession.finish(success: false, notify: true)
                return
            }
            guard scanGeneration == generation else { return }
            scanSession.update(completed: songs.count, total: max(scanTotal, songs.count), detail: scanDetail, force: true)
            scanSession.finish(success: result.errors.isEmpty, notify: true)
            errorMessage = result.errors.isEmpty ? nil : result.errors.joined(separator: "\n")
        }
    }

    func isFavorite(_ song: Song) -> Bool { favorites.contains(song.id) }

    func toggleFavorite(_ song: Song) {
        if !favorites.insert(song.id).inserted { favorites.remove(song.id) }
        defaults.set(Array(favorites), forKey: "favorites")
    }

    func clearArtworkCache() {
        Task {
            do { _ = try await sharedMaintenanceAction("clearCache", payload: [:]) }
            catch { errorMessage = "无法清理缓存：\(error.localizedDescription)" }
        }
    }

    func lyrics(for song: Song?) -> String? {
        guard let song else { return nil }
        return importedLyrics[song.id] ?? song.lyrics
    }

    func importLyrics(from url: URL, for song: Song) {
        let local = folderAccess.isInsideLocalContainer(url)
        let accessing = !local && url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard local || accessing else { errorMessage = "歌词文件授权不可用，请重新选择文件。"; return }
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
    static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "flac", "wav", "aiff", "aif", "caf", "ogg", "opus"]

    private static func withAuthorizedSong<T>(_ song: Song, lease: FolderAccessRegistry.Lease, body: (URL, URL) throws -> T) throws -> T {
        let file = try lease.file(relativePath: song.relativePath)
        var outcome: Result<T, Error>?, coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: file, options: [], error: &coordinationError) { readable in
            outcome = Result { try lease.checkValidity(); return try body(readable, lease.rootURL) }
        }
        if let coordinationError { throw coordinationError }
        try lease.checkValidity()
        guard let outcome else { throw CocoaError(.fileReadUnknown) }
        return try outcome.get()
    }

    static func artworkData(song: Song, folder: MusicFolder, original: Bool, access: FolderAccessRegistry, generation: UInt64? = nil) throws -> Data {
        let path = original ? (song.originalArtworkFile ?? song.artworkFile.map { $0 + ".original" }) : song.artworkFile
        let revision = generation ?? ArtworkDiskCache.shared.generation
        // Generated bytes are already inside the app's cache. A wall hit must not resolve or consume
        // the external directory's bookmark; MusicLibrary still checks current folder membership.
        return try access.request(id: folder.id, bookmark: folder.bookmark).read(cached: {
            path.flatMap { ArtworkDiskCache.shared.read(URL(fileURLWithPath: $0).standardizedFileURL) }
        }, load: { lease in
            try withAuthorizedSong(song, lease: lease) { file, root in
                try sourceArtworkData(song: song, file: file, root: root, original: original, generation: revision)
            }
        })
    }

    private static func sourceArtworkData(song: Song, file: URL, root: URL, original: Bool, generation: UInt64) throws -> Data {
        let thumbnail = song.artworkFile
        let path = original ? (song.originalArtworkFile ?? thumbnail.map { $0 + ".original" }) : thumbnail
        if let path {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            if let cached = ArtworkDiskCache.shared.read(url) { return cached }
            // Dedicated fixture source covers are read only within their registry-authorized root.
            if url.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/"),
               let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 32 * 1024 * 1024 {
                return try Data(contentsOf: url, options: .mappedIfSafe)
            }
        }
        let name = thumbnail.map { URL(fileURLWithPath: $0).lastPathComponent } ?? SHA256.hash(data: Data((song.id + (song.cacheVersion ?? "")).utf8)).map { String(format: "%02x", $0) }.joined() + ".jpg"
        var extracted: Data?
        let recovered = autoreleasepool {
            let isFLAC = file.pathExtension.lowercased() == "flac"
            return prepareArtwork(asset: isFLAC ? nil : AVURLAsset(url: file), url: file, root: root, imageName: name, flac: isFLAC ? try? FLACMetadata.read(file) : nil, retainOriginal: original, generation: generation) { thumbnail, source in extracted = original ? source : thumbnail }
        }
        if let extracted { return extracted }
        guard let recovered,
              let bytes = ArtworkDiskCache.shared.read(URL(fileURLWithPath: recovered + (original ? ".original" : ""))) else { throw CocoaError(.fileNoSuchFile) }
        return bytes
    }

    static func wallArtworkData(song: Song, folder: MusicFolder, card: Bool, access: FolderAccessRegistry, generation: UInt64? = nil) throws -> Data {
        let revision = generation ?? ArtworkDiskCache.shared.generation
        let pixels = card ? 960 : 320
        let key = SHA256.hash(data: Data((song.id + (song.cacheVersion ?? "") + "wall-v1-\(pixels)").utf8)).map { String(format: "%02x", $0) }.joined()
        let destination = cacheDirectory().appendingPathComponent("wall-" + key + ".jpg")
        return try access.request(id: folder.id, bookmark: folder.bookmark).read(cached: {
            ArtworkDiskCache.shared.read(destination)
        }, load: { lease in
            try withAuthorizedSong(song, lease: lease) { file, root in
                try autoreleasepool {
                    let data = try sourceArtworkData(song: song, file: file, root: root, original: card, generation: revision)
                    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: pixels, kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
                          let result = UIImage(cgImage: image).jpegData(compressionQuality: 0.82) else { throw CocoaError(.fileReadCorruptFile) }
                    _ = try? ArtworkDiskCache.shared.write(result, to: destination, generation: revision)
                    return result
                }
            }
        })
    }

    static func displayArtworkData(song: Song, folder: MusicFolder, access: FolderAccessRegistry, generation: UInt64? = nil) throws -> Data {
        let revision = generation ?? ArtworkDiskCache.shared.generation
        let key = SHA256.hash(data: Data((song.id + (song.cacheVersion ?? "") + "display-2048-v1").utf8)).map { String(format: "%02x", $0) }.joined()
        let destination = cacheDirectory().appendingPathComponent("display-" + key + ".jpg")
        return try access.request(id: folder.id, bookmark: folder.bookmark).read(cached: {
            ArtworkDiskCache.shared.read(destination)
        }, load: { lease in
            try withAuthorizedSong(song, lease: lease) { file, root in
                try autoreleasepool {
                    let data = try sourceArtworkData(song: song, file: file, root: root, original: true, generation: revision)
                    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 2048, kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
                          let result = UIImage(cgImage: image).jpegData(compressionQuality: 0.9) else { throw CocoaError(.fileReadCorruptFile) }
                    _ = try? ArtworkDiskCache.shared.write(result, to: destination, generation: revision)
                    return result
                }
            }
        })
    }

    static func scan(folders: [MusicFolder], recursive: Bool, previous: [Song], access: FolderAccessRegistry, checkpoint: ([Song]) -> Void = { _ in }, progress: (Int, Int, String) -> Void) -> (songs: [Song], errors: [String]) {
        let old = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var songs: [Song] = [], errors: [String] = []
        var seenPaths = Set<String>(), failedFolders = Set<String>()
        var scoped: [String: FolderAccessRegistry.Lease] = [:]
        var candidates: [(url: URL, root: URL, folderID: String)] = []
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .contentModificationDateKey, .creationDateKey, .fileSizeKey]
        defer { for lease in scoped.values { lease.close() } }
        for folder in folders {
            if Task<Never, Never>.isCancelled { break }
            let lease: FolderAccessRegistry.Lease
            do { lease = try access.request(id: folder.id, bookmark: folder.bookmark).acquire() }
            catch { failedFolders.insert(folder.id); errors.append("无法打开 \(folder.name)：\(error.localizedDescription)"); continue }
            scoped[folder.id] = lease
            let root = lease.rootURL
            var enumerationError = false
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles], errorHandler: { _, _ in enumerationError = true; return true }) else { failedFolders.insert(folder.id); errors.append("无法读取 \(folder.name)。"); continue }
            for case let url as URL in enumerator {
                if Task<Never, Never>.isCancelled { break }
                guard (try? lease.checkValidity()) != nil else { failedFolders.insert(folder.id); enumerationError = true; break }
                autoreleasepool {
                    let values = try? url.resourceValues(forKeys: Set(keys))
                    if values?.isDirectory == true { if !recursive { enumerator.skipDescendants() }; return }
                    guard values?.isRegularFile == true, audioExtensions.contains(url.pathExtension.lowercased()),
                          url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/"), seenPaths.insert(url.standardizedFileURL.path).inserted else { return }
                    candidates.append((url, root, folder.id))
                    if candidates.count == 1 || candidates.count % 100 == 0 { progress(candidates.count, 0, "正在查找音乐 · 已发现 \(candidates.count) 首") }
                }
            }
            if enumerationError { failedFolders.insert(folder.id); errors.append("部分目录无法读取，请检查 \(folder.name) 的授权或下载状态。") }
        }
        progress(0, candidates.count, "正在读取歌曲、歌词与封面")
        var lastProgress = Date.distantPast
        for (index, item) in candidates.enumerated() {
            if Task<Never, Never>.isCancelled { break }
            guard let lease = scoped[item.folderID], (try? lease.checkValidity()) != nil else {
                if failedFolders.insert(item.folderID).inserted { errors.append("音乐文件夹授权已变化，请重扫或重新选择文件夹。") }
                continue
            }
            guard item.url.resolvingSymlinksInPath().path.hasPrefix(item.root.resolvingSymlinksInPath().path + "/") else { continue }
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--mv-scan-timing-test") { Thread.sleep(forTimeInterval: 1) }
            #endif
            let song: Song = autoreleasepool {
                let url = item.url, root = item.root
                let values = try? url.resourceValues(forKeys: Set(keys))
                let relative = String(url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
                let identity = item.folderID + "/" + relative
                let modified = values?.contentModificationDate
                let version = cacheVersion(url: url, root: root, modified: modified, size: values?.fileSize ?? 0)
                if var cached = old[identity], cached.cacheVersion == version {
                    cached.artist = cached.originalArtist ?? cached.artist; return cached
                }
                var song = readSong(url: url, root: root, folderID: item.folderID, relativePath: relative, version: version)
                song.sourceAdded = old[identity]?.sourceAdded ?? (values?.creationDate ?? Date()).timeIntervalSince1970 * 1000
                song.added = (modified ?? Date()).timeIntervalSince1970 * 1000
                song.fileSize = Int64(values?.fileSize ?? 0); song.cacheVersion = version
                return song
            }
            songs.append(song)
            if songs.count % 100 == 0 { checkpoint(songs) }
            if Date().timeIntervalSince(lastProgress) >= 0.1 || index + 1 == candidates.count { lastProgress = Date(); progress(songs.count, candidates.count, "读取音乐 · " + item.url.lastPathComponent) }
        }
        // A temporarily denied/stale directory is still configured by the user. Keep its prior
        // metadata visible with the scan error; an explicitly removed directory is never restored.
        let discovered = Set(songs.map(\.id))
        songs += old.values.filter { failedFolders.contains($0.folderID) && !discovered.contains($0.id) }
        if Task<Never, Never>.isCancelled { checkpoint(songs) }
        return (songs, errors)
    }

    private static func readSong(url: URL, root: URL, folderID: String, relativePath: String, version: String) -> Song {
        let isFLAC = url.pathExtension.lowercased() == "flac"
        let flac = isFLAC ? try? FLACMetadata.read(url) : nil
        // FLAC metadata stays in our bounded reader, including malformed files.
        let asset = isFLAC ? nil : AVURLAsset(url: url)
        let metadata = asset?.commonMetadata ?? []
        func common(_ key: String) -> String? {
            metadata.first { $0.commonKey?.rawValue == key }?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let stem = url.deletingPathExtension().lastPathComponent
        let parts = stem.components(separatedBy: " - ")
        let fallbackTitle = parts.count >= 3 ? parts.dropFirst(2).joined(separator: " - ") : stem
        let fallbackArtist = parts.count >= 3 ? parts[1] : "未知歌手"
        let title = (flac?.title ?? common("title")).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTitle
        let artist = (flac?.artist ?? common("artist")).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackArtist
        let album = (flac?.album ?? common("albumName")).flatMap { $0.isEmpty ? nil : $0 } ?? "未知专辑"
        let duration = flac?.duration ?? asset?.duration.seconds ?? 0
        let fingerprint = folderID + "/" + relativePath
        let imageName = SHA256.hash(data: Data((fingerprint + version).utf8))
            .map { String(format: "%02x", $0) }.joined() + ".jpg"
        let artworkFile = prepareArtwork(asset: asset, url: url, root: root, imageName: imageName, flac: flac)
        var song = Song(id: fingerprint, folderID: folderID, relativePath: relativePath,
                    title: title, artist: artist, album: album,
                    duration: duration.isFinite && duration > 0 ? duration : 0,
                    artworkFile: artworkFile, lyrics: readLyrics(asset: asset, url: url, root: root, flac: flac))
        if let artworkFile {
            let original = artworkFile + ".original"
            song.originalArtworkFile = original // Recover lazily when a focused/display image is requested.
        }
        song.originalArtist = artist
        return song
    }

    private static func cacheDirectory() -> URL { ArtworkDiskCache.shared.root }

    private static func prepareArtwork(asset: AVURLAsset?, url: URL, root: URL, imageName: String, flac: FLACMetadata?, retainOriginal: Bool = false, generation: UInt64? = nil, extracted: ((Data, Data) -> Void)? = nil) -> String? {
        let revision = generation ?? ArtworkDiskCache.shared.generation
        let destination = cacheDirectory().appendingPathComponent(imageName)
        if ArtworkDiskCache.shared.read(destination) != nil, !retainOriginal || ArtworkDiskCache.shared.read(URL(fileURLWithPath: destination.path + ".original")) != nil { return destination.path }
        var original: Data?
        var thumbnail: CGImage?
        func accept(_ data: Data) -> Bool {
            guard data.count <= 32 * 1024 * 1024,
                  let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 640,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { return false }
            original = data; thumbnail = image; return true
        }
        if url.pathExtension.lowercased() == "flac" {
            if let data = flac?.artwork { _ = accept(data) }
        } else if let asset {
            // Common metadata covers APIC/covr without materializing every format again.
            for item in asset.commonMetadata where item.commonKey?.rawValue == "artwork" {
                if let data = item.dataValue, accept(data) { break }
            }
        }
        if thumbnail == nil {
            let parent = url.deletingLastPathComponent()
            let stem = url.deletingPathExtension().lastPathComponent
            for name in [stem, "cover", "folder", "front", "album"] {
                for ext in ["jpg", "jpeg", "png", "webp"] {
                    let candidate = parent.appendingPathComponent(name).appendingPathExtension(ext)
                    guard candidate.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/"),
                          let size = try? candidate.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 32 * 1024 * 1024 else { continue }
                    if let bytes = try? Data(contentsOf: candidate), accept(bytes) { break }
                }
                if thumbnail != nil { break }
            }
        }
        guard let thumbnail, let original,
              let data = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.82) else { return nil }
        extracted?(data, original)
        do {
            // Scanning stores only the small browsing image. Original encodings are fetched on demand.
            if retainOriginal { _ = try ArtworkDiskCache.shared.write(original, to: URL(fileURLWithPath: destination.path + ".original"), generation: revision) }
            _ = try ArtworkDiskCache.shared.write(data, to: destination, generation: revision)
        } catch { /* Cache persistence is optional; keep the known, recoverable cover identity. */ }
        return destination.path
    }

    private static func validLyrics(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !((try? SharedEngine.parseLyrics(text)) ?? []).isEmpty
    }

    private static func cacheVersion(url: URL, root: URL, modified: Date?, size: Int) -> String {
        let parent = url.deletingLastPathComponent(), stem = url.deletingPathExtension().lastPathComponent
        var parts = ["flac-metadata-v2", String(modified?.timeIntervalSince1970 ?? 0), String(size)]
        let lyricFiles = [parent, parent.appendingPathComponent("lrc"), root, root.appendingPathComponent("lrc")]
            .flatMap { base in ["lrc", "yrc"].map { base.appendingPathComponent(stem).appendingPathExtension($0) } }
        let artFiles = [stem, "cover", "folder", "front", "album"].flatMap { name in ["jpg", "jpeg", "png", "webp"].map { parent.appendingPathComponent(name).appendingPathExtension($0) } }
        for file in lyricFiles + artFiles {
            if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) {
                parts.append(file.path + ":" + String(values.contentModificationDate?.timeIntervalSince1970 ?? 0) + ":" + String(values.fileSize ?? 0))
            }
        }
        return SHA256.hash(data: Data(parts.joined(separator: "\n").utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func readLyrics(asset: AVURLAsset?, url: URL, root: URL, flac: FLACMetadata?) -> String? {
        if let embedded = flac?.lyrics, validLyrics(embedded) { return embedded }
        let items = asset.map { asset in asset.availableMetadataFormats.flatMap { asset.metadata(forFormat: $0) } } ?? []
        if let embedded = items.first(where: { item in
            let key = item.key.map { String(describing: $0).lowercased() } ?? ""
            let identifier = item.identifier?.rawValue.lowercased() ?? ""
            return key.contains("lyr") || key.contains("uslt") || identifier.contains("lyr") || identifier.contains("uslt")
        })?.stringValue, validLyrics(embedded) { return embedded }
        let stem = url.deletingPathExtension().lastPathComponent
        let parent = url.deletingLastPathComponent()
        let bases = [parent.appendingPathComponent("lrc"), parent, root.appendingPathComponent("lrc"), root]
        let candidates = bases.flatMap { base in ["lrc", "yrc"].map { base.appendingPathComponent(stem).appendingPathExtension($0) } }
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            guard let data = try? Data(contentsOf: candidate), data.count <= 1_048_576 else { continue }
            if let value = String(data: data, encoding: .utf8), validLyrics(value) { return value }
            if let value = String(data: data, encoding: .utf16), validLyrics(value) { return value }
            let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
            if let value = String(data: data, encoding: gb18030), validLyrics(value) { return value }
        }
        return nil
    }
}

#if targetEnvironment(simulator)
extension MusicLibrary {
    func simulatorAudioFixtures() async throws -> (songs: [Song], flacArtwork: Bool) {
        guard let folder = folders.first, let resources = Bundle.main.resourceURL else { throw CocoaError(.fileNoSuchFile) }
        let lease = try folderAccess.request(id: folder.id, bookmark: folder.bookmark).acquire()
        defer { lease.close() }
        let root = lease.rootURL
        let probe = root.appendingPathComponent(".audio-probe", isDirectory: true)
        try FileManager.default.createDirectory(at: probe, withIntermediateDirectories: true)
        for ext in ["mp3", "flac"] {
            var data = try Data(contentsOf: resources.appendingPathComponent("AudioTestFixtures/tags." + ext))
            if ext == "flac" {
                let image = try Data(contentsOf: root.appendingPathComponent("cover-0.png"))
                var picture = Data()
                func number(_ value: Int) { var v = UInt32(value).bigEndian; withUnsafeBytes(of: &v) { picture.append(contentsOf: $0) } }
                number(3); number(9); picture.append(Data("image/png".utf8)); number(0)
                number(360); number(360); number(24); number(0); number(image.count); picture.append(image)
                var offset = 4
                while true {
                    let count = Int(data[offset+1]) << 16 | Int(data[offset+2]) << 8 | Int(data[offset+3])
                    if data[offset] & 0x80 != 0 {
                        data[offset] &= 0x7f
                        var block = Data([0x86, UInt8((picture.count >> 16) & 255), UInt8((picture.count >> 8) & 255), UInt8(picture.count & 255)])
                        block.append(picture); data.insert(contentsOf: block, at: offset + 4 + count); break
                    }
                    offset += 4 + count
                }
            }
            try data.write(to: probe.appendingPathComponent("probe." + ext), options: .atomic)
        }
        let bookmark = try probe.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let input = MusicFolder(id: folder.id, name: "Codec probe", bookmark: bookmark)
        let access = FolderAccessRegistry(bookmarks: [.init(id: input.id, data: input.bookmark)])
        let found = await Task.detached { LibraryScanner.scan(folders: [input], recursive: false, previous: [], access: access, progress: { _, _, _ in }).songs }.value
        let songs = found.map { song in
            Song(id: folder.id + "/.audio-probe/" + song.relativePath, folderID: folder.id, relativePath: ".audio-probe/" + song.relativePath, title: song.title, artist: song.artist, album: song.album, duration: song.duration, artworkFile: song.artworkFile, lyrics: song.lyrics)
        }
        return (songs, found.first(where: { $0.relativePath.hasSuffix(".flac") })?.artworkFile != nil)
    }

    /// Real scanner stress, isolated to the explicitly enabled disposable simulator fixture.
    func simulatorScanStress() async throws -> [String: Any] {
        guard let folder = folders.first, let resources = Bundle.main.resourceURL else { throw CocoaError(.fileNoSuchFile) }
        let lease = try folderAccess.request(id: folder.id, bookmark: folder.bookmark).acquire()
        defer { lease.close() }
        let root = lease.rootURL
        let directory = root.appendingPathComponent(".scan-stress")
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let image: Data = autoreleasepool {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: 4096, height: 4096), format: format).pngData { context in
                UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: 4096, height: 4096))
            }
        }
        try image.write(to: directory.appendingPathComponent("cover.png"))
        var audio = try Data(contentsOf: resources.appendingPathComponent("AudioTestFixtures/tags.flac"))
        var offset = 4
        while true {
            let last = audio[offset] & 0x80 != 0
            let count = Int(audio[offset+1]) << 16 | Int(audio[offset+2]) << 8 | Int(audio[offset+3])
            offset += 4 + count
            if last { break }
        }
        var picture = Data()
        func number(_ value: Int) { var n = UInt32(value).bigEndian; withUnsafeBytes(of: &n) { picture.append(contentsOf: $0) } }
        number(3); number(9); picture.append(Data("image/png".utf8)); number(0)
        number(4096); number(4096); number(24); number(0); number(image.count); picture.append(image)
        var flac = Data(audio.prefix(42)); flac[4] &= 0x7f
        flac.append(contentsOf: [0x86, UInt8((picture.count >> 16) & 255), UInt8((picture.count >> 8) & 255), UInt8(picture.count & 255)])
        flac.append(picture); flac.append(audio.suffix(from: offset)); audio = Data()
        let template = directory.appendingPathComponent("template.flac")
        try flac.write(to: template)
        for i in 0..<964 { try FileManager.default.linkItem(at: template, to: directory.appendingPathComponent("track-\(i).flac")) }
        try FileManager.default.removeItem(at: template)
        for i in 0..<73 { try FileManager.default.copyItem(at: resources.appendingPathComponent("AudioTestFixtures/tags.mp3"), to: directory.appendingPathComponent("track-\(i).mp3")) }
        let bookmark = try directory.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let input = MusicFolder(id: directory.path, name: "Scan stress", bookmark: bookmark)
        let access = FolderAccessRegistry(bookmarks: [.init(id: input.id, data: input.bookmark)])
        return await Task.detached {
            func memory() -> UInt64 {
                var info = mach_task_basic_info(), count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
                let status = withUnsafeMutablePointer(to: &info) { pointer in
                    pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) }
                }
                return status == KERN_SUCCESS ? UInt64(info.resident_size) : 0
            }
            let before = memory(); var peak = before
            let result = LibraryScanner.scan(folders: [input], recursive: false, previous: [], access: access, progress: { _, _, _ in peak = max(peak, memory()) })
            peak = max(peak, memory())
            let originalsLazy = result.songs.allSatisfy { song in
                song.originalArtworkFile.map { !FileManager.default.fileExists(atPath: $0) } ?? false
            }
            let bounded = result.songs.allSatisfy { song in
                guard let path = song.artworkFile, let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
                      let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
                      let height = properties[kCGImagePropertyPixelHeight as String] as? Int else { return false }
                return max(width, height) <= 640
            }
            var displayBounded = false, originalRetained = false
            if let song = result.songs.first(where: { $0.relativePath.hasSuffix(".flac") }),
               let before = try? LibraryScanner.artworkData(song: song, folder: input, original: true, access: access),
               let display = try? LibraryScanner.displayArtworkData(song: song, folder: input, access: access),
               let source = CGImageSourceCreateWithData(display as CFData, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
               let width = properties[kCGImagePropertyPixelWidth as String] as? Int {
                displayBounded = width == 2048
                originalRetained = before == (try? LibraryScanner.artworkData(song: song, folder: input, original: true, access: access))
            }
            // Evict a generated thumbnail only, then verify that metadata reuse and image recovery are independent.
            let evicted = result.songs.first(where: { $0.relativePath.hasSuffix(".flac") })
            if let path = evicted?.artworkFile {
                try? ArtworkDiskCache.shared.maintenance { _ in try FileManager.default.removeItem(atPath: path) }
            }
            let incremental = LibraryScanner.scan(folders: [input], recursive: false, previous: result.songs, access: access, progress: { _, _, _ in })
            let incrementalMetadataOnly = evicted?.artworkFile.map { !FileManager.default.fileExists(atPath: $0) } ?? false
            let evictionRecovery = evicted.map { (try? LibraryScanner.artworkData(song: $0, folder: input, original: false, access: access)) != nil } ?? false
            return ["count": result.songs.count, "errors": result.errors.count, "displayBounded": displayBounded, "originalRetained": originalRetained, "originalsLazy": originalsLazy, "incrementalMetadataOnly": incrementalMetadataOnly, "evictionRecovery": evictionRecovery, "thumbnailsBounded": bounded, "incrementalCount": incremental.songs.count, "baselineBytes": before, "peakSampleBytes": peak, "growthBytes": peak - min(peak, before)] as [String: Any]
        }.value
    }

    /// Explicit opt-in fixture for a disposable simulator. Does not save a library index or preferences.
    private func prepareSimulatorFixture() throws {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MiniVoice-UITestFixture", isDirectory: true)
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var wav = Data()
        func ascii(_ text: String) { wav.append(contentsOf: text.utf8) }
        func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
        func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
        let bytes: UInt32 = 8000 * 2 * 60
        ascii("RIFF"); u32(bytes + 36); ascii("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(8000); u32(16000); u16(2); u16(16); ascii("data"); u32(bytes)
        for sample in 0..<Int(bytes / 2) { u16(UInt16(bitPattern: Int16(sin(Double(sample) * 2 * .pi * 440 / 8000) * 1500))) }
        let bookmark = try root.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        folders = [MusicFolder(id: root.path, name: "合成测试音乐", bookmark: bookmark)]
        let titles = ["山海之间", "午夜漫步", "微光", "海岸线", "夏日来信", "远行", "雨后", "星河", "慢慢", "日落之前", "风的方向", "回声"]
        songs = try titles.enumerated().map { index, title in
            let artwork = root.appendingPathComponent("cover-\(index).png")
            let image = UIGraphicsImageRenderer(size: CGSize(width: 360, height: 360)).image { renderer in
                let context = renderer.cgContext
                let color = UIColor(hue: CGFloat(index) / CGFloat(titles.count), saturation: 0.6, brightness: 0.65, alpha: 1)
                color.setFill(); context.fill(CGRect(x: 0, y: 0, width: 360, height: 360))
                UIColor.white.withAlphaComponent(0.12).setFill()
                context.fillEllipse(in: CGRect(x: 80, y: 40, width: 300, height: 300))
                (String(format: "%02d", index + 1) as NSString).draw(at: CGPoint(x: 24, y: 100), withAttributes: [.font: UIFont.systemFont(ofSize: 112, weight: .black), .foregroundColor: UIColor.white])
                ("MINIVOICE · UI TEST" as NSString).draw(at: CGPoint(x: 26, y: 300), withAttributes: [.font: UIFont.systemFont(ofSize: 16, weight: .medium), .foregroundColor: UIColor.white])
            }
            try image.pngData()!.write(to: artwork, options: .atomic)
            try FileManager.default.createDirectory(at: Self.artworkDirectory, withIntermediateDirectories: true)
            let thumbnail = Self.artworkDirectory.appendingPathComponent("fixture-\(index).png")
            try image.pngData()!.write(to: thumbnail, options: .atomic)
            let parent = root.appendingPathComponent("歌手 #\(index)%", isDirectory: true)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let stem = "\(index) - \(["北岸", "山间电台", "微光乐队"][index % 3]) - \(title)"
            let relative = parent.lastPathComponent + "/" + stem + ".wav"
            try wav.write(to: root.appendingPathComponent(relative), options: .atomic)
            try image.pngData()!.write(to: parent.appendingPathComponent("cover.png"), options: .atomic)
            let lyricsRoot = root.appendingPathComponent("lrc", isDirectory: true)
            try FileManager.default.createDirectory(at: lyricsRoot, withIntermediateDirectories: true)
            try "[0,15000](0,15000,0)根目录逐字歌词".write(to: lyricsRoot.appendingPathComponent(stem + ".yrc"), atomically: true, encoding: .utf8)
            var song = Song(id: root.path + "/" + relative, folderID: root.path, relativePath: relative, title: title,
                        artist: ["北岸", "山间电台", "微光乐队"][index % 3], album: "模拟器测试专辑", duration: 60,
                        artworkFile: thumbnail.path, lyrics: "[00:00.00]这是一段合成测试音频\n[00:15.00]用来检查音乐墙与播放界面\n[00:30.00]不会读取你的真实音乐")
            song.originalArtworkFile = artwork.path
            song.sourceAdded = Double(index + 1) * 1000; song.added = Double(index + 1) * 2000
            song.fileSize = Int64(wav.count); song.cacheVersion = "fixture-\(index)"
            song.originalArtist = song.artist
            return song
        }
        if ProcessInfo.processInfo.arguments.contains("--mv-wall-stress-fixture") {
            let templates = songs
            songs = (0..<1037).map { index in
                let base = templates[index % templates.count]
                var song = Song(id: base.id + "#render-\(index)", folderID: base.folderID, relativePath: base.relativePath,
                                title: String(format: "%04d", index) + " " + base.title, artist: base.artist, album: base.album,
                                duration: base.duration, artworkFile: base.artworkFile, lyrics: base.lyrics)
                song.originalArtworkFile = base.originalArtworkFile; song.cacheVersion = base.cacheVersion
                song.sourceAdded = base.sourceAdded; song.added = base.added; song.fileSize = base.fileSize
                return song
            }
        }
    }
}
#endif

extension MusicLibrary {
    /// Mutations for Shared/UI: validate every selected identity before changing collection data.
    func sharedCollectionAction(_ name: String, payload: [String: Any]) throws -> Any {
        func reject(_ message: String) -> NSError {
            NSError(domain: "MiniVoice.iOS.Collection", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        func selected(_ ids: [String]) throws -> Set<String> {
            let allowed = Set(songs.filter { song in folders.contains { $0.id == song.folderID } }.map(\.id))
            guard !ids.isEmpty, ids.allSatisfy(allowed.contains) else { throw reject("歌曲已不在当前音乐库中") }
            return Set(ids)
        }
        func title() throws -> String {
            let value = (payload["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value.count <= 100 else { throw reject("歌单名称需为 1—100 字") }
            guard !playlists.contains(where: { $0.name == value && $0.id.uuidString != payload["playlist"] as? String }) else { throw reject("已有同名歌单") }
            return value
        }
        switch name {
        case "favorite", "favoriteMany":
            let ids = try selected(name == "favorite" ? [payload["id"] as? String ?? ""] : payload["ids"] as? [String] ?? [])
            if name == "favorite" {
                for id in ids { if !favorites.insert(id).inserted { favorites.remove(id) } }
            } else {
                guard let value = payload["value"] as? Bool else { throw reject("缺少收藏状态") }
                if value { favorites.formUnion(ids) } else { favorites.subtract(ids) }
            }
            defaults.set(Array(favorites), forKey: "favorites"); return true
        case "clearRecent": recentIDs = []; defaults.set([], forKey: "recentIDs"); return true
        case "createPlaylist":
            let name = try title()
            let initial = payload["ids"] as? [String] ?? []
            if !initial.isEmpty { _ = try selected(initial) }
            let item = MusicPlaylist(id: UUID(), name: name, songIDs: Array(NSOrderedSet(array: initial)) as? [String] ?? [])
            playlists.append(item); save(playlists, key: "playlists"); return ["id": item.id.uuidString]
        case "renamePlaylist", "deletePlaylist", "addToPlaylist", "addManyToPlaylist", "removeManyFromPlaylist":
            guard let id = payload["playlist"] as? String, let index = playlists.firstIndex(where: { $0.id.uuidString == id }) else { throw reject("歌单不存在") }
            if name == "deletePlaylist" { playlists.remove(at: index); save(playlists, key: "playlists"); return ["id": NSNull()] }
            if name == "renamePlaylist" { playlists[index].name = try title() }
            else {
                let ids = try selected(name == "addToPlaylist" ? [payload["id"] as? String ?? ""] : payload["ids"] as? [String] ?? [])
                if name == "removeManyFromPlaylist" { playlists[index].songIDs.removeAll { ids.contains($0) } }
                else { playlists[index].songIDs.append(contentsOf: songs.map(\.id).filter { ids.contains($0) && !playlists[index].songIDs.contains($0) }) }
            }
            save(playlists, key: "playlists"); return ["id": id]
        default: throw reject("iOS 尚未支持此操作：\(name)")
        }
    }
}

extension MusicLibrary {
    private func applyingAliases(_ input: [Song]) throws -> [Song] {
        var canonical: [String: String] = [:]
        return try input.map { song in
            var value = song
            let original = song.originalArtist ?? song.artist
            value.originalArtist = original
            if canonical[original] == nil {
                canonical[original] = try SharedEngine.execute(["op": "artist.canonical", "value": original, "aliases": aliases]) as? String ?? original
            }
            value.artist = canonical[original] ?? original
            return value
        }
    }

    func invalidateArtworkMemory() async { await ArtworkRequestCache.shared.invalidateMemory() }

    func artworkData(for song: Song, original: Bool, display: Bool = false, wall: Bool = false, card: Bool = false) async throws -> Data {
        guard !maintenanceBusy, let folder = folders.first(where: { $0.id == song.folderID }) else { throw CocoaError(.fileReadNoPermission) }
        let quality = card ? "card" : wall ? "wall" : display ? "display" : original ? "original" : "thumbnail"
        let key = String(decoding: try JSONEncoder().encode([song.id, song.cacheVersion ?? "", quality, song.artworkFile ?? "", song.originalArtworkFile ?? ""]), as: UTF8.self)
        let generation = ArtworkDiskCache.shared.generation
        let access = folderAccess
        let data = try await ArtworkRequestCache.shared.data(key: key, cacheInMemory: quality != "original") {
            try wall || card ? LibraryScanner.wallArtworkData(song: song, folder: folder, card: card, access: access, generation: generation) : display ? LibraryScanner.displayArtworkData(song: song, folder: folder, access: access, generation: generation) : LibraryScanner.artworkData(song: song, folder: folder, original: original, access: access, generation: generation)
        }
        guard !maintenanceBusy, folders.contains(where: { $0.id == folder.id && $0.bookmark == folder.bookmark }) else { throw CocoaError(.fileReadNoPermission) }
        return data
    }

    var sharedSettings: [String: Any] {
        ["folders": folders.map { ["id": $0.id, "name": $0.name, "path": "系统文件授权目录"] },
         "recursive": includesSubfolders, "artists": Array(Set(songs.map { $0.originalArtist ?? $0.artist })).sorted(),
         "aliases": aliases, "crashCount": IOSDiagnostics.shared.crashCount,
         "actions": ["chooseFolder", "removeFolder", "recursive", "rescan", "enableScanNotifications", "clearRecent", "cacheInfo", "clearCache", "inspectLibrary", "artistAlias", "clearArtistAliases", "exportDiagnostics"]]
    }

    func sharedMaintenanceAction(_ name: String, payload: [String: Any]) async throws -> Any {
        func failure(_ text: String) -> NSError { NSError(domain: "MiniVoice.Maintenance", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
        switch name {
        case "cacheInfo":
            let files = try await Task.detached(priority: .utility) {
                try ArtworkDiskCache.shared.inspect { try ScopedCacheFiles.list(root: $0) }
            }.value
            return ["bytes": files.reduce(0) { $0 + $1.bytes }, "count": files.count, "entries": files.prefix(2000).map(\.dto), "truncated": files.count > 2000]
        case "clearCache":
            guard !isScanning, !maintenanceBusy else { throw failure("扫描或维护期间不能清理缓存") }
            maintenanceBusy = true
            defer { maintenanceBusy = false }
            let ids = payload["ids"] as? [String]
            await ArtworkRequestCache.shared.invalidateAll()
            let removed = try await Task.detached(priority: .utility) {
                try ArtworkDiskCache.shared.maintenance { try ScopedCacheFiles.clear(root: $0, ids: ids) }
            }.value
            return ["removed": removed]
        case "inspectLibrary":
            if payload["start"] as? Bool == true, inspection["running"] as? Bool != true {
                let token = UUID(); inspectionGeneration = token
                let input = songs
                let selectedFolders = folders
                let access = folderAccess
                inspection = ["running": true, "checked": 0, "total": input.count, "unavailable": [[String: String]]()]
                Task { [weak self] in
                    let result = await Task.detached(priority: .utility) {
                        var unavailable: [[String: String]] = []
                        let groups = Dictionary(grouping: input, by: \.folderID)
                        var checked = 0
                        for (folderID, songs) in groups {
                            let grant: Result<FolderAccessRegistry.Lease, Error> = Result {
                                guard let folder = selectedFolders.first(where: { $0.id == folderID }) else { throw FolderAccessRegistry.Failure.revoked }
                                return try access.request(id: folder.id, bookmark: folder.bookmark).acquire()
                            }
                            defer { if case .success(let lease) = grant { lease.close() } }
                            for song in songs {
                                do {
                                    let lease = try grant.get()
                                    let file = try lease.file(relativePath: song.relativePath)
                                    let handle = try FileHandle(forReadingFrom: file); try handle.close()
                                    try lease.checkValidity()
                                } catch { unavailable.append(["id": song.id, "title": song.title, "path": song.relativePath, "reason": "文件不存在、无读取权限或提供方暂不可用：" + error.localizedDescription]) }
                                checked += 1
                                if checked % 25 == 0 {
                                    let status: [String: Any] = ["running": true, "checked": checked, "total": input.count, "unavailable": unavailable]
                                    await MainActor.run { [weak self] in if self?.inspectionGeneration == token { self?.inspection = status } }
                                }
                            }
                        }
                        return ["running": false, "checked": checked, "total": input.count, "unavailable": unavailable] as [String: Any]
                    }.value
                    if self?.inspectionGeneration == token { self?.inspection = result }
                }
            }
            return inspection
        case "artistAlias", "clearArtistAliases":
            var next = aliases
            if name == "clearArtistAliases" { next = [:] }
            else {
                guard let source = payload["source"] as? String, let target = payload["target"] as? String,
                      songs.contains(where: { ($0.originalArtist ?? $0.artist) == source }),
                      songs.contains(where: { ($0.originalArtist ?? $0.artist) == target }),
                      let key = try SharedEngine.execute(["op": "artist.key", "value": source]) as? String,
                      let targetKey = try SharedEngine.execute(["op": "artist.key", "value": target]) as? String, key != targetKey else {
                    throw failure("请选择两个不同的现有歌手名称")
                }
                next.removeValue(forKey: targetKey); next[key] = target
            }
            let old = aliases
            aliases = next
            let updated: [Song]
            do { updated = try applyingAliases(songs) } catch { aliases = old; throw error }
            do {
                let data = try JSONEncoder().encode(next)
                try FileManager.default.createDirectory(at: Self.aliasURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let destination = Self.aliasURL
                try await Task.detached(priority: .utility) { try data.write(to: destination, options: .atomic) }.value
            } catch { aliases = old; throw error }
            songs = updated; try await saveIndex(songs)
            return true
        default: throw failure("尚未支持此维护操作")
        }
    }

    func diagnosticsArchive() async throws -> Data {
        let history = try await IOSDiagnostics.shared.exportHistory()
        let historyData = try JSONEncoder().encode(history)
        // Counts, versions and local errors only; do not export security bookmarks or music paths.
        let report: [String: Any] = ["platform": "iOS", "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "",
                                   "songCount": songs.count, "folderCount": folders.count, "playlistCount": playlists.count,
                                   "scanning": isScanning, "scanDetail": scanDetail, "inspection": ["running": inspection["running"] ?? false],
                                   "createdAt": ISO8601DateFormatter().string(from: Date()),
                                   "diagnostics": try JSONSerialization.jsonObject(with: historyData),
                                   "crashDelivery": "MetricKit 系统延迟投递；本地保留最近 5 条崩溃，未收到记录不代表从未崩溃"]
        return DiagnosticArchive.zip(name: "diagnostics.json", data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]))
    }
}
