import AVFoundation
import Combine
import CoreFoundation
import CryptoKit
import Foundation
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

    private static var aliasURL: URL { indexURL.deletingLastPathComponent().appendingPathComponent("artist-aliases.json") }
    static var artworkDirectory: URL { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Artwork", isDirectory: true) }

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

    func restoreAndScan() {
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--mv-ui-fixture") { return }
        #endif
        guard !didRestore || defaults.bool(forKey: "ios.scan.pending") && !isScanning else { return }
        didRestore = true
        if !folders.isEmpty { rescan() }
    }

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
        guard !maintenanceBusy else { errorMessage = "正在维护缓存，请稍后重扫"; return }
        scanTask?.cancel()
        inspectionGeneration = UUID()
        inspection = ["running": false, "checked": 0, "total": 0, "unavailable": [[String: String]]()]
        let generation = UUID()
        scanGeneration = generation
        let selectedFolders = folders
        let previous = songs
        let recursive = includesSubfolders
        IOSDiagnostics.shared.record(.event, "scan started folders=\(selectedFolders.count) recursive=\(recursive)")
        isScanning = true; scanCount = 0; scanDetail = "正在查找音乐文件…"
        defaults.set(true, forKey: "ios.scan.pending")
        let background = UIApplication.shared.beginBackgroundTask(withName: "MiniVoice music scan") { [weak self] in
            guard let self, self.scanGeneration == generation else { return }
            self.scanTask?.cancel()
            self.isScanning = false
            self.scanDetail = "扫描暂停，返回应用后继续"
            IOSDiagnostics.shared.record(.event, "scan background time expired")
        }
        let worker = Task.detached(priority: .userInitiated) { [weak self] in
            LibraryScanner.scan(folders: selectedFolders, recursive: recursive, previous: previous) { count, detail in
                Task { @MainActor [weak self] in
                    guard let self, self.scanGeneration == generation, self.isScanning else { return }
                    self.scanCount = count; self.scanDetail = detail
                }
            }
        }
        scanTask = Task {
            defer { if background != .invalid { UIApplication.shared.endBackgroundTask(background) } }
            let result = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled, scanGeneration == generation else { return }
            do { songs = try applyingAliases(result.songs).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } }
            catch { errorMessage = "歌手归并失败：\(error.localizedDescription)"; songs = result.songs }
            scanCount = songs.count; isScanning = false; scanDetail = "扫描完成 · \(songs.count) 首歌曲"
            IOSDiagnostics.shared.record(.event, "scan completed songs=\(songs.count) errors=\(result.errors.count)")
            defaults.set(false, forKey: "ios.scan.pending")
            saveIndex(songs)
            errorMessage = result.errors.isEmpty ? nil : result.errors.joined(separator: "\n")
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

    static func artworkData(song: Song, folder: MusicFolder, original: Bool) throws -> Data {
        guard let root = resolve(folder) else { throw CocoaError(.fileReadNoPermission) }
        let accessing = root.startAccessingSecurityScopedResource()
        defer { if accessing { root.stopAccessingSecurityScopedResource() } }
        let file = root.appendingPathComponent(song.relativePath).standardizedFileURL
        guard file.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else { throw CocoaError(.fileReadNoPermission) }
        var artwork = original ? (song.originalArtworkFile ?? song.artworkFile) : song.artworkFile
        if artwork == nil || !FileManager.default.fileExists(atPath: artwork!) {
            let name = song.artworkFile.map { URL(fileURLWithPath: $0).lastPathComponent } ?? SHA256.hash(data: Data(song.id.utf8)).map { String(format: "%02x", $0) }.joined() + ".jpg"
            let path = prepareArtwork(asset: AVURLAsset(url: file), url: file, imageName: name)
            artwork = original ? path.map { $0 + ".original" } : path
        }
        guard let artwork else { throw CocoaError(.fileNoSuchFile) }
        return try Data(contentsOf: URL(fileURLWithPath: artwork))
    }

    static func resolve(_ folder: MusicFolder) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: folder.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    static func scan(folders: [MusicFolder], recursive: Bool, previous: [Song], progress: (Int, String) -> Void) -> (songs: [Song], errors: [String]) {
        let old = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var songs: [Song] = []
        var errors: [String] = []
        var seenPaths = Set<String>()
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .contentModificationDateKey, .creationDateKey, .fileSizeKey]
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
                let identity = folder.id + "/" + relativePath
                let modified = values?.contentModificationDate
                let version = cacheVersion(url: url, root: root, modified: modified, size: values?.fileSize ?? 0)
                if var cached = old[identity], cached.cacheVersion == version,
                   cached.artworkFile.map({ FileManager.default.fileExists(atPath: $0) }) ?? true {
                    cached.artist = cached.originalArtist ?? cached.artist
                    songs.append(cached)
                } else {
                    var song = readSong(url: url, root: root, folderID: folder.id, relativePath: relativePath, version: version)
                    song.sourceAdded = old[identity]?.sourceAdded ?? (values?.creationDate ?? Date()).timeIntervalSince1970 * 1000
                    song.added = (modified ?? Date()).timeIntervalSince1970 * 1000
                    song.fileSize = Int64(values?.fileSize ?? 0); song.cacheVersion = version
                    songs.append(song)
                }
                if songs.count % 10 == 0 || songs.count == 1 { progress(songs.count, "读取音乐 · " + url.lastPathComponent) }
            }
        }
        return (songs, errors)
    }

    private static func readSong(url: URL, root: URL, folderID: String, relativePath: String, version: String) -> Song {
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
        let imageName = SHA256.hash(data: Data((fingerprint + version).utf8))
            .map { String(format: "%02x", $0) }.joined() + ".jpg"
        let artworkFile = prepareArtwork(asset: asset, url: url, imageName: imageName)
        var song = Song(id: fingerprint, folderID: folderID, relativePath: relativePath,
                    title: title, artist: artist, album: album,
                    duration: duration.isFinite && duration > 0 ? duration : 0,
                    artworkFile: artworkFile, lyrics: readLyrics(asset: asset, url: url, root: root))
        if let artworkFile {
            let original = artworkFile + ".original"
            if FileManager.default.fileExists(atPath: original) { song.originalArtworkFile = original }
        }
        song.originalArtist = artist
        return song
    }

    private static func cacheDirectory() -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func prepareArtwork(asset: AVURLAsset, url: URL, imageName: String) -> String? {
        let destination = cacheDirectory().appendingPathComponent(imageName)
        if FileManager.default.fileExists(atPath: destination.path), FileManager.default.fileExists(atPath: destination.path + ".original") { return destination.path }
        var original = asset.commonMetadata.first { $0.commonKey?.rawValue == "artwork" }?.dataValue
        var source = original.flatMap(UIImage.init(data:))
        if source == nil {
            let parent = url.deletingLastPathComponent()
            let stem = url.deletingPathExtension().lastPathComponent
            for name in [stem, "cover", "folder", "front", "album"] {
                for ext in ["jpg", "jpeg", "png", "webp"] {
                    let candidate = parent.appendingPathComponent(name).appendingPathExtension(ext)
                    if let bytes = try? Data(contentsOf: candidate), let image = UIImage(data: bytes) { source = image; original = bytes; break }
                }
                if source != nil { break }
            }
        }
        guard let source else { return nil }
        if let original { try? original.write(to: URL(fileURLWithPath: destination.path + ".original"), options: .atomic) }
        let scale = min(1, 640 / max(source.size.width, source.size.height))
        let size = CGSize(width: max(1, source.size.width * scale), height: max(1, source.size.height * scale))
        let image = UIGraphicsImageRenderer(size: size).image { _ in source.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        try? data.write(to: destination, options: .atomic)
        return destination.path
    }

    private static func validLyrics(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !((try? SharedEngine.parseLyrics(text)) ?? []).isEmpty
    }

    private static func cacheVersion(url: URL, root: URL, modified: Date?, size: Int) -> String {
        let parent = url.deletingLastPathComponent(), stem = url.deletingPathExtension().lastPathComponent
        var parts = [String(modified?.timeIntervalSince1970 ?? 0), String(size)]
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

    private static func readLyrics(asset: AVURLAsset, url: URL, root: URL) -> String? {
        let items = asset.availableMetadataFormats.flatMap { asset.metadata(forFormat: $0) }
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
        wav.append(Data(count: Int(bytes)))
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

    func artworkData(for song: Song, original: Bool) async throws -> Data {
        guard let folder = folders.first(where: { $0.id == song.folderID }) else { throw CocoaError(.fileReadNoPermission) }
        return try await Task.detached(priority: .userInitiated) { try LibraryScanner.artworkData(song: song, folder: folder, original: original) }.value
    }

    var sharedSettings: [String: Any] {
        ["folders": folders.map { ["id": $0.id, "name": $0.name, "path": "系统文件授权目录"] },
         "recursive": includesSubfolders, "artists": Array(Set(songs.map { $0.originalArtist ?? $0.artist })).sorted(),
         "aliases": aliases, "crashCount": IOSDiagnostics.shared.crashCount,
         "actions": ["chooseFolder", "removeFolder", "recursive", "rescan", "clearRecent", "cacheInfo", "clearCache", "inspectLibrary", "artistAlias", "clearArtistAliases", "exportDiagnostics"]]
    }

    func sharedMaintenanceAction(_ name: String, payload: [String: Any]) async throws -> Any {
        func failure(_ text: String) -> NSError { NSError(domain: "MiniVoice.Maintenance", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
        switch name {
        case "cacheInfo":
            let root = Self.artworkDirectory
            let files = try await Task.detached(priority: .utility) { try ScopedCacheFiles.list(root: root) }.value
            return ["bytes": files.reduce(0) { $0 + $1.bytes }, "count": files.count, "entries": files.prefix(2000).map(\.dto), "truncated": files.count > 2000]
        case "clearCache":
            guard !isScanning, !maintenanceBusy else { throw failure("扫描或维护期间不能清理缓存") }
            maintenanceBusy = true
            defer { maintenanceBusy = false }
            let root = Self.artworkDirectory
            let ids = payload["ids"] as? [String]
            let removed = try await Task.detached(priority: .utility) { try ScopedCacheFiles.clear(root: root, ids: ids) }.value
            // Invalidate index references, preserving original music, user lyrics and collection data.
            songs = songs.map { song in
                var value = song
                if let path = value.artworkFile, !FileManager.default.fileExists(atPath: path) { value.cacheVersion = nil }
                return value
            }
            saveIndex(songs)
            return ["removed": removed]
        case "inspectLibrary":
            if payload["start"] as? Bool == true, inspection["running"] as? Bool != true {
                let token = UUID(); inspectionGeneration = token
                let input = songs
                let selectedFolders = folders
                inspection = ["running": true, "checked": 0, "total": input.count, "unavailable": [[String: String]]()]
                Task { [weak self] in
                    let result = await Task.detached(priority: .utility) {
                        var unavailable: [[String: String]] = []
                        let groups = Dictionary(grouping: input, by: \.folderID)
                        var checked = 0
                        for (folderID, songs) in groups {
                            let root = selectedFolders.first(where: { $0.id == folderID }).flatMap(LibraryScanner.resolve)
                            let accessing = root?.startAccessingSecurityScopedResource() ?? false
                            defer { if accessing { root?.stopAccessingSecurityScopedResource() } }
                            for song in songs {
                                do {
                                    guard let root else { throw CocoaError(.fileReadNoPermission) }
                                    let file = root.appendingPathComponent(song.relativePath).standardizedFileURL
                                    guard file.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else { throw CocoaError(.fileReadNoPermission) }
                                    let handle = try FileHandle(forReadingFrom: file); try handle.close()
                                } catch { unavailable.append(["id": song.id, "title": song.title, "path": song.relativePath, "reason": "文件不存在、无读取权限或提供方暂不可用"]) }
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
            songs = updated; saveIndex(songs)
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
