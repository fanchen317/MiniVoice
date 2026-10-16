import AppKit
import AVFoundation
import Foundation

struct LyricLine: Identifiable, Equatable, Sendable {
    let id = UUID()
    var timestamp: TimeInterval?
    var text: String
    var endTime: TimeInterval? = nil
    var words: [LyricWord] = []
    var translation: String? = nil
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
    var artworkKey: String?
    var lyricsKey: String?
    var resourcesLoaded = true
    var sourceStamp: FileStamp?
    var lyricSourceStamp: FileStamp?
    var duration: TimeInterval

    var canWriteTags: Bool { ["mp3", "flac", "m4a"].contains(url.pathExtension.lowercased()) }

    private var lyricCache = LyricCache()
    var lyricsAreLoading: Bool { !resourcesLoaded && lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var lyricLines: [LyricLine] { lyricSnapshot.lines }
    var lyricSnapshot: LyricsPlaybackSnapshot {
        lyricsAreLoading ? LyricsPlaybackSnapshot(lines: []) : lyricCache.snapshot(for: lyrics)
    }

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
    private var cached: LyricsPlaybackSnapshot?
    func snapshot(for source: String) -> LyricsPlaybackSnapshot {
        if let cached { return cached }
        let snapshot = LyricsPlaybackSnapshot(lines: LRCParser.parse(source))
        cached = snapshot
        return snapshot
    }
}

/// Build timing metadata once, keeping mixed or unordered lyrics' original precedence.
struct LyricsPlaybackSnapshot: Sendable {
    let lines: [LyricLine]
    let kind: LyricTimingKind
    let hasTranslation: Bool
    private let timedIndices: [Int]
    private let ordered: Bool

    init(lines: [LyricLine]) {
        self.lines = lines
        kind = LyricTimingKind.detect(lines)
        hasTranslation = lines.contains { $0.translation != nil }
        timedIndices = lines.indices.filter { lines[$0].timestamp != nil }
        ordered = zip(timedIndices, timedIndices.dropFirst()).allSatisfy {
            lines[$0.0].timestamp! <= lines[$0.1].timestamp!
        }
    }

    func activeIndex(at time: TimeInterval) -> Int? {
        guard ordered else { return MusicLibrary.activeLyricIndex(for: lines, at: time) }
        var lower = 0, upper = timedIndices.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if lines[timedIndices[middle]].timestamp! <= time { lower = middle + 1 }
            else { upper = middle }
        }
        return lower > 0 ? timedIndices[lower - 1] : nil
    }
}

