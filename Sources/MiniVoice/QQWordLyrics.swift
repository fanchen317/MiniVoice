import Foundation

enum QQWordLyrics {
    static func search(title: String, artist: String, duration: Double) async throws -> [OnlineLyricsResult] {
        let data = try await request(method: "DoSearchForQQMusicLite", module: "music.search.SearchCgiService", parameters: [
            "query": "\(title) \(artist)", "search_type": 0, "num_per_page": 12, "page_num": 1, "highlight": 0, "grp": 1
        ])
        let songs = try JSONDecoder().decode(Search.self, from: data).body.item_song.sorted {
            $0.result("").score(title: title, artist: artist, duration: duration) > $1.result("").score(title: title, artist: artist, duration: duration)
        }
        return await withTaskGroup(of: OnlineLyricsResult?.self) { group in
            for song in songs.prefix(6) {
                group.addTask {
                    let b64: (String) -> String = { Data($0.utf8).base64EncodedString() }
                    guard let data = try? await request(method: "GetPlayLyricInfo", module: "music.musichallSong.PlayLyricInfo", parameters: [
                        "songID": song.id, "songName": b64(song.title), "singerName": b64(song.singer.map(\.name).joined(separator: ", ")),
                        "albumName": b64(song.album?.name ?? ""), "interval": song.interval ?? 0,
                        "qrc": 1, "qrc_t": 0, "lrc_t": 0, "crypt": 1, "trans": 1, "trans_t": 0,
                        "roma": 0, "type": 0, "ct": 19, "cv": 2111
                    ]), let source = try? parse(data), !source.isEmpty else { return nil }
                    return song.result(source)
                }
            }
            var results: [OnlineLyricsResult] = []
            for await result in group { if let result { results.append(result) } }
            return results
        }
    }

    static func parse(_ data: Data) throws -> String {
        let payload = try JSONDecoder().decode(Lyrics.self, from: data)
        guard let lyric = payload.lyric, !lyric.isEmpty else { return "" }
        let main = try QRCLyrics.convert(QRCLyrics.decrypt(lyric))
        let translated = payload.trans.flatMap { $0.isEmpty ? nil : try? QRCLyrics.convert(QRCLyrics.decrypt($0)) }
        return LyricsTranslation.attaching(translated, to: main)
    }

    private static func request(method: String, module: String, parameters: [String: Any]) async throws -> Data {
        let body: [String: Any] = [
            "comm": ["ct": 11, "cv": "1003006", "v": "1003006", "tmeAppID": "qqmusiclight", "uid": "0"],
            "request": ["method": method, "module": module, "param": parameters]
        ]
        var request = URLRequest(url: URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg")!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("okhttp/3.14.9", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 2_000_000,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["code"] as? Int == 0,
              let result = root["request"] as? [String: Any], result["code"] as? Int == 0, let payload = result["data"] else { throw URLError(.badServerResponse) }
        return try JSONSerialization.data(withJSONObject: payload)
    }

    private struct Search: Decodable { let body: Body }
    private struct Body: Decodable { let item_song: [Song] }
    private struct Lyrics: Decodable { let lyric: String?; let trans: String? }
    private struct Song: Decodable, Sendable {
        let id: Int
        let mid: String
        let title: String
        let interval: Double?
        let singer: [Singer]
        let album: Album?
        struct Singer: Decodable, Sendable { let name: String }
        struct Album: Decodable, Sendable { let name: String }
        func result(_ text: String) -> OnlineLyricsResult {
            OnlineLyricsResult(id: "qq:\(mid)", source: "QQ 音乐", trackName: title, artistName: singer.map(\.name).joined(separator: " / "),
                               albumName: album?.name, duration: interval, syncedLyrics: text, plainLyrics: nil)
        }
    }
}
