import AppKit
import AVFoundation
import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    var timestamp: TimeInterval?
    var text: String
}

enum LyricsDestination: Hashable {
    case tags
    case sidecar
    case both
}

struct Track: Identifiable {
    var id = UUID()
    let url: URL
    var title: String
    var artist: String
    var album: String
    var lyrics: String { didSet { if lyrics != oldValue { lyricCache = LyricCache() } } }
    var artwork: NSImage?
    var artworkWasEdited = false
    var duration: TimeInterval

    var canWriteTags: Bool { ["mp3", "flac", "m4a"].contains(url.pathExtension.lowercased()) }

    private var lyricCache = LyricCache()
    var lyricLines: [LyricLine] { lyricCache.lines(for: lyrics) }

    init(id: UUID = UUID(), url: URL, title: String, artist: String, album: String,
         lyrics: String, artwork: NSImage?, artworkWasEdited: Bool = false, duration: TimeInterval) {
        self.id = id; self.url = url; self.title = title; self.artist = artist; self.album = album
        self.lyrics = lyrics; self.artwork = artwork; self.artworkWasEdited = artworkWasEdited; self.duration = duration
    }

    func hasFileChanges(comparedTo original: Track) -> Bool {
        title != original.title || artist != original.artist || album != original.album || lyrics != original.lyrics || artworkWasEdited
    }
}

private final class LyricCache {
    private var parsed: [LyricLine]?
    func lines(for source: String) -> [LyricLine] {
        if let parsed { return parsed }
        let lines = LRCParser.parse(source)
        parsed = lines
        return lines
    }
}

@MainActor
final class PlaybackClock: ObservableObject {
    @Published var time: TimeInterval = 0
}

