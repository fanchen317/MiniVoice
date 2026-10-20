import Foundation
import zlib

enum AdditionalLyricsSources {
    static func qq(title: String, artist: String, duration: Double = 0) async throws -> [OnlineLyricsResult] {
        if let native = try? await QQWordLyrics.search(title: title, artist: artist, duration: duration), !native.isEmpty { return native }
        let data = try await OnlineArtworkSearch.fetch("https://c.y.qq.com/soso/fcgi-bin/client_search_cp", query: [
            URLQueryItem(name: "w", value: "\(title) \(artist)"), URLQueryItem(name: "p", value: "1"),
            URLQueryItem(name: "n", value: "3"), URLQueryItem(name: "format", value: "json"), URLQueryItem(name: "t", value: "0")
        ])
        let payload = try JSONDecoder().decode(QQSearch.self, from: data)
        guard payload.code == 0 else { throw URLError(.badServerResponse) }
        return await withTaskGroup(of: OnlineLyricsResult?.self) { group in
            for song in payload.data?.song?.list ?? [] {
                group.addTask {
                    guard let data = try? await OnlineArtworkSearch.fetch("https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg", query: [
                        URLQueryItem(name: "songmid", value: song.songmid), URLQueryItem(name: "format", value: "json"),
                        URLQueryItem(name: "nobase64", value: "1")
                    ]), let text = try? parseQQ(data) else { return nil }
                    return result(id: "qq:\(song.songmid)", source: "QQ 音乐", title: song.songname,
                                  artist: song.singer.map(\.name).joined(separator: " / "), album: song.albumname,
                                  duration: song.interval, text: text)
                }
            }
            var results: [OnlineLyricsResult] = []
            for await item in group { if let item { results.append(item) } }
            return results
        }
    }

    static func parseQQ(_ data: Data) throws -> String? {
        let payload = try JSONDecoder().decode(QQLyrics.self, from: data)
        guard payload.retcode == 0, payload.code == nil || payload.code == 0 else { throw URLError(.badServerResponse) }
        guard let raw = payload.lyric else { return nil }
        // The nobase64 response escapes newlines once more inside the JSON string.
        let text = raw.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\r", with: "")
            .replacingOccurrences(of: "\\\"", with: "\"")
        let translated = payload.trans?.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\r", with: "")
        return LyricsTranslation.attaching(translated, to: LyricsText.normalized(text)).nilIfEmpty
    }

    static func kugou(title: String, artist: String, duration: Double) async throws -> [OnlineLyricsResult] {
        let data = try? await OnlineArtworkSearch.fetch("https://songsearch.kugou.com/song_search_v2", query: [
            URLQueryItem(name: "keyword", value: "\(title) \(artist)"), URLQueryItem(name: "page", value: "1"), URLQueryItem(name: "pagesize", value: "8")
        ])
        let payload = data.flatMap { try? JSONDecoder().decode(KugouSongs.self, from: $0) }
        let songs = (payload?.status == 1 ? payload?.data?.lists ?? [] : []).sorted {
            result(id: "", source: "", title: $0.OriSongName ?? $0.SongName, artist: $0.SingerName ?? "", album: nil, duration: $0.Duration, text: "")
                .score(title: title, artist: artist, duration: duration)
            > result(id: "", source: "", title: $1.OriSongName ?? $1.SongName, artist: $1.SingerName ?? "", album: nil, duration: $1.Duration, text: "")
                .score(title: title, artist: artist, duration: duration)
        }
        let results = await withTaskGroup(of: [OnlineLyricsResult].self) { group in
            for song in songs.prefix(4) {
                group.addTask { (try? await kugouSong(song)) ?? [] }
            }
            var results: [OnlineLyricsResult] = []
            for await response in group { results += response }
            return results
        }
        if results.contains(where: { $0.timingKind == .word }) { return results }
        // Lyric search remains useful when the separate song catalog is unavailable.
        let fallback = try? await kugouCandidates(query: [
            URLQueryItem(name: "ver", value: "1"), URLQueryItem(name: "man", value: "yes"), URLQueryItem(name: "client", value: "pc"),
            URLQueryItem(name: "keyword", value: "\(artist) - \(title)"),
            URLQueryItem(name: "duration", value: String(Int(max(0, duration.isFinite ? duration : 0) * 1000)))
        ], album: nil, title: title, duration: duration)
        return results + (fallback ?? [])
    }

    private static func kugouSong(_ song: KugouSong) async throws -> [OnlineLyricsResult] {
        try await kugouCandidates(query: [
            URLQueryItem(name: "ver", value: "1"), URLQueryItem(name: "man", value: "yes"), URLQueryItem(name: "client", value: "pc"),
            URLQueryItem(name: "hash", value: song.FileHash), URLQueryItem(name: "keyword", value: song.OriSongName ?? song.SongName),
            URLQueryItem(name: "duration", value: String(Int(song.Duration * 1000)))
        ], album: song.AlbumName, title: song.OriSongName ?? song.SongName, duration: song.Duration)
    }

