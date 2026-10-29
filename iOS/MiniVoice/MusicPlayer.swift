import AVFoundation
import Combine
import MediaPlayer
import UIKit

private final class AudioLoadRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    func check() throws { lock.lock(); let value = cancelled; lock.unlock(); if value { throw CancellationError() } }
}

/// One prepared file owns its directory grant through asynchronous loading and playback.
private final class PreparedLocalAudio: @unchecked Sendable {
    let audio: AVAudioPlayer
    private let root: URL
    private let accessing: Bool
    init(root: URL, relative: String) throws {
        self.root = root; accessing = root.startAccessingSecurityScopedResource()
        do {
            let url = root.appendingPathComponent(relative).standardizedFileURL
            guard url.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else { throw CocoaError(.fileReadNoPermission) }
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            var value: AVAudioPlayer?, failure: Error?, coordinationError: NSError?
            NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                do { value = try AVAudioPlayer(contentsOf: readable) } catch { failure = error }
            }
            if let error = coordinationError ?? failure as NSError? { throw error }
            guard let value, value.prepareToPlay() else { throw CocoaError(.fileReadCorruptFile) }
            audio = value
        } catch { if accessing { root.stopAccessingSecurityScopedResource() }; throw error }
    }
    deinit { if accessing { root.stopAccessingSecurityScopedResource() } }
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
                    let resume = self.isPlaying; self.pause(); self.resumeAfterInterruption = resume
                } else if type == AVAudioSession.InterruptionType.ended.rawValue {
                    let resume = self.resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
                    self.resumeAfterInterruption = false
                    if resume { try? AVAudioSession.sharedInstance().setActive(true); self.player?.play() }
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

    var duration: TimeInterval { player?.duration ?? current?.duration ?? 0 }
    var playbackState: String { loadTask != nil ? "loading" : player == nil ? "unloaded" : player!.isPlaying ? "playing" : "paused" }

    func play(_ song: Song, queue songs: [Song], library: MusicLibrary) {
        self.library = library
        queue = songs.contains(song) ? songs : [song] + songs
        if current?.id == song.id, player != nil || loadTask != nil {
            wantsPlayback = true
            if let player { isPlaying = player.play(); updateNowPlaying() }
            return
        }
        load(song, autoplay: true)
    }

    private func load(_ song: Song, autoplay: Bool) {
        guard let library, let root = library.folderURL(for: song) else {
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
                        autoreleasepool { continuation.resume(with: Result { try ticket.check(); return try PreparedLocalAudio(root: root, relative: song.relativePath) }) }
                    }
                }
                guard !Task.isCancelled, let self, self.loadID == request else { return }
                self.loadTask = nil; self.prepared = file
                let next = file.audio; self.player = next; next.delegate = self
                if let value = self.pendingPosition { next.currentTime = min(next.duration, value); self.pendingPosition = nil }
                if self.wantsPlayback {
                    guard next.play() else { throw NSError(domain: "MiniVoice.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "音频设备未能启动播放"]) }
                    library.recordPlayed(song)
                }
                self.isPlaying = next.isPlaying
                let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self, let audio = self.player else { return }
                        self.position = audio.currentTime; self.isPlaying = audio.isPlaying
                        self.updateNowPlaying()
                    }
                }
                self.clock = timer; RunLoop.main.add(timer, forMode: .common)
                self.updateNowPlaying()
            } catch {
                guard !Task.isCancelled, let self, self.loadID == request else { return }
                self.loadTask = nil; self.player = nil; self.prepared = nil; self.isPlaying = false
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

    func toggle() {
        if loadTask != nil { wantsPlayback.toggle(); return }
        guard let player else {
            if let library, let song = current ?? library.songs.first { play(song, queue: queue.isEmpty ? library.songs : queue, library: library) }
            else { errorMessage = "请先选择一首歌曲" }
            return
        }
        if player.isPlaying { player.pause() } else if !player.play() { errorMessage = "音频设备未能恢复播放" }
        isPlaying = player.isPlaying
        updateNowPlaying()
    }

    func pause() {
        resumeAfterInterruption = false
        wantsPlayback = false
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func seek(to seconds: TimeInterval) {
        let value = max(0, min(seconds, max(duration, 0)))
        guard let player else { if loadTask != nil { pendingPosition = value; position = value }; return }
        player.currentTime = value
        position = value
        updateNowPlaying()
    }

    func next() { advance(manual: true) }

    func previous() {
        if position > 3 { seek(to: 0); return }
        guard let current, let index = queue.firstIndex(of: current), let previous = ExperiencePlaybackPolicy.previous(index: index, count: queue.count) else { return }
        load(queue[previous], autoplay: true)
    }

    private func didFinish() { advance(manual: false) }

    private func advance(manual: Bool) {
        guard let current, let index = queue.firstIndex(of: current) else { return }
        if let next = ExperiencePlaybackPolicy.next(index: index, count: queue.count, mode: mode.rawValue, manual: manual) {
            if !manual && mode == .repeatOne { seek(to: 0); player?.play(); isPlaying = true; updateNowPlaying() }
            else { load(queue[next], autoplay: true) }
        } else { pause(); seek(to: duration) }
    }

    func requestNavigation(_ action: String = "LOCATE_PLAYING") { navigationAction = action; navigationToken += 1 }
    func acknowledgeNavigation(_ token: Int) { if token == navigationToken { navigationAction = "" } }

    private func clearPlayer() {
        loadRequest?.cancel(); loadRequest = nil
        loadID = UUID(); loadTask?.cancel(); loadTask = nil; wantsPlayback = false; pendingPosition = nil
        clock?.invalidate(); clock = nil
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
            Task { @MainActor [weak self] in if self?.isPlaying == false { self?.toggle() }; self?.requestNavigation() }
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
        artworkTask?.cancel()
        nowPlayingArtwork = nil
        guard let path = song.artworkFile else { return }
        artworkTask = Task { [weak self] in
            let image = await Task.detached(priority: .utility) { UIImage(contentsOfFile: path) }.value
            guard !Task.isCancelled, let self, self.current?.id == song.id, let image else { return }
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
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let nowPlayingArtwork { info[MPMediaItemPropertyArtwork] = nowPlayingArtwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