@MainActor
final class MusicLibrary: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var tracks: [Track] = [] {
        didSet {
            tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
            tracksByPath = Dictionary(uniqueKeysWithValues: tracks.map { ($0.url.path, $0) })
            tracksRevision += 1
        }
    }
    private var tracksByID: [UUID: Track] = [:]
    private var tracksByPath: [String: Track] = [:]
    private(set) var tracksRevision = 0
    @Published var selectedID: Track.ID?
    /// The audio currently loaded in AVAudioPlayer. This deliberately differs from
    /// selectedID while the user browses other songs during playback.
    @Published private(set) var playingID: Track.ID?
    @Published var isPlaying = false
    let clock = PlaybackClock()
    var playbackTime: TimeInterval {
        get { clock.time }
        set { if clock.time != newValue { clock.time = newValue } }
    }
    @Published var errorMessage: String?
    @Published var isImporting = false
    var volume: Float = 1 { didSet { player?.volume = volume } }
    @Published var playbackMode: PlaybackMode = .list {
        didSet { defaults.set(playbackMode.rawValue, forKey: "MiniVoice.playbackMode"); queue.reset(current: playingID ?? selectedID, ids: playbackIDs) }
    }
    @Published private(set) var folders: [URL] = []
    @Published var recursiveScan = true { didSet { defaults.set(recursiveScan, forKey: "MiniVoice.recursiveScan"); rescan() } }
    @Published private(set) var scanSummary = "尚未扫描"
    @Published private(set) var scanIssues: [String] = []
    private let defaults: UserDefaults
    @Published private(set) var recentPaths: [String] = []
    var recentTracks: [Track] {
        recentPaths.compactMap { tracksByPath[$0] }
    }

    func track(for id: UUID) -> Track? { tracksByID[id] }
    func track(forPath path: String) -> Track? { tracksByPath[path] }

    func recentTracks(matching query: String) -> [Track] {
        recentPaths.compactMap { path -> Track? in
            guard let track = tracksByPath[path] else { return nil }
            if query.isEmpty { return track }
            return "\(track.title) \(track.artist) \(track.album)"
                .localizedCaseInsensitiveContains(query) ? track : nil
        }
    }

    func clearRecentPlayback() {
        recentPaths = []
        defaults.removeObject(forKey: "MiniVoice.recentPlayback")
    }
    private var hiddenTrackPaths: Set<String>
    private var queue = PlaybackQueue()
    // Snapshot the visible order when playback is explicitly started from a list.
    // Browsing, searching and recent-history updates do not replace this snapshot.
    private var playbackSnapshot: [UUID]?
    var playbackIDs: [UUID] {
        (playbackSnapshot ?? tracks.map(\.id)).filter { tracksByID[$0] != nil }
    }
    private var scanTask: Task<Void, Never>?
    private var scanGeneration = 0

    init(defaults: UserDefaults = .standard, scanOnLaunch: Bool = true) {
        self.defaults = defaults
        hiddenTrackPaths = Set(defaults.stringArray(forKey: "MiniVoice.hiddenTrackPaths") ?? [])
        folders = (defaults.stringArray(forKey: "MiniVoice.musicFolders") ?? []).map { URL(fileURLWithPath: $0) }
        playbackMode = PlaybackMode(rawValue: defaults.string(forKey: "MiniVoice.playbackMode") ?? "list") ?? .list
        recursiveScan = defaults.object(forKey: "MiniVoice.recursiveScan") as? Bool ?? true
        super.init()
        recentPaths = defaults.stringArray(forKey: "MiniVoice.recentPlayback") ?? []
        if scanOnLaunch { rescan(preferCache: true) }
    }
    private var player: AVAudioPlayer?
    private var timer: Timer?

    var selectedTrack: Track? { selectedID.flatMap { tracksByID[$0] } }
    var playingTrack: Track? { playingID.flatMap { tracksByID[$0] } }
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
            var scannedByPath: [String: Track] = [:]
            for root in roots {
                guard !Task.isCancelled else { return }
                let cached = preferCache ? await Task.detached { try? PlaylistCache.read(root: root, recursive: recursive) }.value : nil
                var folderTracks: [Track] = []
                if let cached {
                    for (offset, entry) in cached.tracks.enumerated() {
                        guard !Task.isCancelled else { return }
                        if !hiddenTrackPaths.contains(root.appendingPathComponent(entry.path).path),
                           let track = entry.track(root: root) { folderTracks.append(track) }
                        // Keep window creation and input responsive while restoring large caches.
                        if offset % 64 == 63 { await Task.yield() }
                    }
                    scanSummary = "正在载入已保存歌单…"
                } else {
                    let result = await Task.detached { FolderScanner.scan([root], recursive: recursive) }.value
                    issues += result.issues
                    for (offset, url) in result.urls.enumerated() where !hiddenTrackPaths.contains(url.path) {
                        guard !Task.isCancelled else { return }
                        scanSummary = "正在读取 \(offset + 1) / \(result.urls.count)"
                        if let track = scannedByPath[url.path] {
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
                    if let existing = tracksByPath[track.url.path] { track.id = existing.id }
                    scanned.append(track)
                    scannedByPath[track.url.path] = track
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
            queue.reset(current: playingID ?? selectedID, ids: playbackIDs)
            scanIssues = issues
            scanSummary = "歌单已载入：\(tracks.count) 首歌曲" + (issues.isEmpty ? "" : "，\(issues.count) 项无法读取")
            isImporting = false
        }
    }

    private func loadTrack(_ url: URL) async -> Track? {
        let probe = await Task.detached { try? MediaTools.run("ffprobe", ["-v", "error", "-show_format", "-show_streams", "-of", "json", url.path]) }.value
        guard var track = await readTrack(url) else { return nil }
        var embeddedLyrics = ""
        if let probe,
           let json = try? JSONSerialization.jsonObject(with: probe) as? [String: Any],
           let format = json["format"] as? [String: Any] {
            let tags = (format["tags"] as? [String: String] ?? [:]).reduce(into: [String: String]()) { $0[$1.key.lowercased()] = $1.value }
            track.title = tags["title"] ?? track.title
            track.artist = tags["artist"] ?? track.artist
            track.album = tags["album"] ?? track.album
            embeddedLyrics = tags["lyrics"] ?? tags["unsyncedlyrics"] ?? ""
            track.duration = Double(format["duration"] as? String ?? "") ?? track.duration
            if track.artwork == nil,
               let streams = json["streams"] as? [[String: Any]],
               let cover = streams.first(where: { ($0["disposition"] as? [String: Int])?["attached_pic"] == 1 }),
               let index = cover["index"] as? Int {
                let data = await Task.detached { try? MediaTools.run("ffmpeg", ["-v", "error", "-i", url.path, "-map", "0:\(index)", "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "pipe:1"]) }.value
                track.artwork = data.flatMap(NSImage.init(data:))
            }
        }
        let sidecarLyrics = LyricsStorage.read(LyricsStorage.sidecarURL(for: url)) ?? ""
        track.lyrics = sidecarLyrics.isEmpty ? embeddedLyrics : sidecarLyrics
        return track
    }

    func select(_ id: Track.ID) {
        guard tracksByID[id] != nil else { return }
        selectedID = id
    }

    func play(_ id: Track.ID, in visibleIDs: [Track.ID]? = nil) {
        guard tracksByID[id] != nil else { return }
        if let visibleIDs {
            var seen = Set<UUID>()
            var snapshot = visibleIDs.filter { tracksByID[$0] != nil && seen.insert($0).inserted }
            if !snapshot.contains(id) { snapshot.append(id) }
            playbackSnapshot = snapshot
        } else if !playbackIDs.contains(id) {
            playbackSnapshot = [id]
        }
        activate(id)
        queue.reset(current: id, ids: playbackIDs)
        play()
    }

    private func activate(_ id: Track.ID) {
        stop(); selectedID = id; playingID = id
        defaults.set(selectedTrack?.url.path, forKey: "MiniVoice.lastTrack")
    }

    func togglePlayback() { isPlaying ? pause() : play() }

    func play() {
        guard let track = playingTrack ?? selectedTrack else { return }
        playingID = track.id
        do {
            if player?.url != track.url {
                player?.stop()
                player = try AVAudioPlayer(contentsOf: track.url)
                player?.delegate = self
                player?.prepareToPlay()
                // AVAudioPlayer's duration is the source of truth for the playable
                // length - file metadata (AVURLAsset / ffprobe) can be off by a few
                // seconds on live recordings.  Only ever lengthen the recorded
                // duration; a smaller value here means metadata still wins, and the
                // real end will be locked in when audioPlayerDidFinishPlaying fires.
                if let actual = player?.duration, actual.isFinite, actual > 0,
                   let index = tracks.firstIndex(where: { $0.id == track.id }),
                   actual > tracks[index].duration + 0.5 {
                    tracks[index].duration = actual
                }
                player?.currentTime = playbackTime
            }
            if playbackTime >= track.duration { playbackTime = 0; player?.currentTime = 0 }
            player?.volume = volume
            isPlaying = player?.play() == true
            if isPlaying {
                playingID = track.id
                recentPaths.removeAll { $0 == track.url.path }
                recentPaths.insert(track.url.path, at: 0)
                recentPaths = Array(recentPaths.prefix(200))
                defaults.set(recentPaths, forKey: "MiniVoice.recentPlayback")
                beginTimer()
            }
            else { errorMessage = "无法开始播放这首歌曲。" }
        } catch { pause(); errorMessage = "无法播放这首文件：\(error.localizedDescription)" }
    }

    func pause() { player?.pause(); isPlaying = false; timer?.invalidate() }
    func stop() { player?.stop(); player = nil; playingID = nil; isPlaying = false; playbackTime = 0; timer?.invalidate() }
    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, playingTrack?.duration ?? selectedTrack?.duration ?? 0))
        player?.currentTime = clamped; playbackTime = clamped
    }

    func skip(_ delta: Int) {
        if delta < 0 && playbackTime > 3 { seek(to: 0); return }
        let current = playingID ?? selectedID
        guard let next = queue.destination(current: current, ids: playbackIDs, mode: playbackMode, direction: delta) else { return }
        let resume = isPlaying
        activate(next)
        if resume { play() }
    }

    func save(_ updated: Track, lyricsDestination: LyricsDestination = .tags) async throws {
        guard let existing = tracks.first(where: { $0.id == updated.id }) else { return }
        guard updated.hasFileChanges(comparedTo: existing) else { return }
        let nonLyricsChanged = updated.title != existing.title || updated.artist != existing.artist || updated.album != existing.album || updated.artworkWasEdited
        let lyricsChanged = updated.lyrics != existing.lyrics
        let needsTagWrite = nonLyricsChanged || lyricsDestination != .sidecar
        let resumeScan = isImporting
        scanTask?.cancel(); scanGeneration += 1; isImporting = false
        defer { if resumeScan { rescan() } }
        if needsTagWrite {
            let png: Data?
            if updated.artworkWasEdited, let art = updated.artwork {
                guard let tiff = art.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                      let data = bitmap.representation(using: .png, properties: [:]) else { throw TagWriteError.artworkEncodingFailed }
                png = data
            } else { png = nil }
            let lyricsForTags = lyricsDestination == .sidecar ? "" : updated.lyrics
            let payload = TagPayload(url: updated.url, title: updated.title, artist: updated.artist,
                                     album: updated.album, lyrics: lyricsForTags, artwork: png, preserveArtwork: !updated.artworkWasEdited)
            try await Task.detached { try FFMpegTagWriter.write(payload) }.value
        }
        // A metadata-only edit can move embedded lyrics to the default sidecar destination.
        // Persist that text too, since the tag write above removes embedded lyrics for .sidecar.
        if lyricsChanged || (nonLyricsChanged && lyricsDestination != .tags && !updated.lyrics.isEmpty) {
            let sidecar = LyricsStorage.sidecarURL(for: updated.url)
            switch lyricsDestination {
            case .tags:
                try? LyricsStorage.delete(sidecar)
            case .sidecar, .both:
                if updated.lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try? LyricsStorage.delete(sidecar)
                } else {
                    try LyricsStorage.write(updated.lyrics, to: sidecar)
                }
            }
        }
        if let index = tracks.firstIndex(where: { $0.id == updated.id }) {
            tracks[index] = updated; tracks[index].artworkWasEdited = false
        }
        await updateCachedTrack(updated)
        if playingID == updated.id {
            let time = playbackTime
            let resume = isPlaying
            stop(); playingID = updated.id; playbackTime = time
            if resume { play() }
        }
    }

    func deleteTracks(ids: Set<Track.ID>, moveFilesToTrash: Bool) {
        let targets = tracks.filter { ids.contains($0.id) }
        guard !targets.isEmpty else { return }
        var removedPaths: Set<String> = []
        var failures: [String] = []
        for track in targets {
            if moveFilesToTrash {
                do {
                    var trashed: NSURL?
                    try FileManager.default.trashItem(at: track.url, resultingItemURL: &trashed)
                    removedPaths.insert(track.url.path)
                } catch {
                    failures.append("\(track.title)：\(error.localizedDescription)")
                }
            } else {
                hiddenTrackPaths.insert(track.url.path)
                removedPaths.insert(track.url.path)
            }
        }
        guard !removedPaths.isEmpty else {
            errorMessage = "没有歌曲被移除。\n\(failures.joined(separator: "\n"))"
            return
        }
        defaults.set(Array(hiddenTrackPaths), forKey: "MiniVoice.hiddenTrackPaths")
        tracks.removeAll { removedPaths.contains($0.url.path) }
        if let selectedID, ids.contains(selectedID) {
            self.selectedID = tracks.first?.id
        }
        if let playingID, ids.contains(playingID) { stop() }
        queue.reset(current: playingID ?? selectedID, ids: playbackIDs)
        removeCachedTracks(paths: removedPaths)
        if !failures.isEmpty { errorMessage = "部分歌曲无法移至废纸篓：\n\(failures.joined(separator: "\n"))" }
    }

    private func removeCachedTracks(paths: Set<String>) {
        for root in folders {
            guard var cache = try? PlaylistCache.read(root: root, recursive: recursiveScan) else { continue }
            cache.tracks.removeAll { paths.contains(root.appendingPathComponent($0.path).path) }
            try? cache.write(root: root)
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
        Self.activeLyricIndex(for: lines, at: playbackTime)
    }

    static func activeLyricIndex(for lines: [LyricLine], at time: TimeInterval) -> Int? {
        lines.indices.reversed().first { index in
            guard let timestamp = lines[index].timestamp else { return false }
            return timestamp <= time
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedPlayer = ObjectIdentifier(player)
        // Read the values we need on the calling thread before hopping actors;
        // AVAudioPlayer isn't Sendable and the values we extract are just Doubles.
        let actualEnd = max(player.duration, player.currentTime)
        Task { @MainActor in
            guard let current = self.player, ObjectIdentifier(current) == finishedPlayer else { return }
            // The actual end is wherever AVAudioPlayer stopped - for live
            // recordings this can exceed both the metadata and AVAudioPlayer's
            // own reported duration.  Lock the track's duration to the real
            // end so subsequent plays show the correct total.
            if let id = self.playingID, let index = self.tracks.firstIndex(where: { $0.id == id }),
               actualEnd.isFinite, actualEnd > 0,
               abs(self.tracks[index].duration - actualEnd) > 0.5 {
                self.tracks[index].duration = actualEnd
            }
            self.playbackFinished(successfully: flag)
        }
    }

    func playbackFinished(successfully: Bool) {
        pause()
        playbackTime = playingTrack?.duration ?? 0
        guard successfully else { errorMessage = "音频播放中断，请尝试重新播放。"; return }
        guard let next = queue.destination(current: playingID, ids: playbackIDs, mode: playbackMode, automatic: true) else { return }
        activate(next); play()
    }

    private func beginTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            // Some live recordings let AVAudioPlayer.currentTime drift past its
            // reported duration (and the metadata that backs it).  Clamp the
            // surfaced time so the slider never claims a position past the end.
            Task { @MainActor in
                guard let self = self else { return }
                let playerTime = self.player?.currentTime ?? 0
                let ceiling = self.playingTrack?.duration ?? playerTime
                self.playbackTime = min(playerTime, ceiling)
            }
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
