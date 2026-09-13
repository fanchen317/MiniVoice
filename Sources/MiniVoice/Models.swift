import AppKit
import AVFoundation
import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    var timestamp: TimeInterval?
    var text: String
}

struct Track: Identifiable {
    var id = UUID()
    let url: URL
    var title: String
    var artist: String
    var album: String
    var lyrics: String
    var artwork: NSImage?
    var duration: TimeInterval

    var canWriteTags: Bool { ["mp3", "flac", "m4a"].contains(url.pathExtension.lowercased()) }

    var lyricLines: [LyricLine] { LRCParser.parse(lyrics) }
}

@MainActor
final class MusicLibrary: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var tracks: [Track] = []
    @Published var selectedID: Track.ID?
    @Published var isPlaying = false
    @Published var playbackTime: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var isImporting = false
    @Published var volume: Float = 0.8 { didSet { player?.volume = volume } }
    private var pendingImports: [URL] = []
    private let savedURLsKey = "MiniVoice.libraryURLs"
    override init() {
        super.init()
        let urls = (UserDefaults.standard.stringArray(forKey: savedURLsKey) ?? []).map { URL(fileURLWithPath: $0) }
        importFiles(urls.filter { FileManager.default.fileExists(atPath: $0.path) })
    }
    private var player: AVAudioPlayer?
    private var timer: Timer?

    var selectedTrack: Track? { tracks.first { $0.id == selectedID } }
    var selectedIndex: Int? { tracks.firstIndex { $0.id == selectedID } }

    func importFiles(_ urls: [URL]) {
        let accepted = urls.filter { ["mp3", "flac", "m4a", "aac", "wav", "aiff"].contains($0.pathExtension.lowercased()) }
        pendingImports.append(contentsOf: accepted)
        guard !isImporting else { return }
        isImporting = true
        Task {
            while !pendingImports.isEmpty {
                let url = pendingImports.removeFirst()
                guard !tracks.contains(where: { $0.url == url }) else { continue }
                let probe = await Task.detached { try? MediaTools.run("ffprobe", ["-v", "error", "-show_format", "-show_streams", "-of", "json", url.path]) }.value
                if var track = await readTrack(url) {
                    if let probe,
                       let json = try? JSONSerialization.jsonObject(with: probe) as? [String: Any],
                       let format = json["format"] as? [String: Any] {
                        let tags = (format["tags"] as? [String: String] ?? [:]).reduce(into: [String: String]()) { $0[$1.key.lowercased()] = $1.value }
                        track.title = tags["title"] ?? track.title
                        track.artist = tags["artist"] ?? track.artist
                        track.album = tags["album"] ?? track.album
                        track.lyrics = tags["lyrics"] ?? tags["unsyncedlyrics"] ?? track.lyrics
                        track.duration = Double(format["duration"] as? String ?? "") ?? track.duration
                        if track.artwork == nil,
                           let streams = json["streams"] as? [[String: Any]],
                           let cover = streams.first(where: { ($0["disposition"] as? [String: Int])?["attached_pic"] == 1 }),
                           let index = cover["index"] as? Int {
                            let data = await Task.detached { try? MediaTools.run("ffmpeg", ["-v", "error", "-i", url.path, "-map", "0:\(index)", "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "pipe:1"]) }.value
                            track.artwork = data.flatMap(NSImage.init(data:))
                        }
                    }
                    if track.lyrics.isEmpty {
                        let sidecar = url.deletingPathExtension().appendingPathExtension("lrc")
                        track.lyrics = (try? String(contentsOf: sidecar, encoding: .utf8)) ?? ""
                    }
                    guard track.duration > 0 else {
                        errorMessage = "无法读取音频：\(url.lastPathComponent)"
                        continue
                    }
                    tracks.append(track)
                }
            }
            if selectedID == nil { selectedID = tracks.first?.id }
            UserDefaults.standard.set(tracks.map { $0.url.path }, forKey: savedURLsKey)
            isImporting = false
        }
    }

    func select(_ id: Track.ID) { selectedID = id; stop() }

    func togglePlayback() { isPlaying ? pause() : play() }

    func play() {
        guard let index = selectedIndex else { return }
        let track = tracks[index]
        do {
            if player?.url != track.url {
                player?.stop()
                player = try AVAudioPlayer(contentsOf: track.url)
                player?.delegate = self
                player?.prepareToPlay()
                player?.currentTime = playbackTime
            }
            player?.volume = volume
            isPlaying = player?.play() == true
            beginTimer()
        } catch { errorMessage = "无法播放这首文件：\(error.localizedDescription)" }
    }

    func pause() { player?.pause(); isPlaying = false; timer?.invalidate() }
    func stop() { player?.stop(); player = nil; isPlaying = false; playbackTime = 0; timer?.invalidate() }
    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, selectedTrack?.duration ?? 0))
        player?.currentTime = clamped; playbackTime = clamped
    }

    func skip(_ delta: Int) {
        guard let index = selectedIndex, tracks.indices.contains(index + delta) else { return }
        let resume = isPlaying
        select(tracks[index + delta].id)
        if resume { play() }
    }

    func save(_ updated: Track) async throws {
        let png: Data?
        if let art = updated.artwork {
            guard let tiff = art.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                  let data = bitmap.representation(using: .png, properties: [:]) else { throw TagWriteError.artworkEncodingFailed }
            png = data
        } else { png = nil }
        let payload = TagPayload(url: updated.url, title: updated.title, artist: updated.artist,
                                 album: updated.album, lyrics: updated.lyrics, artwork: png)
        try await Task.detached { try FFMpegTagWriter.write(payload) }.value
        if let index = tracks.firstIndex(where: { $0.id == updated.id }) { tracks[index] = updated }
        if selectedID == updated.id {
            let time = playbackTime
            let resume = isPlaying
            stop(); playbackTime = time
            if resume { play() }
        }
    }

    func activeLyricIndex(for lines: [LyricLine]) -> Int? {
        let timed = lines.enumerated().filter { $0.element.timestamp != nil }
        guard !timed.isEmpty else { return nil }
        return timed.last(where: { $0.element.timestamp! <= playbackTime })?.offset
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.playbackFinished() }
    }

    private func playbackFinished() { isPlaying = false; timer?.invalidate() }

    private func beginTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.playbackTime = self?.player?.currentTime ?? 0 }
        }
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
        return Track(url: url, title: title, artist: artist, album: album, lyrics: "", artwork: artData.flatMap(NSImage.init(data:)), duration: seconds.isFinite ? seconds : 0)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
