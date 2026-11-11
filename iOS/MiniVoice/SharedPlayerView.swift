import SwiftUI
import WebKit
import Combine
import UniformTypeIdentifiers
import MiniVoiceShared
import ImageIO

/// A single Shared/UI rendering surface owns all music-wall pixels and interaction.
/// Swift supplies system services and never projects or snapshots a playing card.
struct SharedPlayerView: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var player: MusicPlayer
    @State private var choosingFolder = false
    @State private var immersive = false
    @State private var exporting = false
    @State private var archive = Data()

    var body: some View {
        SharedPlayerWebView(library: library, player: player, chooseFolder: { choosingFolder = true },
                            immersive: { immersive = $0 }, export: { archive = $0; exporting = true })
            .ignoresSafeArea()
            .background(Color(red: 24/255, green: 39/255, blue: 32/255).ignoresSafeArea())
            .task {
                guard !ProcessInfo.processInfo.arguments.contains("--mv-ui-fixture") else { return }
                let key = "notificationPermissionIntroduced"
                guard !UserDefaults.standard.bool(forKey: key) else { return }
                UserDefaults.standard.set(true, forKey: key)
                do { _ = try await library.scanSession.requestNotifications() }
                catch { library.errorMessage = "通知权限请求失败：\(error.localizedDescription)" }
                if library.folders.isEmpty { choosingFolder = true }
            }
            .statusBarHidden(immersive)
            .persistentSystemOverlays(immersive ? .hidden : .automatic)
            .fileExporter(isPresented: $exporting, document: DiagnosticsDocument(data: archive), contentType: .zip, defaultFilename: "MiniVoice-diagnostics.zip") { result in
                if case .failure(let error) = result, (error as NSError).code != NSUserCancelledError { library.errorMessage = "导出失败：\(error.localizedDescription)" }
            }
            .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): urls.forEach(library.addFolder)
                case .failure(let error): if (error as NSError).code != NSUserCancelledError { library.errorMessage = "无法选择音乐文件夹：\(error.localizedDescription)" }
                }
            }
    }
}

private struct SharedPlayerWebView: UIViewRepresentable {
    let library: MusicLibrary
    let player: MusicPlayer
    let chooseFolder: () -> Void
    let immersive: (Bool) -> Void
    let export: (Data) -> Void

    func makeCoordinator() -> SharedPlayerHost { SharedPlayerHost(library: library, player: player, chooseFolder: chooseFolder, immersive: immersive, export: export) }

    func makeUIView(context: Context) -> UIView {
        let host = context.coordinator
        host.beginWebSession(.created)
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(host, forURLScheme: "minivoice")
        configuration.ignoresViewportScaleLimits = false
        configuration.dataDetectorTypes = []
        configuration.userContentController.add(host, name: "MiniVoice")
        host.installBridgeScript(in: configuration.userContentController)
        let web = SharedContentWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = host
        web.isOpaque = true
        web.backgroundColor = UIColor(red: 24/255, green: 39/255, blue: 32/255, alpha: 1)
        web.scrollView.backgroundColor = web.backgroundColor
        web.underPageBackgroundColor = web.backgroundColor!
        web.scrollView.isScrollEnabled = false
        web.scrollView.pinchGestureRecognizer?.isEnabled = false
        web.scrollView.bouncesZoom = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        #if DEBUG
        web.isInspectable = true
        #endif
        let surface = UIView()
        surface.isOpaque = true
        surface.backgroundColor = web.backgroundColor
        surface.addSubview(web)
        web.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([web.leadingAnchor.constraint(equalTo: surface.leadingAnchor), web.trailingAnchor.constraint(equalTo: surface.trailingAnchor), web.topAnchor.constraint(equalTo: surface.topAnchor), web.bottomAnchor.constraint(equalTo: surface.bottomAnchor)])
        // Native startup chrome covers the web surface until the shared page has
        // restored its initial state. It has no fixed minimum display duration.
        let splash = UIView()
        splash.backgroundColor = UIColor(named: "LaunchBackground")
        splash.translatesAutoresizingMaskIntoConstraints = false
        let logo = UIImageView(image: UIImage(named: "LaunchLogo"))
        logo.contentMode = .scaleAspectFit
        logo.layer.cornerRadius = 20
        logo.clipsToBounds = true
        logo.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.text = "MiniVoice"
        title.font = .systemFont(ofSize: 27, weight: .semibold)
        title.textColor = .label
        title.translatesAutoresizingMaskIntoConstraints = false
        splash.addSubview(logo)
        splash.addSubview(title)
        surface.addSubview(splash)
        NSLayoutConstraint.activate([
            splash.leadingAnchor.constraint(equalTo: surface.leadingAnchor), splash.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            splash.topAnchor.constraint(equalTo: surface.topAnchor), splash.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
            logo.centerXAnchor.constraint(equalTo: splash.centerXAnchor), logo.centerYAnchor.constraint(equalTo: splash.centerYAnchor, constant: -28),
            logo.widthAnchor.constraint(equalToConstant: 88), logo.heightAnchor.constraint(equalToConstant: 88),
            title.centerXAnchor.constraint(equalTo: splash.centerXAnchor), title.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: 20)
        ])
        splash.isAccessibilityElement = true
        splash.accessibilityLabel = "MiniVoice，正在载入"
        host.startupCover = splash
        host.web = web
        host.trackNavigation(web.load(URLRequest(url: URL(string: "minivoice://app/index.html")!)))
        return surface
    }

    func updateUIView(_ view: UIView, context: Context) {}

    static func dismantleUIView(_ view: UIView, coordinator: SharedPlayerHost) {
        coordinator.disconnect()
        guard let web = coordinator.web else { return }
        web.configuration.userContentController.removeScriptMessageHandler(forName: "MiniVoice")
        web.stopLoading()
        coordinator.web = nil
    }
}