    private static func kugouCandidates(query: [URLQueryItem], album: String?, title: String, duration: Double) async throws -> [OnlineLyricsResult] {
        let data = try await OnlineArtworkSearch.fetch("https://lyrics.kugou.com/search", query: query)
        let payload = try JSONDecoder().decode(KugouCandidates.self, from: data)
        guard payload.status == 200 else { throw URLError(.badServerResponse) }
        let candidates = (payload.candidates ?? []).sorted {
            result(id: "", source: "", title: $0.song, artist: "", album: nil, duration: $0.duration / 1000, text: "").score(title: title, artist: "", duration: duration)
                > result(id: "", source: "", title: $1.song, artist: "", album: nil, duration: $1.duration / 1000, text: "").score(title: title, artist: "", duration: duration)
        }
        return await withTaskGroup(of: OnlineLyricsResult?.self) { group in
            for candidate in candidates.prefix(3) {
                group.addTask {
                    for format in ["krc", "lrc"] {
                        guard let data = try? await OnlineArtworkSearch.fetch("https://lyrics.kugou.com/download", query: [
                            URLQueryItem(name: "ver", value: "1"), URLQueryItem(name: "client", value: "pc"),
                            URLQueryItem(name: "id", value: candidate.id), URLQueryItem(name: "accesskey", value: candidate.accesskey),
                            URLQueryItem(name: "fmt", value: format), URLQueryItem(name: "charset", value: "utf8")
                        ]), let text = try? parseKugouDownload(data) else { continue }
                        return result(id: "kugou:\(candidate.id)", source: "酷狗音乐", title: candidate.song,
                                      artist: candidate.singer, album: album,
                                      duration: candidate.duration / 1000, text: text)
                    }
                    return nil
                }
            }
            var results: [OnlineLyricsResult] = []
            for await item in group { if let item { results.append(item) } }
            return results
        }
    }

    static func parseKugouDownload(_ data: Data) throws -> String? {
        let payload = try JSONDecoder().decode(KugouDownload.self, from: data)
        guard payload.status == 200, let encoded = payload.content,
              let content = Data(base64Encoded: encoded), content.count <= 1_000_000 else { throw URLError(.cannotDecodeContentData) }
        if content.starts(with: Data("krc1".utf8)) {
            guard content.starts(with: Data("krc1".utf8)), content.count > 4 else { throw URLError(.cannotDecodeContentData) }
            let key: [UInt8] = [64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105]
            let compressed = content.dropFirst(4).enumerated().map { $0.element ^ key[$0.offset % key.count] }
            var buffer = [UInt8](repeating: 0, count: 1_000_000)
            var count = uLongf(buffer.count)
            guard uncompress(&buffer, &count, compressed, uLong(compressed.count)) == Z_OK,
                  let source = String(bytes: buffer.prefix(Int(count)), encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
            return LyricsTranslation.attaching(LyricsTranslation.fromKRC(source), to: LyricsTiming.krc(source)).nilIfEmpty
        }
        guard let text = String(data: content, encoding: .utf8),
              text.range(of: #"\[\d+:\d{2}"#, options: .regularExpression) != nil else { throw URLError(.cannotDecodeContentData) }
        return LyricsText.normalized(text).nilIfEmpty
    }

    private static func result(id: String, source: String, title: String, artist: String, album: String?, duration: Double?, text: String) -> OnlineLyricsResult {
        let timed = LyricTimingKind.detect(LRCParser.parse(text, placeholder: false)) != .plain
        return OnlineLyricsResult(id: id, source: source, trackName: title, artistName: artist, albumName: album,
                                  duration: duration, syncedLyrics: timed ? text : nil, plainLyrics: timed ? nil : text)
    }

    private struct QQSearch: Decodable { let code: Int; let data: QQData? }
    private struct QQData: Decodable { let song: QQSongs? }
    private struct QQSongs: Decodable { let list: [QQSong]? }
    private struct QQSong: Decodable {
        let songmid: String; let songname: String; let albumname: String?; let interval: Double?; let singer: [Singer]
        struct Singer: Decodable { let name: String }
    }
    private struct QQLyrics: Decodable { let retcode: Int; let code: Int?; let lyric: String?; let trans: String? }
    private struct KugouSongs: Decodable { let status: Int; let data: KugouSongRows? }
    private struct KugouSongRows: Decodable { let lists: [KugouSong]? }
    private struct KugouSong: Decodable {
        let FileHash: String; let SongName: String; let OriSongName: String?; let AlbumName: String?; let Duration: Double
        let SingerName: String?
    }
    private struct KugouCandidates: Decodable { let status: Int; let candidates: [KugouCandidate]? }
    private struct KugouCandidate: Decodable, Sendable {
        let id: String; let accesskey: String; let song: String; let singer: String; let duration: Double
    }
    private struct KugouDownload: Decodable { let status: Int; let fmt: String?; let content: String? }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
