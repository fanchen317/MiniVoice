import AppKit
import AVFoundation
import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    var timestamp: TimeInterval?
    var text: String
}

struct Track: Identifiable {
    var id = UUID()
    let url: URL
    var title: String
    var artist: String
    var album: String
    var lyrics: String
    var artwork: NSImage?
    var artworkWasEdited = false
    var duration: TimeInterval

    var canWriteTags: Bool { ["mp3", "flac", "m4a"].contains(url.pathExtension.lowercased()) }

    var lyricLines: [LyricLine] { LRCParser.parse(lyrics) }
}

@MainActor
final class MusicLibrary: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var tracks: [Track] = []
    @Published var selectedID: Track.ID?
    @Published var isPlaying = false
    @Published var playbackTime: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var isImporting = false
    var volume: Float = 1 { didSet { player?.volume = volume } }
    @Published var playbackMode: PlaybackMode = .list {
        didSet { defaults.set(playbackMode.rawValue, forKey: "MiniVoice.playbackMode"); queue.reset(current: selectedID, ids: tracks.map(\.id)) }
    }
    @Published private(set) var folders: [URL] = []
    @Published var recursiveScan = true { didSet { defaults.set(recursiveScan, forKey: "MiniVoice.recursiveScan"); rescan() } }
    @Published private(set) var scanSummary = "尚未扫描"
    @Published private(set) var scanIssues: [String] = []
    private let defaults: UserDefaults
    private var queue = PlaybackQueue()
    private var scanTask: Task<Void, Never>?
    private var scanGeneration = 0

    init(defaults: UserDefaults = .standard, scanOnLaunch: Bool = true) {
        self.defaults = defaults
        folders = (defaults.stringArray(forKey: "MiniVoice.musicFolders") ?? []).map { URL(fileURLWithPath: $0) }
        playbackMode = PlaybackMode(rawValue: defaults.string(forKey: "MiniVoice.playbackMode") ?? "list") ?? .list
        recursiveScan = defaults.object(forKey: "MiniVoice.recursiveScan") as? Bool ?? true
        super.init()
        if scanOnLaunch { rescan(preferCache: true) }
    }
    private var player: AVAudioPlayer?
    private var timer: Timer?

    var selectedTrack: Track? { tracks.first { $0.id == selectedID } }
    var selectedIndex: Int? { tracks.firstIndex { $0.id == selectedID } }

    func addFolders(_ urls: [URL]) {
        for url in urls {
            let canonical = url.resolvingSymlinksInPath().standardizedFileURL
            if !folders.contains(where: { $0.path == canonical.path }) { folders.append(canonical) }
        }
        defaults.set(folders.map(\.path), forKey: "MiniVoice.musicFolders")
        rescan(preferCache: true)
    }

    func removeFolder(_ url: URL) {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        folders.removeAll { $0.path == path }
        defaults.set(folders.map(\.path), forKey: "MiniVoice.musicFolders")
        rescan(preferCache: true)
    }

    func rescan(preferCache: Bool = false) {
        scanTask?.cancel(); scanGeneration += 1
        let generation = scanGeneration
        let roots = folders, recursive = recursiveScan
        let restoringSelection = selectedID == nil
        isImporting = true; scanSummary = "正在扫描文件夹…"; scanIssues = []
        scanTask = Task {
            var scanned: [Track] = []
            var issues: [String] = []
            var seen = Set<String>()
            for root in roots {
                guard !Task.isCancelled else { return }
                let cached = preferCache ? await Task.detached { try? PlaylistCache.read(root: root, recursive: recursive) }.value : nil
                var folderTracks: [Track] = []
                if let cached {
                    folderTracks = cached.tracks.compactMap { $0.track(root: root) }
                    scanSummary = "正在载入已保存歌单…"
                } else {
                    let result = await Task.detached { FolderScanner.scan([root], recursive: recursive) }.value
                    issues += result.issues
                    for (offset, url) in result.urls.enumerated() {
                        guard !Task.isCancelled else { return }
                        scanSummary = "正在读取 \(offset + 1) / \(result.urls.count)"
                        if let track = scanned.first(where: { $0.url.path == url.path }) {
                            folderTracks.append(track)
                        } else if let track = await loadTrack(url), track.duration > 0 { folderTracks.append(track) }
                        else { issues.append("无法读取音频：\(url.lastPathComponent)") }
                    }
                    guard !Task.isCancelled else { return }
                    // An inaccessible root must never overwrite its last good playlist.
                    if result.issues.isEmpty {
                        let cache = PlaylistCache(recursive: recursive, tracks: folderTracks.map { CachedTrack(track: $0, root: root) })
                        let failure = await Task.detached { () -> String? in
                            do { try cache.write(root: root); return nil }
                            catch { return "歌单缓存无法保存：\(root.path)（\(error.localizedDescription)）" }
                        }.value
                        if let failure { issues.append(failure) }
                    }
                }
                for var track in folderTracks where seen.insert(track.url.path).inserted {
                    if let existing = tracks.first(where: { $0.url.path == track.url.path }) { track.id = existing.id }
                    scanned.append(track)
                }
                // Publish each root as soon as available, including cached roots before scanning new ones.
                if tracks.isEmpty { tracks = scanned; selectedID = tracks.first?.id }
            }
            guard !Task.isCancelled, generation == scanGeneration else { return }
            tracks = scanned
            if restoringSelection || !tracks.contains(where: { $0.id == selectedID }) {
                stop()
                let savedPath = defaults.string(forKey: "MiniVoice.lastTrack")
                selectedID = tracks.first(where: { $0.url.path == savedPath })?.id ?? tracks.first?.id
            }
            queue.reset(current: selectedID, ids: tracks.map(\.id))
            scanIssues = issues
            scanSummary = "歌单已载入：\(tracks.count) 首歌曲" + (issues.isEmpty ? "" : "，\(issues.count) 项无法读取")
            isImporting = false
        }
    }

    private func loadTrack(_ url: URL) async -> Track? {
        let probe = await Task.detached { try? MediaTools.run("ffprobe", ["-v", "error", "-show_format", "-show_streams", "-of", "json", url.path]) }.value
        guard var track = await readTrack(url) else { return nil }
        if let probe,
           let json = try? JSONSerialization.jsonObject(with: probe) as? [String: Any],
           let format = json["format"] as? [String: Any] {
            let tags = (format["tags"] as? [String: String] ?? [:]).reduce(into: [String: String]()) { $0[$1.key.lowercased()] = $1.value }
            track.title = tags["title"] ?? track.title
            track.artist = tags["artist"] ?? track.artist
            track.album = tags["album"] ?? track.album
            track.lyrics = tags["lyrics"] ?? tags["unsyncedlyrics"] ?? track.lyrics
            track.duration = Double(format["duration"] as? String ?? "") ?? track.duration
            if track.artwork == nil,
               let streams = json["streams"] as? [[String: Any]],
               let cover = streams.first(where: { ($0["disposition"] as? [String: Int])?["attached_pic"] == 1 }),
               let index = cover["index"] as? Int {
                let data = await Task.detached { try? MediaTools.run("ffmpeg", ["-v", "error", "-i", url.path, "-map", "0:\(index)", "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "pipe:1"]) }.value
                track.artwork = data.flatMap(NSImage.init(data:))
            }
        }
        if track.lyrics.isEmpty {
            let sidecar = url.deletingPathExtension().appendingPathExtension("lrc")
            track.lyrics = (try? String(contentsOf: sidecar, encoding: .utf8)) ?? ""
        }
        return track
    }

    func select(_ id: Track.ID) {
        guard id != selectedID else { return }
        let resume = isPlaying
        activate(id)
        queue.reset(current: id, ids: tracks.map(\.id))
        if resume { play() }
    }

    private func activate(_ id: Track.ID) {
        stop(); selectedID = id
        defaults.set(selectedTrack?.url.path, forKey: "MiniVoice.lastTrack")
    }

    func togglePlayback() { isPlaying ? pause() : play() }

    func play() {
        guard let index = selectedIndex else { return }
        let track = tracks[index]
        do {
            if player?.url != track.url {
                player?.stop()
                player = try AVAudioPlayer(contentsOf: track.url)
                player?.delegate = self
                player?.prepareToPlay()
                player?.currentTime = playbackTime
            }
            if playbackTime >= track.duration { playbackTime = 0; player?.currentTime = 0 }
            player?.volume = volume
            isPlaying = player?.play() == true
            if isPlaying { beginTimer() }
            else { errorMessage = "无法开始播放这首歌曲。" }
        } catch { pause(); errorMessage = "无法播放这首文件：\(error.localizedDescription)" }
    }

    func pause() { player?.pause(); isPlaying = false; timer?.invalidate() }
    func stop() { player?.stop(); player = nil; isPlaying = false; playbackTime = 0; timer?.invalidate() }
    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, selectedTrack?.duration ?? 0))
        player?.currentTime = clamped; playbackTime = clamped
    }

    func skip(_ delta: Int) {
        if delta < 0 && playbackTime > 3 { seek(to: 0); return }
        guard let next = queue.destination(current: selectedID, ids: tracks.map(\.id), mode: playbackMode, direction: delta) else { return }
        let resume = isPlaying
        activate(next)
        if resume { play() }
    }

    func save(_ updated: Track) async throws {
        let resumeScan = isImporting
        scanTask?.cancel(); scanGeneration += 1; isImporting = false
        defer { if resumeScan { rescan() } }
        let png: Data?
        if updated.artworkWasEdited, let art = updated.artwork {
            guard let tiff = art.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                  let data = bitmap.representation(using: .png, properties: [:]) else { throw TagWriteError.artworkEncodingFailed }
            png = data
        } else { png = nil }
        let payload = TagPayload(url: updated.url, title: updated.title, artist: updated.artist,
                                 album: updated.album, lyrics: updated.lyrics, artwork: png, preserveArtwork: !updated.artworkWasEdited)
        try await Task.detached { try FFMpegTagWriter.write(payload) }.value
        if let index = tracks.firstIndex(where: { $0.id == updated.id }) {
            tracks[index] = updated; tracks[index].artworkWasEdited = false
        }
        await updateCachedTrack(updated)
        if selectedID == updated.id {
            let time = playbackTime
            let resume = isPlaying
            stop(); playbackTime = time
            if resume { play() }
        }
    }

    private func updateCachedTrack(_ track: Track) async {
        for root in folders where track.url.path.hasPrefix(root.path + "/") {
            let entry = CachedTrack(track: track, root: root)
            let recursive = recursiveScan
            let failure = await Task.detached { () -> String? in
                do {
                    var cache = try PlaylistCache.read(root: root, recursive: recursive)
                    if let index = cache.tracks.firstIndex(where: { $0.path == entry.path }) { cache.tracks[index] = entry }
                    else { cache.tracks.append(entry) }
                    try cache.write(root: root); return nil
                } catch { return "歌曲已保存，但歌单缓存更新失败，请刷新：\(error.localizedDescription)" }
            }.value
            if let failure { errorMessage = failure }
        }
    }

    func activeLyricIndex(for lines: [LyricLine]) -> Int? {
        let timed = lines.enumerated().filter { $0.element.timestamp != nil }
        guard !timed.isEmpty else { return nil }
        return timed.last(where: { $0.element.timestamp! <= playbackTime })?.offset
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedPlayer = ObjectIdentifier(player)
        Task { @MainActor in
            guard let current = self.player, ObjectIdentifier(current) == finishedPlayer else { return }
            self.playbackFinished(successfully: flag)
        }
    }

    func playbackFinished(successfully: Bool) {
        pause()
        playbackTime = selectedTrack?.duration ?? 0
        guard successfully else { errorMessage = "音频播放中断，请尝试重新播放。"; return }
        guard let next = queue.destination(current: selectedID, ids: tracks.map(\.id), mode: playbackMode, automatic: true) else { return }
        activate(next); play()
    }

    private func beginTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.playbackTime = self?.player?.currentTime ?? 0 }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func readTrack(_ url: URL) async -> Track? {
        let asset = AVURLAsset(url: url)
        let metadata = (try? await asset.load(.commonMetadata)) ?? []
        func value(_ identifier: AVMetadataIdentifier) async -> String {
            guard let item = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier).first else { return "" }
            return (try? await item.load(.stringValue)) ?? ""
        }
        let title = await value(.commonIdentifierTitle).ifEmpty(url.deletingPathExtension().lastPathComponent)
        let artist = await value(.commonIdentifierArtist).ifEmpty("未知歌手")
        let album = await value(.commonIdentifierAlbumName).ifEmpty("未归类专辑")
        let artItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtwork).first
        let artData = try? await artItem?.load(.dataValue)
        let seconds = (try? await asset.load(.duration).seconds) ?? 0
        return Track(url: url, title: title, artist: artist, album: album, lyrics: "", artwork: artData.flatMap(NSImage.init(data:)), duration: seconds.isFinite ? seconds : 0)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
