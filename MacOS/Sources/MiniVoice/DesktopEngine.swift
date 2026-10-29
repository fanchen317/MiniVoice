import UniformTypeIdentifiers
import AppKit
import ImageIO
import MiniVoiceShared
import Combine

/// The Electron shell owns every main-window pixel. This process owns audio,
/// library/cache access, tag writes and the original auxiliary windows.
@MainActor
final class DesktopEngine {
    private let defaults: UserDefaults
    private let library: MusicLibrary
    private let collections: LibraryCollections
    private let volume = SystemVolume()
    private let lyricsSync = LyricsSyncCoordinator()
    private let songIndex = SongListIndex()
    private let desktopLyrics = DesktopLyricsController()
    private lazy var panels = DesktopPanels(library: library, lyricsSync: lyricsSync, volume: volume) { [weak self] action in
        self?.send(["event": "shell", "data": action])
    }
    private var artworkSearches: [String: (UUID, OnlineArtworkResult)] = [:]
    private var artworkSearchRevision = 0
    private var lastInterfaceStyle: String?
    private var observations = Set<AnyCancellable>()
    private var input = Data()
    private var pendingState = false
    private var catalogRevision = -1
    private var artworkRevision = -1
    private let backdropColors = NSCache<NSImage, NSArray>()
    private var timer: Timer?
    private let writer = DispatchQueue(label: "MiniVoice.engine.output", qos: .userInitiated)

    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let delegate = DesktopEngineApplicationDelegate()
        app.delegate = delegate
        let engine = DesktopEngine()
        engine.start()
        withExtendedLifetime((engine, delegate)) { app.run() }
    }

    init(defaults: UserDefaults? = nil) {
        let testDomain = ProcessInfo.processInfo.environment["MINIVOICE_ENGINE_TEST_DOMAIN"]
        let domain = testDomain?.hasPrefix("MiniVoice.Test.") == true ? testDomain! : AppIdentity.bundleIdentifier
        self.defaults = defaults ?? (domain == Bundle.main.bundleIdentifier ? .standard : UserDefaults(suiteName: domain) ?? .standard)
        if self.defaults.object(forKey: "MiniVoice.trackSortField") == nil {
            let old = self.defaults.string(forKey: "MiniVoice.trackSortOrder") ?? "modified"
            self.defaults.set(["artist", "title"].contains(old) ? old : "added", forKey: "MiniVoice.trackSortField")
            self.defaults.set(["artist", "title"].contains(old), forKey: "MiniVoice.trackSortAscending")
        }
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
        if ProcessInfo.processInfo.environment["MINIVOICE_ENGINE_TEST_DOMAIN"] == nil {
            _ = panels
        }
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.scheduleState() } }.store(in: &observations)
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
         "artworkKey": track.artworkKey ?? "", "artworkRevision": library.browseArtworkRevision,
         "favorite": collections.isFavorite(track.url.path)]
    }
    private func detail(_ track: Track?) -> Any {
        guard let track else { return NSNull() }
        var result = row(track)
        if let image = track.artwork {
            if let cached = backdropColors.object(forKey: image) { result["backdropColors"] = cached }
            else if let base = ArtworkPresentation.averageColor(of: image) {
                let rgb = [base.redComponent, base.greenComponent, base.blueComponent]
                let colors = [rgb.map { min(1, $0 * 0.38 + 0.62) }, rgb.map { min(1, $0 * 0.20 + 0.80) }]
                backdropColors.countLimit = 8
                backdropColors.setObject(colors as NSArray, forKey: image)
                result["backdropColors"] = colors
            }
        }
        result["canWriteTags"] = track.canWriteTags
        result["lyrics"] = track.lyrics
        result["lyricsLoading"] = track.lyricsAreLoading || library.loadingLyricsID == track.id
        result["lyricsError"] = library.playingID == track.id ? (library.onlineLyricsError ?? "") : ""
        result["lines"] = track.lyricLines.map { line -> [String: Any] in
            ["time": line.timestamp.map { $0 as Any } ?? NSNull(), "text": line.text,
             "translation": line.translation ?? "", "end": line.endTime.map { $0 as Any } ?? NSNull(),
             "words": line.words.map { ["text": $0.text, "start": $0.start, "end": $0.end.map { $0 as Any } ?? NSNull()] as [String: Any] }]
        }
        return result
    }
    private func publishState() {
        let style = defaults.string(forKey: PlayerInterfaceStyle.preferenceKey) ?? "simple"
        if lastInterfaceStyle != nil, lastInterfaceStyle != style { send(["event": "style", "data": style]) }
        lastInterfaceStyle = style
        if ProcessInfo.processInfo.environment["MINIVOICE_ENGINE_TEST_DOMAIN"] == nil {
            panels.applyAppearance(defaults.string(forKey: "MiniVoice.appearance") ?? "system")
        }
        if catalogRevision != library.tracksRevision || artworkRevision != library.browseArtworkRevision {
            catalogRevision = library.tracksRevision; artworkRevision = library.browseArtworkRevision
            send(["event": "catalog", "data": library.tracks.map(row)])
        }
        send(["event": "state", "data": [
            "interfaceStyle": defaults.string(forKey: PlayerInterfaceStyle.preferenceKey) ?? "simple",
            "sorting": [
                "tracks": ["field": defaults.string(forKey: "MiniVoice.trackSortField") ?? "added", "ascending": defaults.object(forKey: "MiniVoice.trackSortAscending") == nil ? false : defaults.bool(forKey: "MiniVoice.trackSortAscending")] as [String: Any],
                "artists": ["field": defaults.string(forKey: "MiniVoice.artistSortField") ?? "name", "ascending": defaults.object(forKey: "MiniVoice.artistSortAscending") == nil ? true : defaults.bool(forKey: "MiniVoice.artistSortAscending")] as [String: Any],
                "albums": ["field": defaults.string(forKey: "MiniVoice.albumSortField") ?? "name", "ascending": defaults.object(forKey: "MiniVoice.albumSortAscending") == nil ? true : defaults.bool(forKey: "MiniVoice.albumSortAscending")] as [String: Any]
            ],
            "appearance": defaults.string(forKey: "MiniVoice.appearance") ?? "system", "desktopLyrics": desktopLyrics.isEnabled,
            "closeBehavior": defaults.string(forKey: "MiniVoice.closeBehavior") ?? "background",
            "playbackShortcuts": PlaybackShortcutAction.allCases.map { action -> [String: Any] in
                let key = "MiniVoice.playbackShortcut.\(action.rawValue)"
                let shortcut = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(PlaybackShortcut.self, from: $0) } ?? action.defaultShortcut
                return ["action": action.rawValue, "keyCode": shortcut.keyCode, "modifiers": shortcut.modifiers]
            },
            "doubleClickIntervalMs": NSEvent.doubleClickInterval * 1000,
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
            "outputDevice": volume.outputDeviceID, "outputDeviceName": volume.deviceName, "outputError": volume.error ?? "",
            "tasks": ["modelStatus": lyricsSync.modelStatus ?? "", "modelProgress": lyricsSync.modelProgress.map { $0 as Any } ?? NSNull(), "downloadingModel": lyricsSync.downloadingModel, "modelFailed": lyricsSync.modelFailed, "hasUnread": lyricsSync.hasUnread,
                      "notice": lyricsSync.alert.map { ["title": $0.title, "message": $0.message, "kind": $0.kind == .failure ? "failure" : "warning"] as [String: Any] } as Any? ?? NSNull()] as [String: Any],
            "jobs": lyricsSync.jobs.map { ["id": $0.id.uuidString, "title": $0.track.title, "detail": $0.detail, "finished": $0.finished, "failed": $0.failed] as [String: Any] }
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
        case "sharedCore": return try SharedEngine.execute(payload)
        case "portableSnapshot":
            return ["songs": library.tracks.map { item in ["id": item.id.uuidString, "title": item.title, "artist": item.artist, "album": item.album, "duration": Int(item.duration*1000), "artwork": item.artworkKey.map { "minivoice-art://cover/\($0)?v=\(library.browseArtworkRevision)" } ?? ""] as [String: Any] },
                    "favorites": library.tracks.filter { collections.isFavorite($0.url.path) }.map { $0.id.uuidString },
                    "recent": library.recentPaths.compactMap { path in library.tracks.first { $0.url.path == path }?.id.uuidString },
                    "queue": library.playbackIDs.map(\.uuidString), "mode": library.playbackMode.rawValue,
                    "playlists": collections.playlists.map { list in ["id": list.id.uuidString, "name": list.name, "ids": library.tracks.filter { list.paths.contains($0.url.path) }.map { $0.id.uuidString }] as [String: Any] },
                    "capabilities": ["favorite", "mode", "queueSelect", "createPlaylist", "addToPlaylist", "settings"],
                    "current": library.playingTrack?.id.uuidString as Any? ?? NSNull(), "position": Int(library.playbackTime*1000), "playing": library.isPlaying, "rawLyrics": library.playingTrack?.lyrics ?? ""] as [String: Any]
        case "openSettings":
            if AppIdentity.isDebug { send(["event":"uiSurface","data":["type":"settings"]]) } else { panels.showSettings() }; return true
        case "openEditor":
            let selected = try track(payload)
            if AppIdentity.isDebug { send(["event":"uiSurface","data":["type":"editor","id":selected.id.uuidString]]) } else { panels.showEditor(selected) }; return true
        case "interfaceStyle":
            if let value = payload["value"] as? String, PlayerInterfaceStyle(rawValue: value) != nil {
                // The renderer already applied this explicit change.
                lastInterfaceStyle = value; defaults.set(value, forKey: PlayerInterfaceStyle.preferenceKey)
            }
            return true
        case "desktopSettings":
            let windowKey = WindowToggleController.preferenceKey
            let windowShortcut = defaults.data(forKey: windowKey).flatMap { try? JSONDecoder().decode(PlaybackShortcut.self, from: $0) } ?? WindowToggleController.defaultShortcut
            return ["closeBehavior":defaults.string(forKey:"MiniVoice.closeBehavior") ?? "background",
                    "statusIconStyle":defaults.string(forKey:StatusBarController.preferenceKey) ?? "colored",
                    "lyricsModel":defaults.string(forKey:"MiniVoice.lyricsModel") ?? "small",
                    "windowShortcut":["keyCode":windowShortcut.keyCode,"modifiers":windowShortcut.modifiers,"label":windowShortcut.description],
                    "shortcuts":PlaybackShortcutAction.allCases.map { action -> [String:Any] in
                        let shortcut = defaults.data(forKey:"MiniVoice.playbackShortcut.\(action.rawValue)").flatMap { try? JSONDecoder().decode(PlaybackShortcut.self,from:$0) } ?? action.defaultShortcut
                        return ["action":action.rawValue,"keyCode":shortcut.keyCode,"modifiers":shortcut.modifiers,"label":shortcut.description]
                    },
                    "models":LyricsModel.allCases.map { model in ["id":model.rawValue,"name":model.title,"bundled":LyricsAlignment.isBundled(model),"installed":lyricsSync.installedModels.contains(model)] as [String:Any] }] as [String:Any]
        case "desktopPreference":
            guard let key = payload["key"] as? String, let value = payload["value"] as? String else { throw CocoaError(.coderInvalidValue) }
            let allowed = ["closeBehavior":["background","pause","quit"],"statusIconStyle":["hidden","colored","monochrome"],"lyricsModel":["small","medium"]]
            guard allowed[key]?.contains(value) == true else { throw CocoaError(.coderInvalidValue) }
            defaults.set(value,forKey:"MiniVoice.\(key)");publishState();return true
        case "desktopShortcut":
            guard let action = payload["action"] as? String, let code = payload["keyCode"] as? Int, (0...126).contains(code), let flags = payload["modifiers"] as? UInt else { throw CocoaError(.coderInvalidValue) }
            let shortcut = PlaybackShortcut(keyCode:UInt16(code),modifiers:NSEvent.ModifierFlags(rawValue:flags))
            guard PlaybackShortcutAction(rawValue:action) != nil || action == "window" else { throw CocoaError(.coderInvalidValue) }
            for other in PlaybackShortcutAction.allCases where other.rawValue != action {
                let existing = defaults.data(forKey:"MiniVoice.playbackShortcut.\(other.rawValue)").flatMap { try? JSONDecoder().decode(PlaybackShortcut.self,from:$0) } ?? other.defaultShortcut
                if existing == shortcut { throw NSError(domain:"MiniVoice",code:3,userInfo:[NSLocalizedDescriptionKey:"与\(other.title)快捷键冲突"]) }
            }
            if action == "window" { guard flags & ((1<<18)|(1<<19)|(1<<20)) != 0 else { throw CocoaError(.coderInvalidValue) };panels.configureWindowShortcut(shortcut) }
            else { defaults.set(try JSONEncoder().encode(shortcut),forKey:"MiniVoice.playbackShortcut.\(action)") }
            publishState();return true
        case "lyricsModel":
            guard let model = LyricsModel(rawValue:payload["id"] as? String ?? ""),lyricsSync.activeCount == 0,!lyricsSync.downloadingModel else { throw NSError(domain:"MiniVoice",code:4,userInfo:[NSLocalizedDescriptionKey:"请等待当前歌词任务完成"]) }
            if payload["operation"] as? String == "download" { lyricsSync.download(model) }
            else if payload["operation"] as? String == "delete" { guard !LyricsAlignment.isBundled(model) else { throw CocoaError(.fileWriteNoPermission) };lyricsSync.deleteModel(model) }
            else { throw CocoaError(.coderInvalidValue) };return true
        case "sorting":
            let category = payload["category"] as? String ?? "tracks"
            guard ["tracks", "artists", "albums"].contains(category) else { return false }
            let prefix = category == "tracks" ? "track" : category == "artists" ? "artist" : "album"
            let field = payload["field"] as? String ?? ""
            guard (category == "tracks" ? ["title", "artist", "album", "sourceAdded", "added"] : ["name", "count"]).contains(field) else { return false }
            defaults.set(field, forKey: "MiniVoice.\(prefix)SortField")
            defaults.set(payload["ascending"] as? Bool ?? true, forKey: "MiniVoice.\(prefix)SortAscending")
            return true
        case "tasks":
            switch payload["operation"] as? String {
            case "read": lyricsSync.hasUnread = false
            case "clearFinished": lyricsSync.clearFinished(); lyricsSync.alert = nil
            case "clearNotice": lyricsSync.alert = nil
            case "clearModel": lyricsSync.clearModelResult()
            case "retryModel": lyricsSync.retryModel()
            case "clear": if let id = UUID(uuidString: payload["id"] as? String ?? "") { lyricsSync.clear(id) }
            case "retry": if let id = UUID(uuidString: payload["id"] as? String ?? "") { lyricsSync.retry(id, library: library) }
            default: return false
            }
            return true
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
            if payload["preservePosition"] as? Bool == true, library.playingID == track.id {
                if !library.isPlaying { library.play() }
            } else { library.play(track.id, in: ids) }
            return true
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
        case "addManyToPlaylist":
            let ids = Set((payload["ids"] as? [String] ?? []).compactMap(UUID.init(uuidString:)))
            if let id = UUID(uuidString: payload["playlist"] as? String ?? "") { return collections.add(library.tracks.filter { ids.contains($0.id) }.map { $0.url.path }, to: id) }; return 0
        case "removeManyFromPlaylist":
            let ids = Set((payload["ids"] as? [String] ?? []).compactMap(UUID.init(uuidString:)))
            if let id = UUID(uuidString: payload["playlist"] as? String ?? "") {
                for track in library.tracks where ids.contains(track.id) { collections.remove(track.url.path, from: id) }
            }
            return true
        case "removeFromPlaylist":
            if let id = UUID(uuidString: payload["playlist"] as? String ?? "") { collections.remove(try track(payload).url.path, from: id) }; return true
        case "clearRecent": library.clearRecentPlayback(); return true
        case "prepareOriginalArtwork":
            guard let key = payload["key"] as? String, key.count == 64,
                  let item = library.tracks.first(where: { $0.artworkKey == key }) else { throw CocoaError(.fileReadNoSuchFile) }
            let target = ResourceCache.url(key, kind: "Artwork/Original")
            if ResourceCache.isValidArtwork(try? Data(contentsOf: target)) { ResourceCache.touch(target); return true }
            let sourceURL = item.url
            let bytes = await Task.detached { () -> Data? in
                let before = FileStamp.read(sourceURL)
                guard let data = try? MediaTools.run("ffmpeg", ["-nostdin", "-v", "error", "-i", sourceURL.path, "-map", "0:v:0", "-frames:v", "1", "-c:v", "copy", "-f", "image2pipe", "pipe:1"]),
                      before == FileStamp.read(sourceURL), ResourceCache.isValidArtwork(data) else { return nil }
                guard let imageSource = CGImageSourceCreateWithData(data as CFData,nil) else { return nil }
                let mime = CGImageSourceGetType(imageSource).flatMap { UTType($0 as String)?.preferredMIMEType }
                if ["image/jpeg","image/png","image/webp","image/gif","image/bmp"].contains(mime ?? "") { return data }
                guard let image = CGImageSourceCreateImageAtIndex(imageSource,0,nil) else { return nil }
                return NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])
            }.value
            var original = bytes
            if original == nil, let full = await library.resolveTrack(item.id, fullResolution: true),
               let tiff = full.artwork?.tiffRepresentation, let bitmap = NSBitmapImageRep(data:tiff) {
                original = bitmap.representation(using:.png,properties:[:])
            }
            guard let bytes = original, library.tracks.contains(where: { $0.id == item.id && $0.artworkKey == key }) else { throw CocoaError(.fileReadCorruptFile) }
            try ResourceCache.atomicWrite(bytes, to: target); return true
        case "detail": return detail(await library.resolveTrack(try track(payload).id))
        case "reveal": NSWorkspace.shared.activateFileViewerSelecting([try track(payload).url]); return true
        case "desktopLyrics":
            if AppIdentity.isDebug { send(["event":"hostSurface","data":["type":"desktopLyrics"]]);return true };desktopLyrics.toggle(); return desktopLyrics.isEnabled
        case "outputDevice": volume.selectOutputDevice(UInt32(max(0, min(Double(UInt32.max), finite(payload, "id"))))); return ["ok": volume.error == nil, "error": volume.error ?? ""] as [String: Any]
        case "clearError": library.errorMessage = nil; return true
        case "artworkSearch":
            let item = try track(payload)
            artworkSearchRevision += 1
            let revision = artworkSearchRevision
            let found = try await OnlineArtworkSearch.search(title: String((payload["title"] as? String ?? item.title).prefix(500)), artist: String((payload["artist"] as? String ?? item.artist).prefix(500)), album: String((payload["album"] as? String ?? item.album).prefix(500)))
            guard revision == artworkSearchRevision else { throw CancellationError() }
            artworkSearches.removeAll()
            return found.prefix(80).map { result -> [String:String] in
                let token = UUID().uuidString
                artworkSearches[token] = (item.id,result)
                return ["token":token,"album":result.album,"artist":result.artist,"source":result.source]
            }
        case "artworkDownload":
            let item = try track(payload)
            guard let token = payload["token"] as? String, let result = artworkSearches[token], result.0 == item.id else { throw NSError(domain:"MiniVoice",code:5,userInfo:[NSLocalizedDescriptionKey:"封面搜索结果已失效，请重新搜索"]) }
            let downloaded = try await OnlineArtworkSearch.download(result.1)
            guard downloaded.data.count <= 20 * 1024 * 1024, let source = CGImageSourceCreateWithData(downloaded.data as CFData,nil), let type = CGImageSourceGetType(source) else { throw CocoaError(.fileReadCorruptFile) }
            let mime = UTType(type as String)?.preferredMIMEType ?? "image/png"
            return "data:\(mime);base64," + downloaded.data.base64EncodedString()
        case "lyricsSearch":
            let track = try track(payload)
            return try await OnlineLyricsSearch.search(title: String((payload["title"] as? String ?? track.title).prefix(500)), artist: String((payload["artist"] as? String ?? track.artist).prefix(500)), duration: track.duration).map { result -> [String: Any] in
                ["id": result.id, "source": result.source, "title": result.trackName, "artist": result.artistName, "album": result.albumName ?? "", "duration": result.duration ?? 0, "timingKind": result.timingKind.rawValue, "hasTranslation": result.hasTranslation, "lyrics": result.usableLyrics ?? ""]
            }
        case "downloadMissingLyrics":
            let base = try track(payload)
            guard let original = await library.resolveTrack(base.id), original.lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NSError(domain: "MiniVoice", code: 6, userInfo: [NSLocalizedDescriptionKey: "歌曲已有歌词，请使用在线搜索预览后替换"])
            }
            let candidates = try await OnlineLyricsSearch.search(title: original.title, artist: original.artist, duration: original.duration, album: original.album)
            let matches = candidates.filter {
                LyricsSearchText.key($0.trackName) == LyricsSearchText.key(original.title)
                    && LyricsSearchText.key($0.artistName) == LyricsSearchText.key(original.artist)
                    && ($0.duration.map { abs($0 - original.duration) <= 10 } ?? false)
            }.sorted { $0.timingKind == .word && $1.timingKind != .word }
            guard let text = matches.first?.usableLyrics else {
                throw NSError(domain: "MiniVoice", code: 6, userInfo: [NSLocalizedDescriptionKey: "未找到可靠匹配，请使用在线搜索预览候选歌词"])
            }
            guard var latest = await library.resolveTrack(base.id), latest.lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NSError(domain: "MiniVoice", code: 6, userInfo: [NSLocalizedDescriptionKey: "歌词已变化，未覆盖现有歌词"])
            }
            latest.lyrics = text
            try await library.save(latest, lyricsDestination: .sidecar)
            return text
        case "syncLyrics":
            if let resolved = await library.resolveTrack(try track(payload).id) { lyricsSync.start(track: resolved, destination: .sidecar, library: library) }; return true
        case "saveMetadata":
            let base = try track(payload)
            guard var resolved = await library.resolveTrack(base.id, fullResolution: true) else { throw CocoaError(.fileReadNoSuchFile) }
            resolved.title = payload["title"] as? String ?? resolved.title
            resolved.artist = payload["artist"] as? String ?? resolved.artist
            resolved.album = payload["album"] as? String ?? resolved.album
            resolved.lyrics = payload["lyrics"] as? String ?? resolved.lyrics
            if let translation = payload["translation"] as? String { resolved.lyrics = LyricsTranslation.attaching(translation,to:resolved.lyrics) }
            if let artwork = payload["artwork"] as? String {
                guard artwork.hasPrefix("data:image/"),let separator=artwork.firstIndex(of:","),let data=Data(base64Encoded:String(artwork[artwork.index(after:separator)...])),data.count<=20*1024*1024,let image=NSImage(data:data),image.size.width>0,image.size.height>0 else { throw CocoaError(.coderInvalidValue) }
                resolved.artwork=image;resolved.artworkWasEdited=true
            }
            let destination: LyricsDestination = payload["destination"] as? String == "tags" ? .tags : .sidecar
            try await library.save(resolved, lyricsDestination: destination); return true
        case "deleteTracks":
            let ids = Set((payload["ids"] as? [String] ?? []).compactMap(UUID.init(uuidString:)))
            library.deleteTracks(ids: ids, moveFilesToTrash: payload["trash"] as? Bool ?? false); return true
        case "removeTrack": library.deleteTracks(ids: [try track(payload).id], moveFilesToTrash: false); return true
        case "shutdown": library.pause(); defaults.synchronize(); NSApp.terminate(nil); return true
        default: throw NSError(domain: "MiniVoice", code: 2, userInfo: [NSLocalizedDescriptionKey: "不支持的后台命令：\(action)"])
        }
    }
}

/// Closing an auxiliary window must never end the audio service.
@MainActor
private final class DesktopEngineApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
