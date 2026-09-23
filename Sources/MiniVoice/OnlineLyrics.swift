import Foundation

enum ChineseLyricsScript {
    static func simplified(_ text: String) -> String { transform(text, id: "Traditional-Simplified") }
    static func traditional(_ text: String) -> String { transform(text, id: "Simplified-Traditional") }

    private static func transform(_ text: String, id: String) -> String {
        let value = NSMutableString(string: text)
        let fullRange = NSRange(location: 0, length: value.length)
        guard value.applyTransform(StringTransform(id), reverse: false, range: fullRange, updatedRange: nil) else { return text }
        return value as String
    }
}

struct OnlineLyricsResult: Decodable, Identifiable, Sendable {
    let id: String
    let source: String
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Double?
    let syncedLyrics: String?
    let plainLyrics: String?
    let instrumental: Bool

    private enum CodingKeys: String, CodingKey {
        case id, trackName, artistName, albumName, duration, syncedLyrics, plainLyrics, instrumental
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: "lrclib:\(try values.decode(Int.self, forKey: .id))", source: "LRCLIB",
                  trackName: try values.decode(String.self, forKey: .trackName),
                  artistName: try values.decode(String.self, forKey: .artistName),
                  albumName: try values.decodeIfPresent(String.self, forKey: .albumName),
                  duration: try values.decodeIfPresent(Double.self, forKey: .duration),
                  syncedLyrics: try values.decodeIfPresent(String.self, forKey: .syncedLyrics),
                  plainLyrics: try values.decodeIfPresent(String.self, forKey: .plainLyrics),
                  instrumental: try values.decode(Bool.self, forKey: .instrumental))
    }

    init(id: String, source: String, trackName: String, artistName: String, albumName: String?,
         duration: Double?, syncedLyrics: String?, plainLyrics: String?, instrumental: Bool = false) {
        self.id = id; self.source = source; self.trackName = trackName; self.artistName = artistName
        self.albumName = albumName; self.duration = duration; self.syncedLyrics = syncedLyrics
        self.plainLyrics = plainLyrics; self.instrumental = instrumental
    }

    var usableLyrics: String? {
        let synced = syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines)
        if synced?.isEmpty == false { return synced }
        let plain = plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines)
        return plain?.isEmpty == false ? plain : nil
    }

    var hasTimeline: Bool { syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }

    func score(title: String, artist: String, duration expectedDuration: Double) -> Int {
        var result = 0
        if ChineseLyricsScript.simplified(trackName).compare(ChineseLyricsScript.simplified(title), options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame { result += 100 }
        if ChineseLyricsScript.simplified(artistName).compare(ChineseLyricsScript.simplified(artist), options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame { result += 60 }
        if let duration {
            let difference = abs(duration - expectedDuration)
            if difference <= 3 { result += 40 }
            else if difference <= 10 { result += 10 }
            else if difference > 30 { result -= 80 }
        }
        if hasTimeline { result += 80 }
        return result
    }
}

enum OnlineLyricsSearch {
    static func search(title: String, artist: String, duration: Double) async throws -> [OnlineLyricsResult] {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return [] }
        var queries = [[URLQueryItem(name: "q", value: cleanedTitle)]]
        let traditionalTitle = ChineseLyricsScript.traditional(cleanedTitle)
        if traditionalTitle != cleanedTitle {
            queries.append([URLQueryItem(name: "q", value: traditionalTitle)])
        }
        if !cleanedArtist.isEmpty {
            queries.append([
                URLQueryItem(name: "track_name", value: cleanedTitle),
                URLQueryItem(name: "artist_name", value: cleanedArtist)
            ])
        }
        let canUseOVH = !cleanedArtist.isEmpty && !(cleanedTitle + cleanedArtist).unicodeScalars.contains {
            (0x3400...0x9FFF).contains($0.value)
        }
        let responses = await withTaskGroup(of: [OnlineLyricsResult]?.self, returning: [[OnlineLyricsResult]].self) { group in
            for query in queries {
                group.addTask { try? await fetchLRCLIB(query) }
            }
            group.addTask { try? await fetchLrcAPI(title: cleanedTitle, artist: cleanedArtist) }
            if canUseOVH { group.addTask { try? await fetchLyricsOVH(title: cleanedTitle, artist: cleanedArtist) } }
            var successful: [[OnlineLyricsResult]] = []
            for await response in group {
                if let response { successful.append(response) }
            }
            return successful
        }
        guard !responses.isEmpty else { throw URLError(.cannotLoadFromNetwork) }
        var byID: [String: OnlineLyricsResult] = [:]
        for item in responses.flatMap({ $0 }) where !item.instrumental && item.usableLyrics != nil {
            byID[item.id] = item
        }
        let ranked = byID.values.sorted {
            let left = $0.score(title: cleanedTitle, artist: cleanedArtist, duration: duration)
            let right = $1.score(title: cleanedTitle, artist: cleanedArtist, duration: duration)
            return left == right ? $0.id < $1.id : left > right
        }
        var seenLyrics: Set<String> = []
        return ranked.filter { item in
            guard let lyrics = item.usableLyrics else { return false }
            let key = ChineseLyricsScript.simplified(lyrics).replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            return seenLyrics.insert(key).inserted
        }
    }

    private static func fetchLRCLIB(_ query: [URLQueryItem]) async throws -> [OnlineLyricsResult] {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = query
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        request.setValue("MiniVoice/1.0 (macOS lyrics search)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([OnlineLyricsResult].self, from: data)
    }

    static func parseLrcAPI(_ data: Data) throws -> [OnlineLyricsResult] {
        try JSONDecoder().decode([LrcAPIEntry].self, from: data).compactMap { item in
            guard let lyrics = item.lrc?.trimmingCharacters(in: .whitespacesAndNewlines), !lyrics.isEmpty else { return nil }
            let timed = LRCParser.parse(lyrics, placeholder: false).contains { $0.timestamp != nil }
            return OnlineLyricsResult(id: "lrcapi:\(item.id)", source: "LrcAPI", trackName: item.title,
                                      artistName: item.artist, albumName: item.album, duration: nil,
                                      syncedLyrics: timed ? lyrics : nil, plainLyrics: timed ? nil : lyrics)
        }
    }

    private static func fetchLrcAPI(title: String, artist: String) async throws -> [OnlineLyricsResult] {
        var components = URLComponents(string: "https://api.lrc.cx/jsonapi")!
        components.queryItems = [URLQueryItem(name: "title", value: title), URLQueryItem(name: "artist", value: artist)]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 18
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try parseLrcAPI(data)
    }

    private static func fetchLyricsOVH(title: String, artist: String) async throws -> [OnlineLyricsResult] {
        let url = URL(string: "https://api.lyrics.ovh/v1")!.appendingPathComponent(artist).appendingPathComponent(title)
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if response.statusCode == 404 { return [] }
        guard response.statusCode == 200, data.count < 1_000_000 else { throw URLError(.badServerResponse) }
        let payload = try JSONDecoder().decode(LyricsOVHResponse.self, from: data)
        guard !payload.lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return [OnlineLyricsResult(id: "lyricsovh:\(artist):\(title)", source: "lyrics.ovh", trackName: title,
                                   artistName: artist, albumName: nil, duration: nil,
                                   syncedLyrics: nil, plainLyrics: payload.lyrics)]
    }
}

private struct LrcAPIEntry: Decodable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let lrc: String?
}

private struct LyricsOVHResponse: Decodable { let lyrics: String }
