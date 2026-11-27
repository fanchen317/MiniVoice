import AppKit
import Foundation
import MediaPlayer

/// Bridges macOS system media keys and Now Playing control center to `MusicLibrary`.
@MainActor
final class SystemMediaControls {
    private weak var library: MusicLibrary?
    private var artworkIdentity: String?
    private var cachedArtwork: MPMediaItemArtwork?
    private var lastSyncedKey: String?
    private var lastSyncedTime: TimeInterval = -1
    private var started = false

    init(library: MusicLibrary) {
        self.library = library
    }

    func start(registerCommands: Bool = true) {
        if registerCommands && !started {
            started = true
            configureRemoteCommands()
        }
        sync(force: true)
    }

    func sync(force: Bool = false) {
        guard let library else { return }
        guard let track = library.playingTrack else {
            if force || lastSyncedKey != nil {
                lastSyncedKey = nil
                lastSyncedTime = -1
                artworkIdentity = nil
                cachedArtwork = nil
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                MPNowPlayingInfoCenter.default().playbackState = .stopped
            }
            return
        }

        let currentTime = max(0, library.playbackTime.isFinite ? library.playbackTime : 0)
        let key = "\(track.id.uuidString)|\(track.title)|\(track.artist)|\(track.album)|\(track.duration)|\(track.artworkKey ?? "")|\(library.isPlaying)"
        let timeDelta = abs(currentTime - lastSyncedTime)
        if !force && key == lastSyncedKey && timeDelta < 1.0 {
            return
        }

        let artKey = "\(track.id.uuidString)|\(track.artworkKey ?? "")"
        if artworkIdentity != artKey {
            artworkIdentity = artKey
            if let image = track.artwork {
                let size = image.size.width > 0 && image.size.height > 0 ? image.size : NSSize(width: 256, height: 256)
                cachedArtwork = MPMediaItemArtwork(boundsSize: size) { _ in image }
            } else {
                cachedArtwork = nil
            }
        }

        lastSyncedKey = key
        lastSyncedTime = currentTime

        let info = Self.nowPlayingInfo(
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration,
            elapsedTime: currentTime,
            isPlaying: library.isPlaying,
            artwork: cachedArtwork
        )
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = info
        center.playbackState = library.isPlaying ? .playing : .paused
    }

    nonisolated static func nowPlayingInfo(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        elapsedTime: TimeInterval,
        isPlaying: Bool,
        artwork: MPMediaItemArtwork? = nil
    ) -> [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: album,
            MPMediaItemPropertyPlaybackDuration: max(0, duration.isFinite ? duration : 0),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, elapsedTime.isFinite ? elapsedTime : 0),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        return info
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.library?.play(); self?.sync(force: true) }
            return .success
        }
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.library?.pause(); self?.sync(force: true) }
            return .success
        }
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.library?.togglePlayback(); self?.sync(force: true) }
            return .success
        }
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.library?.skip(1); self?.sync(force: true) }
            return .success
        }
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.library?.skip(-1); self?.sync(force: true) }
            return .success
        }
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let position = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else {
                return .commandFailed
            }
            Task { @MainActor [weak self] in self?.library?.seek(to: position); self?.sync(force: true) }
            return .success
        }
    }
}
