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
    @Published var errorMessage: String?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var accessURL: URL?
    private weak var library: MusicLibrary?
    private var nowPlayingArtwork: MPMediaItemArtwork?
    private var shuffleRemaining: [String] = []
    private var shuffleHistory: [String] = []

    init() {
        if let saved = UserDefaults.standard.object(forKey: "playbackMode") as? Int {
            mode = PlaybackMode(rawValue: saved) ?? .sequential
        }
        configureRemoteCommands()
    }

    var duration: TimeInterval { current?.duration ?? 0 }

    func play(_ song: Song, queue songs: [Song], library: MusicLibrary) {
        self.library = library
        queue = songs.contains(song) ? songs : [song] + songs
        shuffleRemaining = queue.map(\.id).filter { $0 != song.id }
        shuffleHistory.removeAll()
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
        if let path = song.artworkFile, let image = UIImage(contentsOfFile: path) {
            nowPlayingArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        } else {
            nowPlayingArtwork = nil
        }
        let item = AVPlayerItem(url: url)
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor [weak self] in
                self?.pause()
                self?.errorMessage = item.error?.localizedDescription ?? "无法播放这个音频文件。"
            }
        }
        let next = AVPlayer(playerItem: item)
        player = next
        timeObserver = next.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
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

    func toggle() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
        updateNowPlaying()
    }

    func pause() {
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
        guard let current, let index = queue.firstIndex(of: current) else { return }
        if mode == .shuffle, let previousID = shuffleHistory.popLast(), let song = queue.first(where: { $0.id == previousID }) {
            load(song, autoplay: true)
        } else if index > 0 {
            load(queue[index - 1], autoplay: true)
        } else if mode == .repeatAll, let last = queue.last {
            load(last, autoplay: true)
        } else {
            seek(to: 0)
        }
    }

    private func didFinish() { advance(manual: false) }

    private func advance(manual: Bool) {
        guard let current, let index = queue.firstIndex(of: current), !queue.isEmpty else { return }
        if !manual && mode == .repeatOne { load(current, autoplay: true); return }
        if mode == .shuffle {
            if shuffleRemaining.isEmpty {
                if !manual { pause(); seek(to: duration); return }
                shuffleRemaining = queue.map(\.id).filter { $0 != current.id }
            }
            if let id = shuffleRemaining.randomElement(), let song = queue.first(where: { $0.id == id }) {
                shuffleRemaining.removeAll { $0 == id }
                shuffleHistory.append(current.id)
                load(song, autoplay: true)
            }
            return
        }
        if !manual && mode == .single { pause(); seek(to: duration); return }
        let nextIndex = index + 1
        if nextIndex < queue.count {
            load(queue[nextIndex], autoplay: true)
        } else if mode == .repeatAll || manual {
            load(queue[0], autoplay: true)
        } else {
            pause()
            seek(to: duration)
        }
    }

    private func clearPlayer() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        statusObserver?.invalidate()
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
            Task { @MainActor [weak self] in if self?.isPlaying == false { self?.toggle() } }
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
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let value = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else { return .commandFailed }
            Task { @MainActor [weak self] in self?.seek(to: value) }
            return .success
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
