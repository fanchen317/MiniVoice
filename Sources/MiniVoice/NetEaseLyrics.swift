import Foundation

/// Public catalog lookup followed by the native YRC/LRC lyric response.
/// Failures are isolated by OnlineLyricsSearch so other providers still work.
enum NetEaseLyrics {
    struct Song: Decodable, Sendable {
        let id: Int
        let name: String
        let artists: [Artist]
        let album: Album?
        let duration: Double?
        var artistName: String { artists.map(\.name).joined(separator: " / ") }
        struct Artist: Decodable, Sendable { let name: String }
        struct Album: Decodable, Sendable { let name: String }
    }

    static func search(title: String, artist: String, duration: Double) async throws -> [OnlineLyricsResult] {
        let query = [title, artist].filter { !$0.isEmpty }.joined(separator: " ")
        let data = try await fetch(path: "/api/search/get/web", query: [
            URLQueryItem(name: "s", value: query), URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "offset", value: "0"), URLQueryItem(name: "limit", value: "5")
        ])
        let songs = try parseSearch(data).sorted {
            result(song: $0, lyrics: "").score(title: title, artist: artist, duration: duration)
                > result(song: $1, lyrics: "").score(title: title, artist: artist, duration: duration)
        }
        return await withTaskGroup(of: OnlineLyricsResult?.self) { group in
            for song in songs.prefix(3) {
                group.addTask {
                    do {
                        let data = try await fetch(path: "/api/song/lyric/v1", query: [
                            URLQueryItem(name: "id", value: String(song.id)), URLQueryItem(name: "cp", value: "false")
                        ] + ["tv", "lv", "rv", "kv", "yv", "ytv", "yrv"].map { URLQueryItem(name: $0, value: "0") })
                        return try parseLyrics(data, song: song)
                    } catch { return nil }
                }
            }
            var results: [OnlineLyricsResult] = []
            for await item in group { if let item { results.append(item) } }
            return results
        }
    }

    static func parseSearch(_ data: Data) throws -> [Song] {
        let payload = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard payload.code == 200 else { throw URLError(.badServerResponse) }
        return payload.result?.songs ?? []
    }

    static func parseLyrics(_ data: Data, song: Song) throws -> OnlineLyricsResult? {
        let payload = try JSONDecoder().decode(LyricsResponse.self, from: data)
        guard payload.code == 200 else { throw URLError(.badServerResponse) }
        guard let lyrics = [payload.yrc?.lyric, payload.lrc?.lyric].compactMap({ $0 }).map(cleaned).filter({ !$0.isEmpty }).max(by: {
            LyricTimingKind.detect(LRCParser.parse($0, placeholder: false)).rawValue
                < LyricTimingKind.detect(LRCParser.parse($1, placeholder: false)).rawValue
        }) else { return nil }
        let translated = LyricTimingKind.detect(LRCParser.parse(lyrics, placeholder: false)) == .word
            ? (payload.ytlrc?.lyric ?? payload.tlyric?.lyric) : payload.tlyric?.lyric
        return result(song: song, lyrics: LyricsTranslation.attaching(translated.map(cleaned), to: lyrics))
    }

    private static func result(song: Song, lyrics: String) -> OnlineLyricsResult {
        let timed = LyricTimingKind.detect(LRCParser.parse(lyrics, placeholder: false)) != .plain
        return OnlineLyricsResult(id: "netease:\(song.id)", source: "网易云", trackName: song.name,
                                  artistName: song.artistName, albumName: song.album?.name,
                                  duration: song.duration.map { $0 / 1000 },
                                  syncedLyrics: timed ? lyrics : nil, plainLyrics: timed ? nil : lyrics)
    }

    /// YRC may begin with JSON credit rows. Convert only their text and timing,
    /// rather than showing JSON/URLs as lyric lines or losing their timestamps.
    private static func cleaned(_ source: String) -> String {
        let text = source.components(separatedBy: .newlines).compactMap { raw -> String? in
            let row = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard row.hasPrefix("{") else { return row }
            guard let credit = try? JSONDecoder().decode(Credit.self, from: Data(row.utf8)) else { return nil }
            let text = credit.c.map(\.tx).joined()
            return text.isEmpty ? nil : LRCParser.stamp(credit.t / 1000, text: text)
        }.joined(separator: "\n")
        return LyricsText.normalized(text).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fetch(path: String, query: [URLQueryItem]) async throws -> Data {
        var url = URLComponents(string: "https://music.163.com\(path)")!
        url.queryItems = query
        var request = URLRequest(url: url.url!)
        request.timeoutInterval = 12
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, data.count < 1_000_000 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private struct SearchResponse: Decodable { let code: Int; let result: Results? }
    private struct Results: Decodable { let songs: [Song]? }
    private struct LyricsResponse: Decodable {
        let code: Int
        let yrc: Lyrics?
        let lrc: Lyrics?
        let tlyric: Lyrics?
        let ytlrc: Lyrics?
    }
    private struct Lyrics: Decodable { let lyric: String? }
    private struct Credit: Decodable {
        let t: Double
        let c: [Part]
        struct Part: Decodable { let tx: String }
    }
}
