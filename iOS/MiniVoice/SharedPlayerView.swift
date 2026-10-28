import SwiftUI
import WebKit
import Combine
import UniformTypeIdentifiers
import MiniVoiceShared
import ImageIO

/// Android-reference content is rendered by Shared/UI. Only system services live in Swift.
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

    func makeUIView(context: Context) -> WKWebView {
        let host = context.coordinator
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(host, forURLScheme: "minivoice")
        configuration.userContentController.add(host, name: "MiniVoice")
        configuration.userContentController.addUserScript(WKUserScript(source: """
        addEventListener('DOMContentLoaded', () => {
          for (const side of ['top','right','bottom','left'])
            document.documentElement.style.setProperty('--mv-safe-' + side, 'env(safe-area-inset-' + side + ',0px)');
        });
        globalThis.MiniVoiceHost = {
          platform: 'ios',
          request(id, raw) { webkit.messageHandlers.MiniVoice.postMessage({id, raw}); },
          haptic() { webkit.messageHandlers.MiniVoice.postMessage({haptic:true}); }
        };
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let web = SharedContentWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = host
        web.isOpaque = false
        web.backgroundColor = .systemBackground
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        #if targetEnvironment(simulator)
        web.isInspectable = true
        #endif
        host.web = web
        web.load(URLRequest(url: URL(string: "minivoice://app/index.html")!))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    static func dismantleUIView(_ web: WKWebView, coordinator: SharedPlayerHost) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "MiniVoice")
        web.stopLoading()
        coordinator.web = nil
    }
}

@MainActor
private final class SharedPlayerHost: NSObject, WKScriptMessageHandler, WKURLSchemeHandler, WKNavigationDelegate {
    weak var web: WKWebView?
    let library: MusicLibrary
    let player: MusicPlayer
    let chooseFolder: () -> Void
    let immersive: (Bool) -> Void
    let export: (Data) -> Void
    private var subscriptions = Set<AnyCancellable>()
    private var catalogRevision = UUID().uuidString
    private var rows: [[String: Any]] = []
    private var activeLoads = Set<ObjectIdentifier>()
    private var notice = ""
    private var noticeToken = 0
    private var lastError = ""
    private let stateURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MiniVoice/shared-mobile-workspace-v1.json")

    init(library: MusicLibrary, player: MusicPlayer, chooseFolder: @escaping () -> Void, immersive: @escaping (Bool) -> Void, export: @escaping (Data) -> Void) {
        self.library = library; self.player = player; self.chooseFolder = chooseFolder
        self.immersive = immersive; self.export = export
        super.init()
        library.$songs.sink { [weak self] songs in self?.updateCatalog(songs) }.store(in: &subscriptions)
    }

    private func updateCatalog(_ songs: [Song]) {
        player.retainLibrary(songs)
        catalogRevision = UUID().uuidString
        rows = songs.map { song in
            let token = SongResourceToken.encode(song.id)
            let version = song.cacheVersion ?? catalogRevision
            return ["id": song.id, "title": song.title, "artist": song.artist, "album": song.album,
                    "duration": song.duration * 1000, "path": song.relativePath,
                    "sourceAdded": song.sourceAdded ?? 0, "added": song.added ?? 0, "size": song.fileSize ?? 0,
                    "artwork": song.artworkFile == nil ? "" : "minivoice://app/artwork/\(token).png?v=\(version)",
                    "artworkDetail": song.originalArtworkFile == nil ? "" : "minivoice://app/artwork/\(token).png?quality=original&v=\(version)"]
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.scheme == "minivoice",
              message.frameInfo.request.url?.host == "app", let body = message.body as? [String: Any] else { return }
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
            if request["kind"] as? String == "uiTestSnapshot", ProcessInfo.processInfo.arguments.contains("--mv-ui-smoke"),
               let name = request["name"] as? String, name.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil, let web {
                let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name + ".png")
                web.takeSnapshot(with: nil) { [weak self] image, error in
                    do {
                        guard let data = image?.pngData() else { throw error ?? self?.failure("截图失败") ?? NSError(domain: "UITest", code: 1) }
                        try data.write(to: output, options: .atomic)
                        self?.reply(id, value: true)
                    } catch { self?.reply(id, error: error.localizedDescription) }
                }
                return
            }
            #endif
            if request["kind"] as? String == "captureStyle", let web {
                let configuration = WKSnapshotConfiguration()
                configuration.snapshotWidth = NSNumber(value: min(900, web.bounds.width))
                web.takeSnapshot(with: configuration) { [weak self] image, _ in
                    let value: Any = image?.jpegData(compressionQuality: 0.75).map { "data:image/jpeg;base64," + $0.base64EncodedString() } ?? NSNull() as Any
                    self?.reply(id, value: value)
                }
                return
            }
            Task { [weak self] in
                guard let self else { return }
                do { self.reply(id, value: try await self.execute(request)) }
                catch { self.reply(id, error: error.localizedDescription) }
            }
        } catch { reply(id, error: error.localizedDescription) }
    }

    private func execute(_ request: [String: Any]) async throws -> Any {
        switch request["kind"] as? String {
        case "core":
            guard let value = request["request"] as? [String: Any] else { throw failure("缺少核心请求") }
            return try await Task.detached(priority: .userInitiated) { try SharedEngine.execute(value) }.value
        case "snapshot": return snapshot(revision: request["catalogRevision"] as? String)
        case "readState":
            let url = stateURL
            if let data = await Task.detached(priority: .utility, operation: { try? Data(contentsOf: url) }).value {
                let state = try JSONSerialization.jsonObject(with: data)
                applyChrome(state as? [String: Any] ?? [:]); return state
            }
            return ["version": 1, "section": "音乐库", "pages": ["appearance": ["style": "wall", "theme": UserDefaults.standard.string(forKey: "ios.appearance") ?? "system"]]]
        case "writeState":
            guard let state = request["state"] as? [String: Any], state["version"] as? Int == 1 else { throw failure("页面状态无效") }
            let data = try JSONSerialization.data(withJSONObject: state)
            let url = stateURL
            try await Task.detached(priority: .utility) {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            }.value
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
            let songs = try ids.map(allowedSong)
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

    private func snapshot(revision: String?) -> [String: Any] {
        let error = library.errorMessage ?? player.errorMessage ?? ""
        if error != lastError { lastError = error; notice = error; noticeToken += 1 }
        return ["songs": revision == catalogRevision ? NSNull() : rows, "catalogRevision": catalogRevision,
                "scanning": library.isScanning, "scanDetail": library.scanDetail,
                "current": player.current?.id as Any? ?? NSNull(), "position": player.position * 1000,
                "playing": player.isPlaying, "rawLyrics": library.lyrics(for: player.current) ?? "",
                "favorites": Array(library.favorites), "recent": library.recentIDs,
                "navigationAction": player.navigationAction, "navigationToken": player.navigationToken,
                "playlists": library.playlists.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }.map { ["id": $0.id.uuidString, "name": $0.name, "ids": $0.songIDs] as [String: Any] },
                "queue": player.queue.map(\.id), "mode": player.mode.rawValue,
                "nativeNotice": notice, "noticeToken": noticeToken,
                "capabilities": ["favorite", "mode", "queueSelect", "createPlaylist", "addToPlaylist", "settings"]]
    }

    private func action(_ name: String, _ payload: [String: Any]) async throws -> Any {
        switch name {
        case "immersive": immersive(payload["value"] as? Bool ?? false); return true
        case "ackNavigation": player.acknowledgeNavigation(payload["token"] as? Int ?? -1); return true
        case "settings": player.requestNavigation("SHOW_SCAN"); return true
        case "exportDiagnostics": export(try library.diagnosticsArchive()); return true
        case "cacheInfo", "clearCache", "inspectLibrary", "artistAlias", "clearArtistAliases":
            return try await library.sharedMaintenanceAction(name, payload: payload)
        case "chooseFolder": chooseFolder(); return true
        case "getSettings": return library.sharedSettings
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
        case "readLyrics":
            let song = try allowedSong(payload["id"] as? String ?? "")
            return ["title": song.title, "raw": library.lyrics(for: song) ?? ""]
        default: return try library.sharedCollectionAction(name, payload: payload)
        }
    }

    private func allowedSong(_ id: String) throws -> Song {
        guard let song = library.songs.first(where: { $0.id == id }), library.folders.contains(where: { $0.id == song.folderID }) else {
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

    private func failure(_ message: String) -> NSError { NSError(domain: "MiniVoice.iOS.Host", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        decisionHandler(url?.scheme == "minivoice" && url?.host == "app" && navigationAction.targetFrame?.isMainFrame == true ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let identifier = ObjectIdentifier(urlSchemeTask)
        activeLoads.insert(identifier)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let url = urlSchemeTask.request.url, url.host == "app", !url.pathComponents.contains("..") else { throw self.failure("资源路径无效") }
                let file: URL
                let artwork = url.path.hasPrefix("/artwork/")
                if artwork {
                    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                    guard query.allSatisfy({ ["quality", "v"].contains($0.name) }),
                          let id = SongResourceToken.decode(String(url.lastPathComponent.dropLast(4))) else { throw self.failure("封面资源身份无效") }
                    let song = try self.allowedSong(id)
                    let original = query.first(where: { $0.name == "quality" })?.value == "original"
                    guard let path = original ? (song.originalArtworkFile ?? song.artworkFile) : song.artworkFile else { throw self.failure("没有封面") }
                    file = URL(fileURLWithPath: path)
                } else {
                    guard url.query == nil, let root = Bundle.main.resourceURL?.appendingPathComponent("SharedPlayer", isDirectory: true) else { throw self.failure("共享资源无效") }
                    let relative = url.path == "/" ? "index.html" : String(url.path.dropFirst())
                    file = root.appendingPathComponent(relative).standardizedFileURL
                    guard file.path.hasPrefix(root.path + "/") else { throw self.failure("资源路径越界") }
                }
                let data = try await Task.detached(priority: .userInitiated) { try Data(contentsOf: file) }.value
                guard self.activeLoads.remove(identifier) != nil else { return }
                let mime: String
                if artwork, let source = CGImageSourceCreateWithData(data as CFData, nil), let type = CGImageSourceGetType(source) {
                    mime = UTType(type as String)?.preferredMIMEType ?? "image/jpeg"
                } else { mime = ["html": "text/html", "js": "application/javascript", "css": "text/css", "png": "image/png", "svg": "image/svg+xml", "json": "application/json"][file.pathExtension] ?? "application/octet-stream" }
                let response = HTTPURLResponse(url: urlSchemeTask.request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime, "Access-Control-Allow-Origin": "*", "Cache-Control": "no-cache"])!
                urlSchemeTask.didReceive(response); urlSchemeTask.didReceive(data); urlSchemeTask.didFinish()
            } catch {
                guard self.activeLoads.remove(identifier) != nil else { return }
                urlSchemeTask.didFailWithError(error)
            }
        }
    }

    private func applyChrome(_ state: [String: Any]) {
        let pages = state["pages"] as? [String: Any]
        let appearance = pages?["appearance"] as? [String: Any]
        (web as? SharedContentWebView)?.contentStyle = appearance?["style"] as? String ?? "wall"
        (web as? SharedContentWebView)?.publishInsets()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        (webView as? SharedContentWebView)?.publishInsets()
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.arguments.contains("--mv-ui-smoke"),
              let sourceURL = Bundle.main.resourceURL?.appendingPathComponent("SharedPlayer/shared-host-smoke.js"),
              let source = try? String(contentsOf: sourceURL, encoding: .utf8) else { return }
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        webView.callAsyncJavaScript(source, arguments: [:], in: nil, in: .page) { result in
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
        // Shared workspace is already persisted atomically; transient panels start closed.
        webView.reload()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) { activeLoads.remove(ObjectIdentifier(urlSchemeTask)) }
}


private struct DiagnosticsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private final class SharedContentWebView: WKWebView {
    var contentStyle = "wall"
    private var lastInsets = ""
    override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); publishInsets() }
    override func layoutSubviews() { super.layoutSubviews(); publishInsets() }
    func publishInsets() {
        var safe = safeAreaInsets
        if contentStyle != "wall", bounds.width > bounds.height { safe.left = max(safe.left, safe.right); safe.right = safe.left }
        let key = "\(safe)-\(bounds.size)-\(contentStyle)"
        guard key != lastInsets, url != nil else { return }
        lastInsets = key
        let script = "(()=>{const s=document.documentElement.style;s.setProperty('--mv-safe-top','\(safe.top)px');s.setProperty('--mv-safe-bottom','\(safe.bottom)px');s.setProperty('--mv-safe-left','\(safe.left)px');s.setProperty('--mv-safe-right','\(safe.right)px');dispatchEvent(new Event('minivoice-insets'));})()"
        evaluateJavaScript(script, completionHandler: nil)
    }
}