@MainActor
private final class SharedPlayerHost: NSObject, WKScriptMessageHandler, WKURLSchemeHandler, WKNavigationDelegate {
    weak var web: WKWebView?
    weak var startupCover: UIView?
    let library: MusicLibrary
    let player: MusicPlayer
    let chooseFolder: () -> Void
    let immersive: (Bool) -> Void
    let export: (Data) -> Void
    private var subscriptions = Set<AnyCancellable>()
    private var catalogRevision = UUID().uuidString
    private var artworkEpoch = ""
    private var rows: [[String: Any]] = []
    private var snapshotMetadata = SnapshotMetadataCache()
    private var songsByID: [String: Song] = [:]
    private let styleFragments = StyleFragmentSession()
    private var activeLoads = Set<ObjectIdentifier>()
    private var resourceTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var artworkActive = 0
    private var artworkPeak = 0
    private var artworkWaiters: [(ObjectIdentifier, CheckedContinuation<Void, Error>)] = []
    private var webTerminations = 0
    private var webDiagnostics = WebHostDiagnostics()
    private var navigationGenerations: [ObjectIdentifier: UInt64] = [:]
    private var bridgeScript: WKUserScript?

    private var artworkConcurrency: Int {
        let thermal = ProcessInfo.processInfo.thermalState
        return ProcessInfo.processInfo.isLowPowerModeEnabled || thermal == .serious || thermal == .critical ? 1 : 2
    }
    private func acquireArtwork(_ id: ObjectIdentifier, priority: Bool) async throws {
        try Task.checkCancellation()
        if artworkActive < artworkConcurrency { artworkActive += 1; artworkPeak = max(artworkPeak, artworkActive); return }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in if priority { artworkWaiters.insert((id, continuation), at: 0) } else { artworkWaiters.append((id, continuation)) } }
        } onCancel: { Task { @MainActor [weak self] in self?.cancelArtworkWaiter(id) } }
        if Task.isCancelled { releaseArtwork(); throw CancellationError() }
    }
    private func cancelArtworkWaiter(_ id: ObjectIdentifier) {
        guard let index = artworkWaiters.firstIndex(where: { $0.0 == id }) else { return }
        artworkWaiters.remove(at: index).1.resume(throwing: CancellationError())
    }
    private func releaseArtwork() {
        if artworkWaiters.isEmpty || artworkActive > artworkConcurrency { artworkActive -= 1 }
        else { artworkWaiters.removeFirst().1.resume() }
    }
    private var notice = ""
    private var noticeToken = 0
    private var lastError = ""
    private let stateWorker = DispatchQueue(label: "MiniVoice.shared-state", qos: .utility)
    private let stateURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MiniVoice/shared-mobile-workspace-v1.json")

    init(library: MusicLibrary, player: MusicPlayer, chooseFolder: @escaping () -> Void, immersive: @escaping (Bool) -> Void, export: @escaping (Data) -> Void) {
        self.library = library; self.player = player; self.chooseFolder = chooseFolder
        self.immersive = immersive; self.export = export
        super.init()
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification).sink { [weak self] _ in
            guard let self else { return }
            Task { await self.library.invalidateArtworkMemory() }
            IOSDiagnostics.shared.record(.event, "memory warning artworkActive=\(self.artworkActive)")
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).sink { [weak self] _ in
            self?.styleFragments.cancel()
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification).sink { [weak self] _ in
            if UIAccessibility.isReduceMotionEnabled { self?.styleFragments.cancel() }
        }.store(in: &subscriptions)
        // @Published emits its current value synchronously on subscription.
        // makeCoordinator runs during a SwiftUI view update; retainLibrary below
        // publishes player state, so deliver catalog changes after that update.
        library.$songs.receive(on: DispatchQueue.main).sink { [weak self] songs in self?.updateCatalog(songs) }.store(in: &subscriptions)
        library.$favorites.sink { [weak self] _ in self?.snapshotMetadata.invalidate() }.store(in: &subscriptions)
        library.$recentIDs.sink { [weak self] _ in self?.snapshotMetadata.invalidate() }.store(in: &subscriptions)
        library.$playlists.sink { [weak self] _ in self?.snapshotMetadata.invalidate() }.store(in: &subscriptions)
        library.$importedLyrics.sink { [weak self] _ in self?.snapshotMetadata.invalidate() }.store(in: &subscriptions)
        player.$current.sink { [weak self] _ in self?.snapshotMetadata.invalidate() }.store(in: &subscriptions)
        player.$queue.sink { [weak self] _ in self?.snapshotMetadata.invalidate() }.store(in: &subscriptions)
        player.$mode.sink { [weak self] _ in self?.snapshotMetadata.invalidate() }.store(in: &subscriptions)
    }

    private func updateCatalog(_ songs: [Song]) {
        snapshotMetadata.invalidate()
        songsByID = Dictionary(songs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        player.retainLibrary(songs)
        catalogRevision = UUID().uuidString
        rows = songs.map { song in
            let token = SongResourceToken.encode(song.id)
            let version = (song.cacheVersion ?? "legacy-" + URL(fileURLWithPath: song.artworkFile ?? song.id).lastPathComponent) + artworkEpoch
            return ["id": song.id, "artworkRevision": song.cacheVersion ?? "legacy", "title": song.title, "artist": song.artist, "album": song.album,
                    "duration": song.duration * 1000, "path": song.relativePath,
                    "sourceAdded": song.sourceAdded ?? 0, "added": song.added ?? 0, "size": song.fileSize ?? 0,
                    "artwork": song.artworkFile == nil ? "" : "minivoice://app/artwork/\(token).png?v=\(version)",
                    "artworkWall": song.artworkFile == nil ? "" : "minivoice://app/artwork/\(token).png?quality=wall&v=\(version)",
                    "artworkCard": song.artworkFile == nil ? "" : "minivoice://app/artwork/\(token).png?quality=card&v=\(version)",
                    "artworkDetail": song.originalArtworkFile == nil ? "" : "minivoice://app/artwork/\(token).png?quality=display&v=\(version)"]
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.scheme == "minivoice",
              message.frameInfo.request.url?.host == "app", let body = message.body as? [String: Any] else { return }
        if body["startupReady"] as? Bool == true {
            guard let generation = (body["startupGeneration"] as? NSNumber)?.uint64Value,
                  generation == webDiagnostics.generation else { return }
            if let detail = webDiagnostics.stage(.ready, generation: generation) { IOSDiagnostics.shared.record(.event, detail) }
            guard let cover = startupCover else { return }
            startupCover = nil
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.2, animations: { cover.alpha = 0 }) { _ in cover.removeFromSuperview() }
            return
        }
        if body["haptic"] as? Bool == true {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }
        guard let id = body["id"] as? String, id.count <= 64, id.allSatisfy(\.isNumber),
              let raw = body["raw"] as? String, raw.utf8.count <= 4 * 1024 * 1024 else { return }
        do {
            guard let request = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
                  request["version"] as? Int == 1 else { throw failure("无效的宿主协议") }
            #if targetEnvironment(simulator)
            if request["kind"] as? String == "uiTestOrientation", ProcessInfo.processInfo.arguments.contains("--mv-ui-smoke") {
                let controller = web?.window?.rootViewController
                reply(id, value: ["device": UIDevice.current.orientation.rawValue,
                                  "interface": web?.window?.windowScene?.interfaceOrientation.rawValue ?? 0,
                                  "supportedMask": controller?.supportedInterfaceOrientations.rawValue ?? 0,
                                  "controller": controller.map { String(describing: type(of: $0)) } ?? "none"])
                return
            }
            if request["kind"] as? String == "uiTestScanStress", ProcessInfo.processInfo.arguments.contains("--mv-ui-smoke") {
                Task { [weak self] in
                    guard let self else { return }
                    do { self.reply(id, value: try await self.library.simulatorScanStress()) }
                    catch { self.reply(id, error: error.localizedDescription) }
                }
                return
            }
            if request["kind"] as? String == "uiTestAudioFormats", ProcessInfo.processInfo.arguments.contains("--mv-ui-smoke") {
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        let fixture = try await self.library.simulatorAudioFixtures()
                        var rows: [[String: Any]] = []
                        self.player.setSceneActive(true)
                        var clockLifecyclePassed = true
                        let savedMode = self.player.mode; self.player.mode = .single
                        for song in fixture.songs {
                            self.player.play(song, queue: [song], library: self.library)
                            for _ in 0..<60 {
                                if self.player.playbackState == "playing", self.player.position > 0.2 { break }
                                try await Task.sleep(for: .milliseconds(25))
                            }
                            rows.append(["format": URL(fileURLWithPath: song.relativePath).pathExtension, "state": self.player.playbackState, "position": self.player.position, "duration": self.player.duration, "error": self.player.errorMessage ?? ""])
                            clockLifecyclePassed = clockLifecyclePassed && self.player.isUIClockRunning
                            let foregroundPosition = self.player.position
                            self.player.setSceneActive(false)
                            clockLifecyclePassed = clockLifecyclePassed && !self.player.isUIClockRunning && self.player.playbackState == "playing"
                            try await Task.sleep(for: .milliseconds(120))
                            self.player.setSceneActive(true)
                            clockLifecyclePassed = clockLifecyclePassed && self.player.isUIClockRunning && self.player.position > foregroundPosition
                            self.player.pause()
                            let pausedPosition = self.player.position
                            try await Task.sleep(for: .milliseconds(280))
                            clockLifecyclePassed = clockLifecyclePassed && !self.player.isUIClockRunning && self.player.position == pausedPosition
                        }
                        self.player.mode = savedMode
                        var rapidSelectionSettled = false
                        if let first = self.library.songs.first, let last = self.library.songs.last {
                            for song in [first,last,first,last,first] { self.player.play(song, queue: self.library.songs, library: self.library) }
                            self.player.pause(); self.player.seek(to: 12)
                            for _ in 0..<100 { if self.player.playbackState != "loading" { break }; try await Task.sleep(for: .milliseconds(25)) }
                            rapidSelectionSettled = self.player.current?.id == first.id && self.player.playbackState == "paused" && abs(self.player.position - 12) < 0.2
                        }
                        if let song = self.library.songs.first { self.player.play(song, queue: self.library.songs, library: self.library); self.player.pause() }
                        self.reply(id, value: ["rows": rows, "clockLifecyclePassed": clockLifecyclePassed, "rapidSelectionSettled": rapidSelectionSettled, "flacArtwork": fixture.flacArtwork, "pageZoom": self.web?.scrollView.zoomScale ?? 0, "maximumPageZoom": self.web?.scrollView.maximumZoomScale ?? 0])
                    } catch { self.reply(id, error: error.localizedDescription) }
                }
                return
            }
            if request["kind"] as? String == "uiTestArtworkBudget", ProcessInfo.processInfo.arguments.contains("--mv-ui-smoke") {
                reply(id, value: ["peak": artworkPeak, "active": artworkActive, "queued": artworkWaiters.count, "webTerminations": webTerminations]); return
            }
            if request["kind"] as? String == "uiTestDiagnostics", ProcessInfo.processInfo.arguments.contains("--mv-ui-smoke") {
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        let data = try await self.library.diagnosticsArchive()
                        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("diagnostics-test.zip")
                        try await Task.detached(priority: .utility) { try data.write(to: output, options: .atomic) }.value
                        self.reply(id, value: ["bytes": data.count])
                    } catch { self.reply(id, error: error.localizedDescription) }
                }
                return
            }
            if request["kind"] as? String == "uiTestSnapshot", ProcessInfo.processInfo.arguments.contains("--mv-ui-smoke"),
               let name = request["name"] as? String, name.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil, let web {
                let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name + ".png")
                let surface = web.superview ?? web
                let image = UIGraphicsImageRenderer(bounds: surface.bounds).image { _ in
                    surface.drawHierarchy(in: surface.bounds, afterScreenUpdates: true)
                }
                do {
                    guard let data = image.pngData() else { throw failure("截图失败") }
                    try data.write(to: output, options: .atomic)
                    reply(id, value: true)
                } catch { reply(id, error: error.localizedDescription) }
                return
            }
            #endif
            if request["kind"] as? String == "captureStyle" {
                let phase = request["phase"] as? String
                if phase == "prepare", let web, let cells = request["cells"] as? [[String: Any]],
                   let token = styleFragments.prepare(in: web.superview ?? web, cells: cells) {
                    reply(id, value: ["token": token, "cells": cells.count])
                } else if let token = request["token"] as? String, phase == "animate" {
                    styleFragments.animate(token) { [weak self] in self?.reply(id, value: true) }
                } else {
                    styleFragments.cancel(request["token"] as? String)
                    reply(id, value: NSNull())
                }
                return
            }
            Task { [weak self] in
                guard let self else { return }
                do { self.reply(id, value: try await self.execute(request)) }
                catch { IOSDiagnostics.shared.record(.failure, "host: " + error.localizedDescription); self.reply(id, error: error.localizedDescription) }
            }
        } catch { reply(id, error: error.localizedDescription) }
    }

    /// Enqueue before suspension so rapid camera/settings saves cannot finish out of order.
    private func stateIO<T>(_ operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            stateWorker.async { continuation.resume(with: Result { try operation() }) }
        }
    }

    private func execute(_ request: [String: Any]) async throws -> Any {
        switch request["kind"] as? String {
        case "core":
            guard let value = request["request"] as? [String: Any] else { throw failure("缺少核心请求") }
            return try await Task.detached(priority: .userInitiated) { try SharedEngine.execute(value) }.value
        case "snapshot": return snapshot(revision: request["catalogRevision"] as? String, metadataRevision: request["snapshotRevision"] as? String)
        case "readState":
            let url = stateURL
            if let data = try? await stateIO({ try Data(contentsOf: url) }) {
                let state = try JSONSerialization.jsonObject(with: data)
                applyChrome(state as? [String: Any] ?? [:]); return state
            }
            return ["version": 1, "section": "音乐库", "pages": ["appearance": ["style": "wall", "theme": UserDefaults.standard.string(forKey: "ios.appearance") ?? "system"]]]
        case "writeState":
            guard let state = request["state"] as? [String: Any], state["version"] as? Int == 1 else { throw failure("页面状态无效") }
            let data = try JSONSerialization.data(withJSONObject: state)
            let url = stateURL
            try await stateIO {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            }
            applyChrome(state)
            if let pages = state["pages"] as? [String: Any], let appearance = pages["appearance"] as? [String: Any],
               let theme = appearance["theme"] as? String, ["light", "dark", "system"].contains(theme) {
                UserDefaults.standard.set(theme, forKey: "ios.appearance")
            }
            return true
        case "play":
            guard let id = request["id"] as? String else { throw failure("缺少歌曲") }
            let song = try allowedSong(id)
            let ids = request["ids"] as? [String] ?? library.songs.map(\.id)
            let folders = Set(library.folders.map(\.id))
            let songs = try ids.map { id -> Song in
                guard let song = songsByID[id], folders.contains(song.folderID) else { throw failure("歌曲已不在授权音乐库中") }; return song
            }
            guard songs.contains(where: { $0.id == id }) else { throw failure("歌曲不在播放列表中") }
            player.play(song, queue: songs, library: library)
            return true
        case "toggle": player.toggle(); return true
        case "seek":
            guard let milliseconds = request["position"] as? Double, milliseconds.isFinite else { throw failure("无效的播放位置") }
            player.seek(to: min(player.duration, max(0, milliseconds / 1000))); return true
        case "skip":
            guard let delta = request["delta"] as? Int else { throw failure("无效的切歌方向") }
            if delta < 0 { player.previous() } else { player.next() }; return true
        case "action": return try await action(request["name"] as? String ?? "", request["payload"] as? [String: Any] ?? [:])
        case "exit": return true // Settings closes in Shared/UI; there is no legacy content window.
        default: throw failure("不支持的宿主命令")
        }
    }

    private func snapshot(revision: String?, metadataRevision: String?) -> [String: Any] {
        let error = library.errorMessage ?? player.errorMessage ?? ""
        if error != lastError { lastError = error; notice = error; noticeToken += 1 }
        var value = snapshotMetadata.fields(ifRevision: metadataRevision) {
            ["rawLyrics": library.lyrics(for: player.current) ?? "",
             "favorites": Array(library.favorites), "recent": library.recentIDs,
             "playlists": library.playlists.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }.map { ["id": $0.id.uuidString, "name": $0.name, "ids": $0.songIDs] as [String: Any] },
             "queue": player.queue.map(\.id), "mode": player.mode.rawValue,
             "capabilities": ["favorite", "mode", "queueSelect", "createPlaylist", "addToPlaylist", "settings"]]
        }
        value.merge(["songs": revision == catalogRevision ? NSNull() : rows, "catalogRevision": catalogRevision,
                "scanning": library.isScanning, "scanDetail": library.scanDetail, "scanCompleted": library.scanCount, "scanTotal": library.scanTotal, "scanExecution": library.scanSession.execution, "scanPaused": UserDefaults.standard.bool(forKey: "ios.scan.pending") && !library.isScanning,
                "current": player.current?.id as Any? ?? NSNull(), "position": player.position * 1000,
                "playing": player.isPlaying, "playbackState": player.playbackState,
                "navigationAction": player.navigationAction, "navigationToken": player.navigationToken,
                "nativeNotice": notice, "noticeToken": noticeToken]) { _, new in new }
        return value
    }

    private func action(_ name: String, _ payload: [String: Any]) async throws -> Any {
        switch name {
        case "immersive": immersive(payload["value"] as? Bool ?? false); return true
        case "ackNavigation": player.acknowledgeNavigation(payload["token"] as? Int ?? -1); return true
        case "settings": player.requestNavigation("SHOW_SCAN"); return true
        case "exportDiagnostics": export(try await library.diagnosticsArchive()); return true
        case "clearCache":
            let result = try await library.sharedMaintenanceAction(name, payload: payload)
            // Clear renderer/browser cache identities as well, without invalidating audio metadata.
            artworkEpoch = "-clear-" + UUID().uuidString
            updateCatalog(library.songs)
            return result
        case "cacheInfo", "inspectLibrary", "artistAlias", "clearArtistAliases":
            return try await library.sharedMaintenanceAction(name, payload: payload)
        case "chooseFolder": chooseFolder(); return true
        case "getSettings": return library.sharedSettings
        case "enableScanNotifications": return try await library.scanSession.requestNotifications()
        case "rescan": library.rescan(); return true
        case "recursive":
            guard let value = payload["value"] as? Bool else { throw failure("缺少递归扫描设置") }
            library.includesSubfolders = value; library.rescan(); return true
        case "removeFolder":
            guard let id = payload["folder"] as? String, let folder = library.folders.first(where: { $0.id == id }) else { throw failure("文件夹已移除") }
            player.retainLibrary(library.songs.filter { $0.folderID != folder.id })
            library.removeFolder(folder); return true
        case "mode":
            guard let raw = payload["value"] as? Int, let mode = PlaybackMode(rawValue: raw) else { throw failure("播放模式无效") }
            player.mode = mode; return true
        case "queueSelect":
            guard let id = payload["id"] as? String, player.queue.contains(where: { $0.id == id }) else { throw failure("歌曲不在播放队列中") }
            player.play(try allowedSong(id), queue: player.queue, library: library); return true
        case "artworkSubjects":
            let song = try allowedSong(payload["id"] as? String ?? "")
            let data = try await library.artworkData(for: song, original: true)
            let viewport = payload["viewport"] as? [String: Any] ?? [:]
            return try await ArtworkSubjects.detect(data, viewportWidth: viewport["width"] as? Double, viewportHeight: viewport["height"] as? Double)
        case "readLyrics":
            let song = try allowedSong(payload["id"] as? String ?? "")
            return ["title": song.title, "raw": library.lyrics(for: song) ?? ""]
        default: return try library.sharedCollectionAction(name, payload: payload)
        }
    }

    private func allowedSong(_ id: String) throws -> Song {
        guard let song = songsByID[id], library.folders.contains(where: { $0.id == song.folderID }) else {
            throw failure("歌曲已不在授权音乐库中")
        }
        return song
    }

    private func reply(_ id: String, value: Any = NSNull(), error: String? = nil) {
        let envelope: [String: Any] = error.map { ["ok": false, "error": $0] } ?? ["ok": true, "value": value]
        guard let data = try? JSONSerialization.data(withJSONObject: [id, envelope], options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else { return }
        web?.evaluateJavaScript("((r)=>globalThis.MiniVoiceTransport?.receive(r[0],r[1]))(\(json))", completionHandler: nil)
    }

    func beginWebSession(_ reason: WebHostDiagnostics.Reason) {
        navigationGenerations.removeAll(keepingCapacity: true)
        IOSDiagnostics.shared.record(.event, webDiagnostics.begin(reason))
    }

    func trackNavigation(_ navigation: WKNavigation?) {
        if let navigation { navigationGenerations[ObjectIdentifier(navigation)] = webDiagnostics.generation }
    }

    func installBridgeScript(in controller: WKUserContentController) {
        // Replace only this host's document-start bridge; keep any other scripts.
        if let bridgeScript {
            var removedOwnedScript = false
            let retained = controller.userScripts.filter { script in
                if !removedOwnedScript, script.source == bridgeScript.source,
                   script.injectionTime == bridgeScript.injectionTime,
                   script.isForMainFrameOnly == bridgeScript.isForMainFrameOnly {
                    removedOwnedScript = true; return false
                }
                return true
            }
            controller.removeAllUserScripts()
            retained.forEach { controller.addUserScript($0) }
        }
        let bridgeScript = WKUserScript(source: """
        addEventListener('DOMContentLoaded', () => {
          document.querySelector('meta[name=viewport]')?.setAttribute('content','width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover');
          for (const side of ['top','right','bottom','left'])
            document.documentElement.style.setProperty('--mv-safe-' + side, 'env(safe-area-inset-' + side + ',0px)');
        });
        addEventListener('DOMContentLoaded', () => {
          const observer = new MutationObserver(check);
          function check() {
            if (!document.querySelector('.mv-workspace[data-ready="true"]')) return;
            observer.disconnect();
            requestAnimationFrame(() => requestAnimationFrame(() =>
              webkit.messageHandlers.MiniVoice.postMessage({startupReady:true,startupGeneration:\(webDiagnostics.generation)})));
          }
          observer.observe(document.documentElement, {subtree:true, childList:true, attributes:true, attributeFilter:['data-ready']});
          check();
        });
        globalThis.MiniVoiceHost = {
          platform: 'ios',
          wallRenderer: 'single-surface',
          request(id, raw) { webkit.messageHandlers.MiniVoice.postMessage({id, raw}); },
          haptic() { webkit.messageHandlers.MiniVoice.postMessage({haptic:true}); }
        };
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        self.bridgeScript = bridgeScript
        controller.addUserScript(bridgeScript)
    }

    private func failure(_ message: String, code: Int = 1) -> NSError { NSError(domain: "MiniVoice.iOS.Host", code: code, userInfo: [NSLocalizedDescriptionKey: message]) }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        decisionHandler(url?.scheme == "minivoice" && url?.host == "app" && navigationAction.targetFrame?.isMainFrame == true ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let identifier = ObjectIdentifier(urlSchemeTask)
        activeLoads.insert(identifier)
        let diagnosticsGeneration = webDiagnostics.generation
        resourceTasks[identifier] = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.resourceTasks[identifier] = nil }
            do {
                guard let url = urlSchemeTask.request.url, url.host == "app", !url.pathComponents.contains("..") else { throw self.failure("资源路径无效") }
                let file: URL
                var artworkBytes: Data?
                let artwork = url.path.hasPrefix("/artwork/")
                if artwork {
                    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                    guard query.allSatisfy({ ["quality", "v"].contains($0.name) }),
                          let id = SongResourceToken.decode(String(url.lastPathComponent.dropLast(4))) else { throw self.failure("封面资源身份无效") }
                    let song = try self.allowedSong(id)
                    let quality = query.first(where: { $0.name == "quality" })?.value
                    let original = quality == "original" || quality == "display"
                    guard let path = original ? (song.originalArtworkFile ?? song.artworkFile) : song.artworkFile else { throw self.failure("没有封面", code: 2) }
                    file = URL(fileURLWithPath: path)
                    do {
                        try await self.acquireArtwork(identifier, priority: quality == "card" || quality == "display")
                        defer { self.releaseArtwork() }
                        try Task.checkCancellation()
                        guard self.activeLoads.contains(identifier) else { throw CancellationError() }
                        let bytes = try await self.library.artworkData(for: song, original: original, display: quality == "display", wall: quality == "wall", card: quality == "card")
                        try Task.checkCancellation()
                        artworkBytes = bytes
                        _ = try self.allowedSong(id)
                    }
                } else {
                    guard url.query == nil, let root = Bundle.main.resourceURL?.appendingPathComponent("SharedPlayer", isDirectory: true).standardizedFileURL else { throw self.failure("共享资源无效") }
                    let relative = url.path == "/" ? "index.html" : String(url.path.dropFirst())
                    file = root.appendingPathComponent(relative).standardizedFileURL
                    guard file.path.hasPrefix(root.path + "/") else { throw self.failure("资源路径越界") }
                }
                let data: Data
                if let artworkBytes { data = artworkBytes }
                else { data = try await Task.detached(priority: .userInitiated) { try Data(contentsOf: file) }.value }
                guard self.activeLoads.remove(identifier) != nil else { return }
                let mime: String
                if artwork, let source = CGImageSourceCreateWithData(data as CFData, nil), let type = CGImageSourceGetType(source) {
                    mime = UTType(type as String)?.preferredMIMEType ?? "image/jpeg"
                } else { mime = ["html": "text/html", "js": "application/javascript", "css": "text/css", "png": "image/png", "svg": "image/svg+xml", "json": "application/json"][file.pathExtension] ?? "application/octet-stream" }
                let response = HTTPURLResponse(url: urlSchemeTask.request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime, "Access-Control-Allow-Origin": "*", "Cache-Control": artwork && url.query?.contains("v=") == true ? "private, max-age=3600" : "no-cache"])!
                urlSchemeTask.didReceive(response); urlSchemeTask.didReceive(data); urlSchemeTask.didFinish()
            } catch {
                guard self.activeLoads.remove(identifier) != nil else { return }
                let category = WebHostDiagnostics.resource(for: urlSchemeTask.request.url)
                if let detail = self.webDiagnostics.failure(.resource(category), error: error, generation: diagnosticsGeneration, expectedMissingArtwork: category == .artwork) {
                    IOSDiagnostics.shared.record(.failure, detail)
                }
                urlSchemeTask.didFailWithError(error)
            }
        }
    }

    private func applyChrome(_ state: [String: Any]) {
        let pages = state["pages"] as? [String: Any]
        let appearance = pages?["appearance"] as? [String: Any]
        (web as? SharedContentWebView)?.contentStyle = appearance?["style"] as? String ?? "wall"
        (web as? SharedContentWebView)?.contentTheme = appearance?["theme"] as? String ?? "system"
        (web as? SharedContentWebView)?.publishInsets()
    }

    private func recordNavigationStage(_ stage: WebHostDiagnostics.Stage, navigation: WKNavigation?) {
        guard let navigation, let generation = navigationGenerations[ObjectIdentifier(navigation)],
              let detail = webDiagnostics.stage(stage, generation: generation) else { return }
        IOSDiagnostics.shared.record(.event, detail)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        recordNavigationStage(.provisional, navigation: navigation)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        recordNavigationStage(.committed, navigation: navigation)
    }

    private func navigationFailed(_ navigation: WKNavigation?, stage: WebHostDiagnostics.Stage, error: Error) {
        let generation: UInt64
        if let navigation {
            guard let known = navigationGenerations[ObjectIdentifier(navigation)], known == webDiagnostics.generation else { return }
            generation = known
        } else {
            // WebKit may omit the navigation object. Preserve the visible error
            // for that case instead of silently treating it as an old callback.
            generation = webDiagnostics.generation
        }
        if let detail = webDiagnostics.failure(.navigation(stage), error: error, generation: generation) { IOSDiagnostics.shared.record(.failure, detail) }
        startupCover?.removeFromSuperview()
        startupCover = nil
        library.errorMessage = "界面加载失败：\(error.localizedDescription)"
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationFailed(navigation, stage: .provisional, error: error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationFailed(navigation, stage: .committed, error: error)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        recordNavigationStage(.finished, navigation: navigation)
        (webView as? SharedContentWebView)?.publishInsets(force: true)
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.arguments.contains("--mv-ui-smoke"),
              let sourceURL = Bundle.main.resourceURL?.appendingPathComponent("SharedPlayer/" + (ProcessInfo.processInfo.arguments.contains("--mv-duo-motion-smoke") ? "duo-motion-smoke.js" : ProcessInfo.processInfo.arguments.contains("--mv-duo-probe") ? "duo-probe.js" : ProcessInfo.processInfo.arguments.contains("--mv-duo-matrix-smoke") ? "duo-matrix-smoke.js" : ProcessInfo.processInfo.arguments.contains("--mv-duo-layout-smoke") ? "duo-layout-smoke.js" : ProcessInfo.processInfo.arguments.contains("--mv-wall-stress-fixture") ? "wall-stress-smoke.js" : "shared-host-smoke.js")),
              let source = try? String(contentsOf: sourceURL, encoding: .utf8) else { return }
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let testSource = (ProcessInfo.processInfo.arguments.contains("--mv-wall-only-smoke") ? "globalThis.MINIVOICE_WALL_ONLY=true;\n" : "") + source
        webView.callAsyncJavaScript(testSource, arguments: [:], in: nil, in: .page) { result in
            let report: [String: Any]
            switch result {
            case .success(let value): report = value as? [String: Any] ?? ["error": "测试无结果"]
            case .failure(let error): report = ["error": error.localizedDescription]
            }
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: output.appendingPathComponent("shared-host-smoke.json"), options: .atomic)
            }
            webView.takeSnapshot(with: nil) { image, _ in
                try? image?.pngData()?.write(to: output.appendingPathComponent("shared-host-smoke.png"), options: .atomic)
            }
        }
        #endif
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webTerminations += 1
        IOSDiagnostics.shared.record(.failure, "WebContent terminated count=\(webTerminations) artworkActive=\(artworkActive) queued=\(artworkWaiters.count) thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
        cancelResourceLoads()
        Task { await library.invalidateArtworkMemory() }
        beginWebSession(.recovery)
        installBridgeScript(in: webView.configuration.userContentController)
        trackNavigation(webView.reload())
    }

    func disconnect() {
        navigationGenerations.removeAll()
        subscriptions.removeAll()
        cancelResourceLoads()
    }

    private func cancelResourceLoads() {
        styleFragments.cancel()
        resourceTasks.values.forEach { $0.cancel() }
        activeLoads.removeAll()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) { let id = ObjectIdentifier(urlSchemeTask); activeLoads.remove(id); resourceTasks[id]?.cancel() }
}


private struct DiagnosticsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private final class SharedContentWebView: WKWebView {
    // A touch beginning in the home-indicator strip belongs to iOS. Keep
    // WebKit's inner overflow scroller from starting a competing wall pan.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if contentStyle == "wall", !hingeAvailable, safeAreaInsets.bottom > 0,
           point.y >= bounds.maxY - safeAreaInsets.bottom { return nil }
        return super.hitTest(point, with: event)
    }
    var contentStyle = "wall"
    var contentTheme = "system"
    private func updateCanvasBackground() {
        let dark = contentTheme == "dark" || (contentTheme == "system" && traitCollection.userInterfaceStyle == .dark)
        let rgb: (CGFloat, CGFloat, CGFloat) = contentStyle == "wall" ? (dark ? (16,36,26) : (220,234,222)) : (dark ? (24,39,32) : (234,240,238))
        let color = UIColor(red: rgb.0/255, green: rgb.1/255, blue: rgb.2/255, alpha: 1)
        isOpaque = true
        backgroundColor = color
        scrollView.backgroundColor = color
        underPageBackgroundColor = color
        // Every exposed hosting container must agree before the system rotates
        // the old surface into its new bounds. A clear intermediate UIView can
        // otherwise expose the hosting controller's default white backing.
        var container = superview
        while let view = container {
            view.backgroundColor = color
            container = view.superview
        }
        window?.backgroundColor = color
        window?.rootViewController?.view.backgroundColor = color
    }
    private var observingHinge = false
    private var hingeAvailable = false
    override func didMoveToWindow() {
        super.didMoveToWindow(); updateCanvasBackground()
        if #available(iOS 27.1, *), !observingHinge {
            observingHinge = true
            addInteraction(UIHingeInteraction { [weak self] _, update in
                self?.hingeAvailable = update.hinge != nil
                self?.setNeedsLayout()
            })
        }
    }
    private var lastInsets = ""
    override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); publishInsets() }
    override func layoutSubviews() { super.layoutSubviews(); publishInsets() }
    func publishInsets(force: Bool = false) {
        updateCanvasBackground()
        scrollView.pinchGestureRecognizer?.isEnabled = false
        scrollView.bouncesZoom = false
        let safe = safeAreaInsets
        var hasDivision = hingeAvailable
        var occlusions: [[String: CGFloat]] = []
        var foldTop: CGFloat = 0, foldBottom: CGFloat = 0, foldLeft: CGFloat = 0, foldRight: CGFloat = 0
        if #available(iOS 27.1, *) {
            occlusions = reservedRegions(kind: .occlusion).filter { $0.isActive }.map { ["x": $0.frame.minX, "y": $0.frame.minY, "width": $0.frame.width, "height": $0.frame.height] }
            hasDivision = hingeAvailable || !reservedRegions(kind: .division, options: .includeInactive).isEmpty
            if let fold = reservedRegions(kind: .division).first(where: { $0.isActive }) {
                if fold.frame.width > fold.frame.height, fold.frame.minY > 0, fold.frame.maxY < bounds.height {
                    foldTop = fold.frame.minY; foldBottom = fold.frame.maxY
                } else if fold.frame.height > fold.frame.width, fold.frame.minX > 0, fold.frame.maxX < bounds.width {
                    foldLeft = fold.frame.minX; foldRight = fold.frame.maxX
                }
            }
        }
        let occlusionJSON = String(data: (try? JSONSerialization.data(withJSONObject: occlusions, options: [.sortedKeys])) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        let key = "\(occlusionJSON)-\(safe)-\(bounds.size)-\(contentStyle)-\(foldTop)-\(foldBottom)-\(foldLeft)-\(foldRight)-\(hasDivision)"
        guard (force || key != lastInsets), url != nil else { return }
        lastInsets = key
        let script = "(()=>{window.miniVoiceOcclusions=\(occlusionJSON);window.miniVoiceFold={duo:\(hasDivision),top:\(foldTop),bottom:\(foldBottom),left:\(foldLeft),right:\(foldRight)};const s=document.documentElement.style;s.setProperty('--mv-safe-top','\(safe.top)px');s.setProperty('--mv-safe-bottom','\(safe.bottom)px');s.setProperty('--mv-safe-left','\(safe.left)px');s.setProperty('--mv-safe-right','\(safe.right)px');dispatchEvent(new Event('minivoice-insets'));})()"
        evaluateJavaScript(script, completionHandler: nil)
    }
}
