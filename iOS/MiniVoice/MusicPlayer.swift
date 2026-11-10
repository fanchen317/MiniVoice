import AVFoundation
import Combine
import MediaPlayer
import UIKit
import ImageIO

private final class AudioLoadRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    func check() throws { lock.lock(); let value = cancelled; lock.unlock(); if value { throw CancellationError() } }
}

/// One prepared file owns its directory grant through asynchronous loading and playback.
private final class PreparedLocalAudio: @unchecked Sendable {
    let audio: AVAudioPlayer
    private let lease: FolderAccessRegistry.Lease
    init(access: FolderAccessRegistry.Request, relative: String) throws {
        let grant = try access.acquire()
        lease = grant
        do {
            let url = try grant.file(relativePath: relative)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            var value: AVAudioPlayer?, failure: Error?, coordinationError: NSError?
            NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                do { try grant.checkValidity(); value = try AVAudioPlayer(contentsOf: readable) } catch { failure = error }
            }
            if let error = coordinationError ?? failure as NSError? { throw error }
            try grant.checkValidity()
            guard let value, value.prepareToPlay() else { throw CocoaError(.fileReadCorruptFile) }
            audio = value
        } catch { grant.close(); throw error }
    }
    func checkAuthorization() throws { try lease.checkValidity() }
    deinit { lease.close() }
}

