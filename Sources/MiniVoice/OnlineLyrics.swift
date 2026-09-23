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
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Double?
    let syncedLyrics: String?
    let plainLyrics: String?
    let instrumental: Bool

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
        let responses = await withTaskGroup(of: [OnlineLyricsResult]?.self, returning: [[OnlineLyricsResult]].self) { group in
            for query in queries {
                group.addTask { try? await fetch(query) }
            }
            var successful: [[OnlineLyricsResult]] = []
            for await response in group {
                if let response { successful.append(response) }
            }
            return successful
        }
        guard !responses.isEmpty else { throw URLError(.cannotLoadFromNetwork) }
        var byID: [Int: OnlineLyricsResult] = [:]
        for item in responses.flatMap({ $0 }) where !item.instrumental && item.usableLyrics != nil {
            byID[item.id] = item
        }
        return byID.values.sorted {
            let left = $0.score(title: cleanedTitle, artist: cleanedArtist, duration: duration)
            let right = $1.score(title: cleanedTitle, artist: cleanedArtist, duration: duration)
            return left == right ? $0.id < $1.id : left > right
        }
    }

    private static func fetch(_ query: [URLQueryItem]) async throws -> [OnlineLyricsResult] {
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
}
