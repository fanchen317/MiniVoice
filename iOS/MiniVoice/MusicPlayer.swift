import AVFoundation
import Combine
import MediaPlayer
import UIKit

@MainActor
final class MusicPlayer: ObservableObject {
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
    private var playbackObserver: NSKeyValueObservation?
    private var resumeAfterInterruption = false
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var accessURL: URL?
    private weak var library: MusicLibrary?
    private var nowPlayingArtwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?

    init() {
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

    var duration: TimeInterval { current?.duration ?? 0 }

    func play(_ song: Song, queue songs: [Song], library: MusicLibrary) {
        self.library = library
        queue = songs.contains(song) ? songs : [song] + songs
        load(song, autoplay: true)
    }

    private func load(_ song: Song, autoplay: Bool) {
        guard let library,
              let root = library.folderURL(for: song),
              let url = library.url(for: song) else {
            errorMessage = "音乐文件夹不可访问，请在设置中重新选择。"
            return
        }
        clearPlayer()
        let accessing = root.startAccessingSecurityScopedResource()
        accessURL = accessing ? root : nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "无法启动音频播放：\(error.localizedDescription)"
            return
        }
        current = song
        position = 0
        refreshNowPlayingArtwork(song)
        let item = AVPlayerItem(url: url)
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor [weak self] in
                guard self?.player?.currentItem === item else { return }
                self?.pause()
                self?.errorMessage = "无法播放此音频，格式或编码可能不受 iOS 支持：" + (item.error?.localizedDescription ?? "请检查文件是否完整")
            }
        }
        let next = AVPlayer(playerItem: item)
        player = next
        playbackObserver = next.observe(\.timeControlStatus, options: [.new]) { [weak self] observed, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player === observed else { return }
                self.isPlaying = observed.timeControlStatus == .playing || observed.timeControlStatus == .waitingToPlayAtSpecifiedRate
                self.updateNowPlaying()
            }
        }
        timeObserver = next.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, self.player === next else { return }
                self.position = max(0, time.seconds.isFinite ? time.seconds : 0)
                self.updateNowPlaying()
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.didFinish() }
        }
        if autoplay {
            next.play()
            isPlaying = true
            library.recordPlayed(song)
        } else {
            isPlaying = false
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
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
        updateNowPlaying()
    }

    func pause() {
        resumeAfterInterruption = false
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func seek(to seconds: TimeInterval) {
        guard let player else { return }
        let value = max(0, min(seconds, max(duration, 0)))
        player.seek(to: CMTime(seconds: value, preferredTimescale: 600))
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
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        statusObserver?.invalidate(); playbackObserver?.invalidate(); playbackObserver = nil
        player?.pause()
        player = nil
        isPlaying = false
        current = nil
        position = 0
        timeObserver = nil
        endObserver = nil
        statusObserver = nil
        accessURL?.stopAccessingSecurityScopedResource()
        accessURL = nil
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