@MainActor
final class PlaybackClock: ObservableObject {
    private(set) var sampledAt = Date()
    @Published var time: TimeInterval = 0 { willSet { sampledAt = Date() } }
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
    @Published private(set) var browseArtworkRevision = 0
    @Published var selectedID: Track.ID?
    /// The audio currently loaded in AVAudioPlayer. This deliberately differs from
    /// selectedID while the user browses other songs during playback.
    @Published private(set) var playingID: Track.ID?
    @Published var isPlaying = false
    @Published private(set) var isPreparingPlayback = false
    let clock = PlaybackClock()
    var playbackTime: TimeInterval {
        get { clock.time }
        set { if clock.time != newValue { clock.time = newValue } }
    }
    @Published var errorMessage: String?
    @Published var isImporting = false
    @Published var volume: Float = 1 {
        didSet {
            player?.volume = volume
            defaults.set(volume, forKey: "MiniVoice.appVolume")
        }
    }
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
        volume = min(1, max(0, defaults.object(forKey: "MiniVoice.appVolume") as? Float ?? 1))
        super.init()
        recentPaths = defaults.stringArray(forKey: "MiniVoice.recentPlayback") ?? []
        if Bundle.main.bundleIdentifier == AppIdentity.bundleIdentifier, defaults === UserDefaults.standard {
            do { try CacheStorage.migrateLegacyCaches() }
            catch { errorMessage = "旧缓存迁移未完成：\(error.localizedDescription)" }
        }
        if scanOnLaunch { rescan(preferCache: true) }
    }
    private var player: AVAudioPlayer?
    private var audioLoadTask: Task<Void, Never>?
    private var audioLoadID: UUID?
    private var audioLoadGeneration = 0
    private var timer: Timer?
    @Published private var detailTracks: [UUID: Track] = [:]
    private var detailTasks: [UUID: Task<Void, Never>] = [:]
    private var detailRequests: [UUID: UUID] = [:]

    private func invalidateDetails(_ id: UUID) {
        detailRequests[id] = nil
        detailTasks.removeValue(forKey: id)?.cancel()
        detailTracks[id] = nil
    }

    var selectedTrack: Track? { selectedID.flatMap(displayTrack) }
    var playingTrack: Track? { playingID.flatMap(displayTrack) }

    private func displayTrack(_ id: Track.ID) -> Track? {
        guard var track = detailTracks[id] ?? tracksByID[id] else { return nil }
        // Artwork is ready before source tags/lyrics finish resolving. Only the
        // display copy receives it; full-resolution editing still reads the source.
        if track.artwork == nil { track.artwork = PreparedBrowseArtwork.shared.image(track.artworkKey) }
        return track
    }
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
                let cached = await Task.detached { try? PlaylistCache.read(root: root, recursive: recursive) }.value
                var folderTracks: [Track] = []
                if preferCache, let cached {
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
                    let current = await Task.detached {
                        (cached?.tracks ?? []).filter { $0.isCurrent(root: root) }
                    }.value
                    let unchanged = Dictionary(current.map { ($0.path, $0) }, uniquingKeysWith: { _, latest in latest })
                    issues += result.issues
                    for (offset, url) in result.urls.enumerated() where !hiddenTrackPaths.contains(url.path) {
                        guard !Task.isCancelled else { return }
                        scanSummary = "正在读取 \(offset + 1) / \(result.urls.count)"
                        if let track = scannedByPath[url.path] {
                            folderTracks.append(track)
                        } else if let entry = unchanged[String(url.path.dropFirst(root.path.count + 1))],
                                  let track = entry.track(root: root) { folderTracks.append(track) }
                        else if let track = await loadTrack(url), track.duration > 0 {
                            do {
                                let snapshot = try await CachedTrack.snapshot(track: track, root: root)
                                let entry = try await Task.detached {
                                    var value = snapshot; try value.splitResources(); return value
                                }.value
                                if let light = entry.track(root: root) { folderTracks.append(light) }
                            } catch { folderTracks.append(track); issues.append("资源缓存无法保存：\(url.lastPathComponent)") }
                        }
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
                        else if let saved = await Task.detached(operation: { try? PlaylistCache.read(root: root, recursive: recursive) }).value {
                            folderTracks = saved.tracks.compactMap { $0.track(root: root) }
                        }
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
            for id in Set(detailTracks.keys).union(detailTasks.keys) { invalidateDetails(id) }
            if let id = playingID, tracksByID[id] == nil { stop() }
            if restoringSelection || !tracks.contains(where: { $0.id == selectedID }) {
                stop()
                let savedPath = defaults.string(forKey: "MiniVoice.lastTrack")
                selectedID = tracks.first(where: { $0.url.path == savedPath })?.id ?? tracks.first?.id
                if let restored = selectedTrack, restored.url.path == savedPath {
                    let savedTime = defaults.double(forKey: "MiniVoice.lastPlaybackTime")
                    playbackTime = savedTime.isFinite && savedTime >= 0 && savedTime < restored.duration ? savedTime : 0
                    playingID = restored.id
                }
            }
            queue.reset(current: playingID ?? selectedID, ids: playbackIDs)
            // Prepare every referenced classification cover before declaring the scan complete.
            // Existing libraries hydrate the same persistent cache during startup.
            let artworkEntries = scanned.compactMap { track in
                track.artworkKey.map { (key: $0, source: track.url) }
            }
            let prepared = await BrowseArtworkLoader.shared.prepare(artworkEntries) { [weak self] done, total in
                await MainActor.run {
                    guard let self, self.scanGeneration == generation else { return }
                    self.scanSummary = "正在准备高清封面：\(done) / \(total)"
                }
            }
            guard !Task.isCancelled, generation == scanGeneration else { return }
            PreparedBrowseArtwork.shared.replace(prepared)
            browseArtworkRevision += 1
            let missingCovers = Set(artworkEntries.map(\.key)).subtracting(prepared.keys).count
            if missingCovers > 0 { issues.append("\(missingCovers) 张高清封面无法准备，请检查对应歌曲文件是否可读取。") }
            if defaults === UserDefaults.standard {
                await BrowseArtworkWorker.shared.discardObsoletePreparedFiles(retaining: Set(artworkEntries.map(\.key)))
                guard !Task.isCancelled, generation == scanGeneration else { return }
            }
            scanIssues = issues
            scanSummary = "歌单已载入：\(tracks.count) 首歌曲" + (issues.isEmpty ? "" : "，\(issues.count) 项无法读取")
            isImporting = false
            if let id = selectedID { requestDetails(id) }
            if let id = playingID, id != selectedID { requestDetails(id) }
            if self.defaults === UserDefaults.standard {
                Task.detached(priority: .utility) { ResourceCache.prune() }
                if preferCache { validateCachedSources(generation: generation) }
            }
        }
    }

    private func loadTrack(_ url: URL) async -> Track? {
        let sourceStamp = FileStamp.read(url)
        let lyricStamp = FileStamp.read(LyricsStorage.sidecarURL(for: url))
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
        guard sourceStamp == FileStamp.read(url),
              lyricStamp == FileStamp.read(LyricsStorage.sidecarURL(for: url)) else { return nil }
        return track
    }

    func select(_ id: Track.ID) {
        guard tracksByID[id] != nil else { return }
        selectedID = id
        requestDetails(id)
    }

    private func requestDetails(_ id: UUID) {
        let retained = Set([selectedID, playingID, id].compactMap { $0 })
        for obsolete in Set(detailTasks.keys).union(detailTracks.keys) where !retained.contains(obsolete) {
            invalidateDetails(obsolete)
        }
        let generation = scanGeneration
        Task {
            guard scanGeneration == generation, !isImporting else { return }
            _ = await resolveTrack(id)
        }
    }

    private func validateCachedSources(generation: Int) {
        let roots = folders, recursive = recursiveScan
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, self.scanGeneration == generation, !self.isImporting else { return }
            for root in roots {
                let changed = await Task.detached(priority: .utility) {
                    (try? PlaylistCache.read(root: root, recursive: recursive))?.tracks.filter {
                        FileStamp.read(root.appendingPathComponent($0.path)) != nil && !$0.isCurrent(root: root)
                    } ?? []
                }.value
                for entry in changed {
                    guard self.scanGeneration == generation, !self.isImporting else { return }
                    let url = root.appendingPathComponent(entry.path)
                    guard let existing = self.track(forPath: url.path), var updated = await self.loadTrack(url),
                          self.scanGeneration == generation,
                          let index = self.tracks.firstIndex(where: { $0.id == existing.id }) else { continue }
                    updated.id = existing.id
                    self.invalidateDetails(existing.id)
                    self.tracks[index] = updated
                    await self.updateCachedTrack(updated)
                    if existing.id == self.selectedID || existing.id == self.playingID {
                        self.requestDetails(existing.id)
                    }
                }
            }
            Task.detached(priority: .utility) { ResourceCache.prune() }
        }
    }

    /// Full lyrics and artwork are hydrated only for selection/playback/editing.
    func resolveTrack(_ id: UUID, fullResolution: Bool = false) async -> Track? {
        if fullResolution {
            guard let base = tracksByID[id] else { return nil }
            let generation = scanGeneration
            if var source = await loadTrack(base.url) {
                guard !Task.isCancelled, scanGeneration == generation, tracksByID[id]?.url == base.url else { return nil }
                source.id = id; source.artworkKey = base.artworkKey; source.lyricsKey = base.lyricsKey
                return source
            }
            return nil
        }
        if let loaded = detailTracks[id] { return loaded }
        guard let base = tracksByID[id] else { return nil }
        if base.resourcesLoaded { return base }
        if let pending = detailTasks[id] { await pending.value; return detailTracks[id] }
        let requestID = UUID(), generation = scanGeneration
        detailRequests[id] = requestID
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.detailRequests[id] == requestID {
                    self.detailRequests[id] = nil
                    self.detailTasks[id] = nil
                }
            }
            let artKey = base.artworkKey, lyricKey = base.lyricsKey
            let sourceStamp = base.sourceStamp, lyricStamp = base.lyricSourceStamp, sourceURL = base.url
            let cached = await Task.detached {
                let current = sourceStamp != nil && sourceStamp == FileStamp.read(sourceURL)
                    && lyricStamp == FileStamp.read(LyricsStorage.sidecarURL(for: sourceURL))
                let bytes = ResourceCache.artworkData(artKey, detail: true)
                return (current, ResourceCache.isValidArtwork(bytes) ? bytes : nil, ResourceCache.lyrics(lyricKey))
            }.value
            guard !Task.isCancelled, self.detailRequests[id] == requestID, self.scanGeneration == generation else { return }
            var result: Track?
            if cached.0 && (artKey == nil || cached.1 != nil) && (lyricKey == nil || cached.2 != nil) {
                result = base
                result?.artwork = cached.1.flatMap(NSImage.init(data:))
                result?.lyrics = cached.2 ?? ""
            } else {
                result = await self.loadTrack(base.url)
                guard !Task.isCancelled, self.detailRequests[id] == requestID, self.scanGeneration == generation else { return }
                if var fresh = result {
                    fresh.id = id
                    await self.updateCachedTrack(fresh)
                    let key = self.tracksByID[id]?.artworkKey
                    let bounded = await Task.detached { ResourceCache.artworkData(key, detail: true) }.value
                    if let bounded { fresh.artwork = NSImage(data: bounded) }
                    result = fresh
                }
            }
            if result == nil {
                let values = await Task.detached { (ResourceCache.artworkData(artKey, detail: true), ResourceCache.lyrics(lyricKey)) }.value
                result = base
                result?.artwork = values.0.flatMap(NSImage.init(data:))
                result?.lyrics = values.1 ?? ""
            }
            guard !Task.isCancelled, self.detailRequests[id] == requestID, self.scanGeneration == generation,
                  var resolved = result, self.tracksByID[id] != nil else { return }
            resolved.id = id; resolved.resourcesLoaded = true
            resolved.artworkKey = self.tracksByID[id]?.artworkKey
            resolved.lyricsKey = self.tracksByID[id]?.lyricsKey
            // Retain only current selections; rapid browsing cannot retain all full covers.
            self.detailTracks = self.detailTracks.filter { $0.key == self.selectedID || $0.key == self.playingID }
            self.detailTracks[id] = resolved
        }
        detailTasks[id] = task
        await task.value
        return detailTracks[id]
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
        requestDetails(id)
        persistPlaybackPosition()
    }

    func togglePlayback() { (isPlaying || audioLoadID != nil) ? pause() : play() }

    func play() {
        guard let track = playingTrack ?? selectedTrack else { return }
        playingID = track.id
        requestDetails(track.id)
        if player?.url != track.url {
            guard audioLoadID != track.id else { return }
            cancelAudioPreparation()
            player?.stop(); player = nil
            isPlaying = false; timer?.invalidate()
            audioLoadID = track.id
            isPreparingPlayback = true
            let generation = audioLoadGeneration
            audioLoadTask = Task { [weak self] in
                guard !Task.isCancelled else { return }
                do {
                    let prepared = try await PreparedAudioPlayer.load(track.url)
                    guard let self, !Task.isCancelled, self.audioLoadGeneration == generation,
                          self.playingID == track.id else { return }
                    self.audioLoadID = nil; self.audioLoadTask = nil
                    self.isPreparingPlayback = false
                    self.player = prepared.player
                    self.player?.delegate = self
                    // The decoder's duration can exceed source metadata on live recordings.
                    if let actual = self.player?.duration, actual.isFinite, actual > 0,
                       let index = self.tracks.firstIndex(where: { $0.id == track.id }),
                       actual > self.tracks[index].duration + 0.5 {
                        self.tracks[index].duration = actual
                        self.detailTracks[track.id]?.duration = actual
                    }
                    self.player?.currentTime = self.playbackTime
                    self.startPreparedPlayback(track)
                } catch {
                    guard let self, !Task.isCancelled, self.audioLoadGeneration == generation else { return }
                    self.audioLoadID = nil; self.audioLoadTask = nil
                    self.isPreparingPlayback = false
                    self.errorMessage = "无法播放这首文件：\(error.localizedDescription)"
                }
            }
            return
        }
        startPreparedPlayback(track)
    }

    private func cancelAudioPreparation() {
        audioLoadGeneration += 1
        audioLoadTask?.cancel(); audioLoadTask = nil; audioLoadID = nil
        isPreparingPlayback = false
    }

    private func startPreparedPlayback(_ track: Track) {
        if playbackTime >= track.duration { playbackTime = 0; player?.currentTime = 0 }
        player?.volume = volume
        isPlaying = player?.play() == true
        if isPlaying {
            playingID = track.id
            recentPaths.removeAll { $0 == track.url.path }
            recentPaths.insert(track.url.path, at: 0)
            recentPaths = Array(recentPaths.prefix(200))
            defaults.set(recentPaths, forKey: "MiniVoice.recentPlayback")
            persistPlaybackPosition()
            beginTimer()
        }
        else { errorMessage = "无法开始播放这首歌曲。" }
    }

    func pause() {
        cancelAudioPreparation()
        player?.pause()
        if let player { playbackTime = player.currentTime }
        persistPlaybackPosition()
        isPlaying = false; timer?.invalidate()
    }

    private func persistPlaybackPosition() {
        guard let track = playingTrack ?? selectedTrack, playbackTime.isFinite else { return }
        defaults.set(track.url.path, forKey: "MiniVoice.lastTrack")
        defaults.set(max(0, playbackTime), forKey: "MiniVoice.lastPlaybackTime")
    }
    func stop() { cancelAudioPreparation(); if player != nil || playingID != nil { persistPlaybackPosition() }; player?.stop(); player = nil; playingID = nil; isPlaying = false; playbackTime = 0; timer?.invalidate() }
    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, playingTrack?.duration ?? selectedTrack?.duration ?? 0))
        player?.currentTime = clamped; playbackTime = clamped
        persistPlaybackPosition()
    }

    func skip(_ delta: Int) {
        if delta < 0 && playbackTime > 3 { seek(to: 0); return }
        let current = playingID ?? selectedID
        guard let next = queue.destination(current: current, ids: playbackIDs, mode: playbackMode, direction: delta) else { return }
        let resume = isPlaying || audioLoadID != nil
        activate(next)
        if resume { play() }
    }

    func save(_ updated: Track, lyricsDestination: LyricsDestination = .tags) async throws {
        guard let existing = await resolveTrack(updated.id, fullResolution: true) else {
            throw TagWriteError.failed("无法读取歌曲文件，未保存修改。请检查文件是否存在及访问权限。")
        }
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
        invalidateDetails(updated.id)
        detailTracks[updated.id] = updated
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
        let removedSelected = selectedID.flatMap { tracksByID[$0]?.url.path }.map { removedPaths.contains($0) } ?? false
        let removedPlaying = playingID.flatMap { tracksByID[$0]?.url.path }.map { removedPaths.contains($0) } ?? false
        for track in targets where removedPaths.contains(track.url.path) { invalidateDetails(track.id) }
        if removedPlaying { stop() }
        tracks.removeAll { removedPaths.contains($0.url.path) }
        if removedSelected {
            self.selectedID = tracks.first?.id
            if let selectedID = self.selectedID { requestDetails(selectedID) }
        }
        queue.reset(current: playingID ?? selectedID, ids: playbackIDs)
        removeCachedTracks(paths: removedPaths)
        if !failures.isEmpty { errorMessage = "部分歌曲无法移至废纸篓：\n\(failures.joined(separator: "\n"))" }
    }

    private func removeCachedTracks(paths: Set<String>) {
        let roots = folders, recursive = recursiveScan
        Task.detached(priority: .utility) { for root in roots {
          ResourceCache.withDiskLock {
            guard var cache = try? PlaylistCache.read(root: root, recursive: recursive) else { return }
            cache.tracks.removeAll { paths.contains(root.appendingPathComponent($0.path).path) }
            try? cache.write(root: root)
          }
        } }
    }

    private func updateCachedTrack(_ track: Track) async {
        for root in folders where track.url.path.hasPrefix(root.path + "/") {
            guard !Task.isCancelled, tracksByID[track.id] != nil else { return }
            let entry: CachedTrack
            do { entry = try await CachedTrack.snapshot(track: track, root: root) }
            catch { errorMessage = "封面缓存无法保存：\(error.localizedDescription)"; return }
            guard !Task.isCancelled, tracksByID[track.id] != nil else { return }
            let recursive = recursiveScan
            let outcome = await Task.detached { () -> (CachedTrack?, String?) in
                do {
                    return (try PlaylistCache.update(root: root, recursive: recursive, entry: entry), nil)
                } catch { return (nil, "歌曲已保存，但歌单缓存更新失败，请刷新：\(error.localizedDescription)") }
            }.value
            guard !Task.isCancelled, tracksByID[track.id] != nil else { return }
            if let failure = outcome.1 { errorMessage = failure }
            else if let saved = outcome.0,
                    let index = tracks.firstIndex(where: { $0.id == track.id }) {
                if let key = saved.artworkKey {
                    let prepared = await BrowseArtworkLoader.shared.prepare([(key: key, source: track.url)])
                    guard !Task.isCancelled, tracksByID[track.id] != nil else { return }
                    PreparedBrowseArtwork.shared.merge(prepared)
                    browseArtworkRevision += 1
                }
                if var light = saved.track(root: root) {
                    light.id = track.id
                    tracks[index] = light
                }
                detailTracks[track.id]?.artworkKey = saved.artworkKey
                detailTracks[track.id]?.lyricsKey = saved.lyricsKey
                if detailTracks[track.id] != nil {
                    let key = saved.artworkKey
                    let bytes = await Task.detached { ResourceCache.artworkData(key, detail: true) }.value
                    guard !Task.isCancelled, tracksByID[track.id]?.artworkKey == key else { return }
                    detailTracks[track.id]?.artwork = bytes.flatMap(NSImage.init(data:))
                }
            }
        }
    }

    func activeLyricIndex(for lines: [LyricLine]) -> Int? {
        Self.activeLyricIndex(for: lines, at: playbackTime)
    }

    nonisolated static func activeLyricIndex(for lines: [LyricLine], at time: TimeInterval) -> Int? {
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
                self.detailTracks[id]?.duration = actualEnd
            }
            self.playbackFinished(successfully: flag)
        }
    }

    func playbackFinished(successfully: Bool) {
        pause()
        playbackTime = playingTrack?.duration ?? 0
        persistPlaybackPosition()
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
                if Int(self.defaults.double(forKey: "MiniVoice.lastPlaybackTime")) != Int(self.playbackTime) {
                    self.persistPlaybackPosition()
                }
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
        guard seconds.isFinite, seconds > 0 else { return nil }
        return Track(url: url, title: title, artist: artist, album: album, lyrics: "", artwork: artData.flatMap(NSImage.init(data:)), duration: seconds)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
