import AppKit
import AVFoundation
import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    var timestamp: TimeInterval?
    var text: String
}

struct Track: Identifiable {
    let id = UUID()
    let url: URL
    var title: String
    var artist: String
    var album: String
    var lyrics: String
    var artwork: NSImage?
    var duration: TimeInterval

    var lyricLines: [LyricLine] { LRCParser.parse(lyrics) }
}

enum LRCParser {
    static func parse(_ source: String) -> [LyricLine] {
        let lines = source.components(separatedBy: .newlines)
        let expression = try? NSRegularExpression(pattern: #"^\s*\[(\d{1,2}):(\d{2}(?:\.\d{1,3})?)\]\s*(.*)$"#)
        let parsed = lines.compactMap { line -> LyricLine? in
            let range = NSRange(line.startIndex..., in: line)
            guard let match = expression?.firstMatch(in: line, range: range),
                  let minuteRange = Range(match.range(at: 1), in: line),
                  let secondRange = Range(match.range(at: 2), in: line),
                  let textRange = Range(match.range(at: 3), in: line),
                  let minutes = Double(line[minuteRange]), let seconds = Double(line[secondRange]) else {
                return line.trimmingCharacters(in: .whitespaces).isEmpty ? nil : LyricLine(timestamp: nil, text: line)
            }
            return LyricLine(timestamp: minutes * 60 + seconds, text: String(line[textRange]))
        }
        return parsed.isEmpty ? [LyricLine(timestamp: nil, text: "尚未添加歌词")] : parsed
    }

    static func timestamped(_ plainText: String, every seconds: TimeInterval = 4) -> String {
        plainText.components(separatedBy: .newlines).enumerated().compactMap { offset, line in
            let text = line.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            let point = TimeInterval(offset) * seconds
            return String(format: "[%02d:%05.2f] %@", Int(point / 60), point.truncatingRemainder(dividingBy: 60), text)
        }.joined(separator: "\n")
    }
}

@MainActor
final class MusicLibrary: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var tracks: [Track] = []
    @Published var selectedID: Track.ID?
    @Published var isPlaying = false
    @Published var playbackTime: TimeInterval = 0
    @Published var errorMessage: String?
    private var player: AVAudioPlayer?
    private var timer: Timer?

    var selectedTrack: Track? { tracks.first { $0.id == selectedID } }
    var selectedIndex: Int? { tracks.firstIndex { $0.id == selectedID } }

    func importFiles(_ urls: [URL]) {
        let accepted = urls.filter { ["mp3", "flac", "m4a", "aac", "wav", "aiff"].contains($0.pathExtension.lowercased()) }
        for url in accepted where !tracks.contains(where: { $0.url == url }) {
            if let track = readTrack(url) { tracks.append(track) }
        }
        if selectedID == nil { selectedID = tracks.first?.id }
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
                playbackTime = 0
            }
            player?.play()
            isPlaying = true
            beginTimer()
        } catch { errorMessage = "无法播放这首文件：\(error.localizedDescription)" }
    }

    func pause() { player?.pause(); isPlaying = false; timer?.invalidate() }
    func stop() { player?.stop(); player = nil; isPlaying = false; playbackTime = 0; timer?.invalidate() }
    func seek(to time: TimeInterval) { player?.currentTime = time; playbackTime = time }

    func updateSelected(title: String, artist: String, album: String, lyrics: String, artwork: NSImage?) {
        guard let index = selectedIndex else { return }
        tracks[index].title = title
        tracks[index].artist = artist
        tracks[index].album = album
        tracks[index].lyrics = lyrics
        tracks[index].artwork = artwork
        objectWillChange.send()
    }

    func saveSelectedToFile(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let track = selectedTrack else { return }
        FFMpegTagWriter.write(track: track) { result in
            DispatchQueue.main.async {
                if case .success = result { self.importFiles([track.url]) }
                completion(result)
            }
        }
    }

    func activeLyricIndex(for lines: [LyricLine]) -> Int? {
        let timed = lines.enumerated().filter { $0.element.timestamp != nil }
        guard !timed.isEmpty else { return nil }
        return timed.last(where: { $0.element.timestamp! <= playbackTime })?.offset ?? timed.first?.offset
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

    private func readTrack(_ url: URL) -> Track? {
        let asset = AVURLAsset(url: url)
        let metadata = asset.commonMetadata + asset.metadata
        func value(_ identifier: AVMetadataIdentifier) -> String {
            AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier).first?.stringValue ?? ""
        }
        let title = value(.commonIdentifierTitle).ifEmpty(url.deletingPathExtension().lastPathComponent)
        let artist = value(.commonIdentifierArtist).ifEmpty("未知歌手")
        let album = value(.commonIdentifierAlbumName).ifEmpty("未归类专辑")
        let lyric = metadata.filter {
            (($0.key as? String)?.lowercased().contains("lyric") == true) ||
            ($0.identifier?.rawValue.lowercased().contains("lyric") == true)
        }.first?.stringValue ?? ""
        let artData = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtwork).first?.dataValue
        let duration = asset.duration.seconds.isFinite ? asset.duration.seconds : 0
        return Track(url: url, title: title, artist: artist, album: album, lyrics: lyric, artwork: artData.flatMap(NSImage.init(data:)), duration: duration)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
