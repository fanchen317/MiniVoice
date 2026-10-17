import AppKit
import Combine

/// The Electron shell owns every main-window pixel. This process owns audio,
/// library/cache access and tag writes; JSON lines are its only UI transport.
@MainActor
final class DesktopEngine {
    private let defaults: UserDefaults
    private let library: MusicLibrary
    private let collections: LibraryCollections
    private let volume = SystemVolume()
    private let lyricsSync = LyricsSyncCoordinator()
    private let songIndex = SongListIndex()
    private let desktopLyrics = DesktopLyricsController()
    private var observations = Set<AnyCancellable>()
    private var input = Data()
    private var pendingState = false
    private var catalogRevision = -1
    private var artworkRevision = -1
    private var timer: Timer?
    private let writer = DispatchQueue(label: "MiniVoice.engine.output", qos: .userInitiated)

    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let engine = DesktopEngine()
        engine.start()
        withExtendedLifetime(engine) { app.run() }
    }

    init(defaults: UserDefaults? = nil) {
        let testDomain = ProcessInfo.processInfo.environment["MINIVOICE_ENGINE_TEST_DOMAIN"]
        let domain = testDomain?.hasPrefix("MiniVoice.Test.") == true ? testDomain! : AppIdentity.bundleIdentifier
        self.defaults = defaults ?? (domain == Bundle.main.bundleIdentifier ? .standard : UserDefaults(suiteName: domain) ?? .standard)
        library = MusicLibrary(defaults: self.defaults, scanOnLaunch: false)
        collections = LibraryCollections(defaults: self.defaults)
        volume.connect(library: library)
        desktopLyrics.connect(library: library)
    }

    private func send(_ message: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(message),
              var data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]) else { return }
        data.append(10)
        let bytes = data
        writer.async { try? FileHandle.standardOutput.write(contentsOf: bytes) }
    }

    private func start() {
        library.objectWillChange.sink { [weak self] _ in self?.scheduleState() }.store(in: &observations)
        collections.objectWillChange.sink { [weak self] _ in self?.scheduleState() }.store(in: &observations)
        lyricsSync.objectWillChange.sink { [weak self] _ in self?.scheduleState() }.store(in: &observations)
        volume.objectWillChange.sink { [weak self] _ in self?.scheduleState() }.store(in: &observations)
        timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.send(["event": "clock", "data": ["time": self.library.playbackTime,
                    "playing": self.library.isPlaying, "duration": self.library.playingTrack?.duration ?? 0]])
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
        FileHandle.standardInput.readabilityHandler = { [weak self] handle in
            let bytes = handle.availableData
            Task { @MainActor in
                guard let self else { return }
                if bytes.isEmpty { self.library.pause(); NSApp.terminate(nil); return }
                self.receive(bytes)
            }
        }
        send(["event": "ready", "data": ["protocol": 1, "artworkRoot": ResourceCache.directory.path]])
        publishState()
        library.rescan(preferCache: true)
    }

    private func receive(_ data: Data) {
        input.append(data)
        guard input.count <= 8 * 1024 * 1024 else { input.removeAll(); return }
        while let newline = input.firstIndex(of: 10) {
            let line = input[..<newline]; input.removeSubrange(...newline)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let id = object["id"] as? String, let action = object["action"] as? String else { continue }
            let payload = object["payload"] as? [String: Any] ?? [:]
            Task {
                do {
                    let result = try await command(action, payload)
                    send(["id": id, "result": result])
                    scheduleState()
                } catch { send(["id": id, "error": error.localizedDescription]) }
            }
        }
    }

    private func scheduleState() {
        guard !pendingState else { return }
        pendingState = true
        DispatchQueue.main.async { [weak self] in self?.pendingState = false; self?.publishState() }
    }
    private func row(_ track: Track) -> [String: Any] {
        ["id": track.id.uuidString, "path": track.url.path, "title": track.title, "artist": track.artist,
         "album": track.album, "duration": track.duration.isFinite ? track.duration : 0,
         "artworkKey": track.artworkKey ?? "", "favorite": collections.isFavorite(track.url.path)]
    }
    private func detail(_ track: Track?) -> Any {
        guard let track else { return NSNull() }
        var result = row(track)
        result["lyrics"] = track.lyrics
        result["lines"] = track.lyricLines.map { line -> [String: Any] in
            ["time": line.timestamp.map { $0 as Any } ?? NSNull(), "text": line.text,
             "translation": line.translation ?? "", "end": line.endTime.map { $0 as Any } ?? NSNull(),
             "words": line.words.map { ["text": $0.text, "start": $0.start, "end": $0.end.map { $0 as Any } ?? NSNull()] as [String: Any] }]
        }
        return result
    }
    private func publishState() {
        if catalogRevision != library.tracksRevision || artworkRevision != library.browseArtworkRevision {
            catalogRevision = library.tracksRevision; artworkRevision = library.browseArtworkRevision
            send(["event": "catalog", "data": library.tracks.map(row)])
        }
        send(["event": "state", "data": [
            "appearance": defaults.string(forKey: "MiniVoice.appearance") ?? "system", "desktopLyrics": desktopLyrics.isEnabled,
            "wallLyricsStyle": defaults.string(forKey: "MiniVoice.musicWallLyricsStyle") ?? "scrolling",
            "showLyricsTranslation": defaults.object(forKey: "MiniVoice.showLyricsTranslation") == nil ? true : defaults.bool(forKey: "MiniVoice.showLyricsTranslation"),
            "selected": detail(library.selectedTrack), "playing": detail(library.playingTrack),
            "isPlaying": library.isPlaying, "preparing": library.isPreparingPlayback,
            "volume": library.volume, "mode": library.playbackMode.rawValue,
            "importing": library.isImporting, "scanSummary": library.scanSummary,
            "issues": library.scanIssues, "error": library.errorMessage ?? "",
            "folders": library.folders.map(\.path), "recursive": library.recursiveScan,
            "recent": library.recentPaths,
            "queue": library.playbackIDs.map(\.uuidString),
            "favorites": library.tracks.filter { collections.isFavorite($0.url.path) }.map { $0.url.path },
            "playlists": collections.playlists.map { ["id": $0.id.uuidString, "name": $0.name, "paths": $0.paths] as [String: Any] },
            "outputDevices": volume.outputDevices.map { ["id": $0.id, "name": $0.name] as [String: Any] },
            "outputDevice": volume.outputDeviceID,
            "jobs": lyricsSync.jobs.map { ["id": $0.id.uuidString, "detail": $0.detail, "finished": $0.finished, "failed": $0.failed] as [String: Any] }
        ]])
    }

    private func track(_ payload: [String: Any]) throws -> Track {
        guard let raw = payload["id"] as? String, let id = UUID(uuidString: raw), let track = library.track(for: id) else {
            throw NSError(domain: "MiniVoice", code: 1, userInfo: [NSLocalizedDescriptionKey: "歌曲已移除，请刷新后重试。"])
        }
        return track
    }
    private func finite(_ payload: [String: Any], _ key: String, default value: Double = 0) -> Double {
        let result = payload[key] as? Double ?? value
        return result.isFinite ? result : value
    }
    private func command(_ action: String, _ payload: [String: Any]) async throws -> Any {
        switch action {
        case "orderedTracks":
            let field = payload["field"] as? String ?? "title"
            guard ["title", "artist", "album", "sourceAdded", "added"].contains(field) else { return [] }
            let entries = library.tracks.map { SongListEntry(id: $0.id, url: $0.url, title: $0.title, artist: $0.artist, album: $0.album) }
            let request = SongListRequest(revision: library.tracksRevision, field: field, ascending: payload["ascending"] as? Bool ?? true)
            return await songIndex.orderedIDs(entries, request: request).map(\.uuidString)
        case "lyricsPresentation":
            if let style = payload["style"] as? String, ["scrolling", "kinetic"].contains(style) { defaults.set(style, forKey: "MiniVoice.musicWallLyricsStyle") }
            if let translation = payload["translation"] as? Bool { defaults.set(translation, forKey: "MiniVoice.showLyricsTranslation") }
            publishState(); return true
        case "favoriteMany":
            let ids = Set((payload["ids"] as? [String] ?? []).compactMap(UUID.init(uuidString:)))
            collections.setFavorites(library.tracks.filter { ids.contains($0.id) }.map { $0.url.path }, favorite: payload["value"] as? Bool ?? true)
            publishState(); return true
        case "appearance":
            if let value = payload["value"] as? String, ["system", "light", "dark"].contains(value) { defaults.set(value, forKey: "MiniVoice.appearance") }
            publishState(); return true
        case "snapshot": catalogRevision = -1; publishState(); return true
        case "play":
            let track = try track(payload)
            let ids = (payload["ids"] as? [String])?.compactMap(UUID.init(uuidString:))
            library.play(track.id, in: ids); return true
        case "select": library.select(try track(payload).id); return true
        case "toggle": library.togglePlayback(); return true
        case "pause": library.pause(); return true
        case "seek": library.seek(to: max(0, min(library.playingTrack?.duration ?? 0, finite(payload, "time")))); return true
        case "skip": library.skip(finite(payload, "delta") < 0 ? -1 : 1); return true
        case "volume": library.volume = Float(min(1, max(0, finite(payload, "value")))); return true
        case "mode": if let mode = PlaybackMode(rawValue: payload["value"] as? String ?? "") { library.playbackMode = mode }; return true
        case "favorite": collections.toggleFavorite(try track(payload).url.path); return true
        case "rescan": library.rescan(); return true
        case "addFolders": library.addFolders((payload["paths"] as? [String] ?? []).map { URL(fileURLWithPath: $0) }); return true
        case "removeFolder":
            if let path = payload["path"] as? String, let folder = library.folders.first(where: { $0.path == path }) { library.removeFolder(folder) }; return true
        case "recursive": library.recursiveScan = payload["value"] as? Bool ?? true; return true
        case "createPlaylist": return collections.createPlaylist(name: payload["name"] as? String ?? "")?.uuidString ?? ""
        case "renamePlaylist": if let id = UUID(uuidString: payload["playlist"] as? String ?? "") { collections.renamePlaylist(id, name: payload["name"] as? String ?? "") }; return true
        case "deletePlaylist": if let id = UUID(uuidString: payload["playlist"] as? String ?? "") { collections.deletePlaylist(id) }; return true
        case "addToPlaylist":
            if let id = UUID(uuidString: payload["playlist"] as? String ?? "") { return collections.add([try track(payload).url.path], to: id) }; return 0
        case "removeFromPlaylist":
            if let id = UUID(uuidString: payload["playlist"] as? String ?? "") { collections.remove(try track(payload).url.path, from: id) }; return true
        case "clearRecent": library.clearRecentPlayback(); return true
        case "detail": return detail(await library.resolveTrack(try track(payload).id))
        case "reveal": NSWorkspace.shared.activateFileViewerSelecting([try track(payload).url]); return true
        case "desktopLyrics": desktopLyrics.toggle(); return desktopLyrics.isEnabled
        case "outputDevice": volume.selectOutputDevice(UInt32(max(0, min(Double(UInt32.max), finite(payload, "id"))))); return true
        case "clearError": library.errorMessage = nil; return true
        case "lyricsSearch":
            let track = try track(payload)
            return try await OnlineLyricsSearch.search(title: track.title, artist: track.artist, duration: track.duration).map {
                ["id": $0.id, "source": $0.source, "title": $0.trackName, "artist": $0.artistName, "lyrics": $0.usableLyrics ?? ""]
            }
        case "syncLyrics":
            if let resolved = await library.resolveTrack(try track(payload).id) { lyricsSync.start(track: resolved, destination: .sidecar, library: library) }; return true
        case "saveMetadata":
            let base = try track(payload)
            guard var resolved = await library.resolveTrack(base.id, fullResolution: true) else { throw CocoaError(.fileReadNoSuchFile) }
            resolved.title = payload["title"] as? String ?? resolved.title
            resolved.artist = payload["artist"] as? String ?? resolved.artist
            resolved.album = payload["album"] as? String ?? resolved.album
            resolved.lyrics = payload["lyrics"] as? String ?? resolved.lyrics
            let destination: LyricsDestination = payload["destination"] as? String == "tags" ? .tags : .sidecar
            try await library.save(resolved, lyricsDestination: destination); return true
        case "removeTrack": library.deleteTracks(ids: [try track(payload).id], moveFilesToTrash: false); return true
        case "shutdown": library.pause(); defaults.synchronize(); NSApp.terminate(nil); return true
        default: throw NSError(domain: "MiniVoice", code: 2, userInfo: [NSLocalizedDescriptionKey: "不支持的后台命令：\(action)"])
        }
    }
}