@MainActor
final class MusicPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var current: Song?
    @Published private(set) var isPlaying = false
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var queue: [Song] = []
    @Published var mode: PlaybackMode = .sequential {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "playbackMode") }
    }
    @Published var errorMessage: String? {
        didSet { if let message = errorMessage, message != oldValue { IOSDiagnostics.shared.record(.failure, "player: " + message) } }
    }

    @Published private(set) var navigationAction = ""
    @Published private(set) var navigationToken = 0
    private var sessionObservers: [NSObjectProtocol] = []
    private var clock: Timer?
    private var sceneActive = false
    private var resumeAfterInterruption = false
    private var player: AVAudioPlayer?
    private var prepared: PreparedLocalAudio?
    private var loadTask: Task<Void, Never>?
    private var loadID = UUID()
    private var loadRequest: AudioLoadRequest?
    private var wantsPlayback = false
    private var pendingPosition: TimeInterval?
    private let audioWorker = DispatchQueue(label: "MiniVoice.audio-prepare", qos: .userInitiated)
    private weak var library: MusicLibrary?
    private var nowPlayingArtwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?
    private var artworkIdentity: String?

    override init() {
        super.init()
        if let saved = UserDefaults.standard.object(forKey: "playbackMode") as? Int {
            mode = PlaybackMode(rawValue: saved) ?? .sequential
        }
        configureRemoteCommands()
        sessionObservers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    // The engine may already have stopped before scene/interrupt
                    // notifications arrive. Preserve the user's intent, not a
                    // transient engine sample from setSceneActive(false).
                    let resume = self.wantsPlayback || self.resumeAfterInterruption
                    self.pause(); self.resumeAfterInterruption = resume
                } else if type == AVAudioSession.InterruptionType.ended.rawValue {
                    let resume = self.resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
                    self.resumeAfterInterruption = false
                    if resume { self.resumePlayback() }
                }
            }
        })
        sessionObservers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                Task { @MainActor [weak self] in self?.pause() }
            }
        })
    }

    // The audio engine keeps its own clock in the background. Only the visible UI
    // needs periodic samples; Now Playing extrapolates elapsed time from its rate.
    func setSceneActive(_ active: Bool) {
        guard sceneActive != active else { return }
        sceneActive = active
        synchronizePlayback()
        updateNowPlaying()
    }

    private func synchronizePlayback() {
        if let player {
            let seconds = player.currentTime
            if position != seconds { position = seconds }
            if isPlaying != player.isPlaying { isPlaying = player.isPlaying }
        } else if isPlaying { isPlaying = false }
        updateClock()
    }

    private func updateClock() {
        guard sceneActive, player?.isPlaying == true else {
            clock?.invalidate(); clock = nil
            return
        }
        guard clock == nil else { return }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.sceneActive else { return }
                let wasPlaying = self.isPlaying
                self.synchronizePlayback()
                // A device/engine stop can occur without a user command. Publish
                // that rate change, while ordinary ticks never rebuild metadata.
                if wasPlaying != self.isPlaying { self.updateNowPlaying() }
            }
        }
        timer.tolerance = 0.025
        clock = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    #if targetEnvironment(simulator)
    var isUIClockRunning: Bool { clock?.isValid == true }
    #endif

    var duration: TimeInterval { player?.duration ?? current?.duration ?? 0 }
    var playbackState: String { loadTask != nil ? "loading" : player == nil ? "unloaded" : player!.isPlaying ? "playing" : "paused" }

    func play(_ song: Song, queue songs: [Song], library: MusicLibrary) {
        self.library = library
        queue = songs.contains(song) ? songs : [song] + songs
        if current?.id == song.id, player != nil || loadTask != nil {
            resumePlayback()
            return
        }
        load(song, autoplay: true)
    }

    private func load(_ song: Song, autoplay: Bool) {
        guard let library, let access = library.folderAccessRequest(for: song) else {
            errorMessage = "音乐文件夹不可访问，请在设置中重新选择。"
            return
        }
        clearPlayer()
        current = song; position = 0; wantsPlayback = autoplay; errorMessage = nil
        refreshNowPlayingArtwork(song)
        let request = loadID, worker = audioWorker, ticket = AudioLoadRequest()
        loadRequest = ticket
        loadTask = Task { [weak self] in
            do {
                let file: PreparedLocalAudio = try await withCheckedThrowingContinuation { continuation in
                    worker.async {
                        autoreleasepool { continuation.resume(with: Result { try ticket.check(); return try PreparedLocalAudio(access: access, relative: song.relativePath) }) }
                    }
                }
                guard !Task.isCancelled, let self, self.loadID == request else { return }
                try file.checkAuthorization()
                self.loadTask = nil; self.prepared = file
                let next = file.audio; self.player = next; next.delegate = self
                if let value = self.pendingPosition { next.currentTime = min(next.duration, value); self.pendingPosition = nil }
                if self.wantsPlayback {
                    guard next.play() else { throw NSError(domain: "MiniVoice.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "音频设备未能启动播放"]) }
                    library.recordPlayed(song)
                }
                self.synchronizePlayback()
                self.updateNowPlaying()
            } catch {
                guard !Task.isCancelled, let self, self.loadID == request else { return }
                self.loadTask = nil; self.player = nil; self.prepared = nil; self.isPlaying = false; self.wantsPlayback = false
                let detail = error as NSError
                self.errorMessage = "无法读取或解码歌曲（\(detail.domain) \(detail.code)）：\(detail.localizedDescription)。请确认目录授权仍有效。"
                self.updateNowPlaying()
            }
        }
        updateNowPlaying()
    }

    /// Keep playback and lock-screen controls inside the currently authorized catalog.
    func retainLibrary(_ songs: [Song]) {
        let allowed = Set(songs.map(\.id))
        queue.removeAll { !allowed.contains($0.id) }
        if let current, !allowed.contains(current.id) {
            clearPlayer(); nowPlayingArtwork = nil; updateNowPlaying()
        } else if let id = current?.id {
            let updates = Dictionary(songs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            queue = queue.compactMap { updates[$0.id] }
            if let updated = updates[id] {
                current = updated
                refreshNowPlayingArtwork(updated)
                updateNowPlaying()
            }
        }
    }

    /// Explicit play intent is idempotent, including while a file is loading.
    /// Remote Play must never toggle an already requested asynchronous play off.
    private func resumePlayback() {
        resumeAfterInterruption = false
        wantsPlayback = true
        if loadTask != nil { return }
        guard let player else {
            if let library, let song = current ?? library.songs.first {
                play(song, queue: queue.isEmpty ? library.songs : queue, library: library)
            } else {
                wantsPlayback = false
                errorMessage = "请先选择一首歌曲"
            }
            return
        }
        if player.isPlaying {
            synchronizePlayback()
            updateNowPlaying()
            return
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            if !player.play() {
                wantsPlayback = false
                errorMessage = "音频设备未能恢复播放"
            }
        } catch {
            wantsPlayback = false
            errorMessage = "音频设备未能恢复播放：" + error.localizedDescription
        }
        synchronizePlayback()
        updateNowPlaying()
    }

    func toggle() {
        resumeAfterInterruption = false
        if loadTask != nil { wantsPlayback.toggle(); return }
        if player?.isPlaying == true { pause() }
        else { resumePlayback() }
    }

    func pause() {
        resumeAfterInterruption = false
        wantsPlayback = false
        player?.pause()
        synchronizePlayback()
        updateNowPlaying()
    }

    func seek(to seconds: TimeInterval) {
        guard seconds.isFinite else { return }
        let value = max(0, min(seconds, max(duration, 0)))
        guard let player else { if loadTask != nil { pendingPosition = value; position = value }; return }
        player.currentTime = value
        position = value
        updateNowPlaying()
    }

    func next() { advance(manual: true) }

    func previous() {
        if (player?.currentTime ?? position) > 3 { seek(to: 0); return }
        guard let current, let index = queue.firstIndex(of: current), let previous = ExperiencePlaybackPolicy.previous(index: index, count: queue.count) else { return }
        load(queue[previous], autoplay: true)
    }

    private func didFinish() { advance(manual: false) }

    private func advance(manual: Bool) {
        guard let current, let index = queue.firstIndex(of: current) else { return }
        if let next = ExperiencePlaybackPolicy.next(index: index, count: queue.count, mode: mode.rawValue, manual: manual) {
            if !manual && mode == .repeatOne { seek(to: 0); resumePlayback() }
            else { load(queue[next], autoplay: true) }
        } else { pause(); seek(to: duration) }
    }

    func requestNavigation(_ action: String = "LOCATE_PLAYING") { navigationAction = action; navigationToken += 1 }
    func acknowledgeNavigation(_ token: Int) { if token == navigationToken { navigationAction = "" } }

    private func clearPlayer() {
        loadRequest?.cancel(); loadRequest = nil
        loadID = UUID(); loadTask?.cancel(); loadTask = nil; wantsPlayback = false; resumeAfterInterruption = false; pendingPosition = nil
        clock?.invalidate(); clock = nil
        artworkTask?.cancel(); artworkTask = nil; artworkIdentity = nil; nowPlayingArtwork = nil
        player?.delegate = nil
        player?.stop()
        player = nil
        isPlaying = false
        current = nil
        position = 0
        prepared = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ audio: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === audio else { return }
            if flag { self.didFinish() } else { self.pause(); self.errorMessage = "歌曲解码未能完成" }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ audio: AVAudioPlayer, error: Error?) {
        let message = error?.localizedDescription ?? "无法解码此音频"
        Task { @MainActor [weak self] in
            guard let self, self.player === audio else { return }
            self.pause(); self.errorMessage = "音频解码失败：" + message
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resumePlayback(); self?.requestNavigation() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.toggle() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.next(); self?.requestNavigation() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previous(); self?.requestNavigation() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let value = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else { return .commandFailed }
            Task { @MainActor [weak self] in self?.seek(to: value) }
            return .success
        }
    }

    private func refreshNowPlayingArtwork(_ song: Song) {
        let identity = [song.id, song.artworkFile ?? "", song.cacheVersion ?? ""].joined(separator: "\u{0}")
        guard artworkIdentity != identity else { return }
        artworkTask?.cancel(); artworkTask = nil
        artworkIdentity = identity
        nowPlayingArtwork = nil
        guard song.artworkFile != nil, let library else { return }
        artworkTask = Task { [weak self] in
            // Use the same recoverable cache path as the web surface: iOS may
            // evict Caches while the persisted catalog still names this cover.
            guard let data = try? await library.artworkData(for: song, original: false) else {
                guard !Task.isCancelled, let self, self.artworkIdentity == identity else { return }
                self.artworkTask = nil; self.artworkIdentity = nil
                return
            }
            guard !Task.isCancelled else { return }
            let image = await Task.detached(priority: .utility) {
                autoreleasepool { () -> UIImage? in
                    guard let source = CGImageSourceCreateWithData(data as CFData,
                        [kCGImageSourceShouldCache: false] as CFDictionary),
                        let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceThumbnailMaxPixelSize: 640,
                            kCGImageSourceShouldCacheImmediately: true
                        ] as CFDictionary) else { return nil }
                    return UIImage(cgImage: thumbnail)
                }
            }.value
            guard !Task.isCancelled, let self, self.current?.id == song.id,
                  self.artworkIdentity == identity else { return }
            self.artworkTask = nil
            guard let image else { self.artworkIdentity = nil; return }
            self.nowPlayingArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            self.updateNowPlaying()
        }
    }

    private func updateNowPlaying() {
        guard let current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: current.artist,
            MPMediaItemPropertyAlbumTitle: current.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let nowPlayingArtwork { info[MPMediaItemPropertyArtwork] = nowPlayingArtwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
