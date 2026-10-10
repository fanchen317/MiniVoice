import Foundation
import ImageIO

struct OnlineArtworkResult: Identifiable, Sendable {
    let id: String
    let source: String
    let album: String
    let artist: String
    let thumbnailURL: URL
    let imageURL: URL

    func score(album expectedAlbum: String, artist expectedArtist: String) -> Int {
        func matches(_ a: String, _ b: String) -> Bool {
            !b.isEmpty && ChineseLyricsScript.simplified(a).compare(ChineseLyricsScript.simplified(b), options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        return (matches(album, expectedAlbum) ? 100 : 0) + (matches(artist, expectedArtist) ? 60 : 0)
    }
}

struct DownloadedArtwork: Sendable {
    let data: Data
    let width: Int
    let height: Int
}

enum OnlineArtworkSearch {
    static func search(title: String, artist: String, album: String) async throws -> [OnlineArtworkResult] {
        let album = album.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !album.isEmpty || !title.isEmpty else { return [] }
        let term = [album.isEmpty ? title : album, artist].filter { !$0.isEmpty }.joined(separator: " ")
        let responses = await withTaskGroup(of: [OnlineArtworkResult]?.self) { group in
            for country in ["US", "CN"] {
                group.addTask {
                    try? parseApple(await fetch("https://itunes.apple.com/search", query: [
                        URLQueryItem(name: "term", value: term), URLQueryItem(name: "entity", value: album.isEmpty ? "musicTrack" : "album"),
                        URLQueryItem(name: "country", value: country), URLQueryItem(name: "limit", value: "15")
                    ]))
                }
            }
            group.addTask {
                try? parseNetEase(await fetch("https://music.163.com/api/search/get/web", query: [
                    URLQueryItem(name: "s", value: term), URLQueryItem(name: "type", value: album.isEmpty ? "1" : "10"),
                    URLQueryItem(name: "limit", value: "15"), URLQueryItem(name: "offset", value: "0")
                ]))
            }
            group.addTask { try? await AdditionalArtworkSources.qq(term: term, hasAlbum: !album.isEmpty) }
            group.addTask { try? await AdditionalArtworkSources.kugou(term: term, hasAlbum: !album.isEmpty) }
            var responses: [[OnlineArtworkResult]] = []
            for await response in group { if let response { responses.append(response) } }
            return responses
        }
        try Task.checkCancellation()
        guard !responses.isEmpty else { throw URLError(.cannotLoadFromNetwork) }
        var seen: Set<String> = []
        return responses.flatMap { $0 }.sorted {
            let lhs = $0.score(album: album, artist: artist), rhs = $1.score(album: album, artist: artist)
            return lhs == rhs ? $0.id < $1.id : lhs > rhs
        }.filter { seen.insert($0.imageURL.absoluteString).inserted }
    }

    static func parseApple(_ data: Data) throws -> [OnlineArtworkResult] {
        try JSONDecoder().decode(AppleResponse.self, from: data).results.compactMap { row in
            guard let url = trustedImageURL(row.artworkUrl100),
                  let host = url.host, host.hasSuffix(".mzstatic.com") else { return nil }
            let large = url.absoluteString.replacingOccurrences(of: #"/\d+x\d+bb[^/]*$"#, with: "/3000x3000bb.jpg", options: .regularExpression)
            guard large != url.absoluteString, let imageURL = URL(string: large) else { return nil }
            return OnlineArtworkResult(id: "apple:\(row.collectionId):\(imageURL.absoluteString)", source: "Apple Music", album: row.collectionName,
                                       artist: row.artistName, thumbnailURL: url, imageURL: imageURL)
        }
    }

    static func parseNetEase(_ data: Data) throws -> [OnlineArtworkResult] {
        let payload = try JSONDecoder().decode(NetEaseResponse.self, from: data)
        guard payload.code == 200 else { throw URLError(.badServerResponse) }
        let albums = (payload.result?.albums ?? []) + (payload.result?.songs ?? []).compactMap(\.album)
        return albums.compactMap { row in
            guard let url = trustedImageURL(row.picUrl), let host = url.host, host.hasSuffix(".music.126.net") else { return nil }
            var original = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            original.queryItems = nil
            guard let imageURL = original.url else { return nil }
            original.queryItems = [URLQueryItem(name: "param", value: "160y160")]
            return OnlineArtworkResult(id: "netease:\(row.id)", source: "网易云", album: row.name,
                                       artist: row.artists?.map(\.name).joined(separator: " / ") ?? row.artist?.name ?? "",
                                       thumbnailURL: original.url!, imageURL: imageURL)
        }
    }

    static func download(_ item: OnlineArtworkResult) async throws -> DownloadedArtwork {
        let data = try await fetch(item.imageURL.absoluteString, query: [], maxBytes: 25_000_000)
        try Task.checkCancellation()
        return try inspectedImage(data)
    }

    static func inspectedImage(_ data: Data) throws -> DownloadedArtwork {
        guard data.count <= 25_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 10_000, height <= 10_000, width * height <= 40_000_000,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else { throw URLError(.cannotDecodeContentData) }
        return DownloadedArtwork(data: data, width: width, height: height)
    }

    static func trustedImageURL(_ raw: String?) -> URL? {
        guard let raw, var components = URLComponents(string: raw), let host = components.host,
              host.hasSuffix(".mzstatic.com") || host.hasSuffix(".music.126.net") || host == "y.gtimg.cn" || host == "imge.kugou.com",
              components.scheme == "http" || components.scheme == "https" else { return nil }
        components.scheme = "https"
        return components.url
    }

    static func fetch(_ rawURL: String, query: [URLQueryItem], maxBytes: Int = 2_000_000) async throws -> Data {
        var components = URLComponents(string: rawURL)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 18
        if components.host?.hasSuffix("163.com") == true || components.host?.hasSuffix("music.126.net") == true {
            request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        } else if components.host?.hasSuffix("qq.com") == true || components.host == "y.gtimg.cn" {
            request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        } else if components.host?.hasSuffix("kugou.com") == true {
            request.setValue("https://www.kugou.com/", forHTTPHeaderField: "Referer")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, data.count <= maxBytes else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private struct AppleResponse: Decodable { let results: [AppleAlbum] }
    private struct AppleAlbum: Decodable {
        let collectionId: Int
        let collectionName: String
        let artistName: String
        let artworkUrl100: String?
    }
    private struct NetEaseResponse: Decodable { let code: Int; let result: NetEaseResults? }
    private struct NetEaseResults: Decodable { let albums: [NetEaseAlbum]?; let songs: [NetEaseSong]? }
    private struct NetEaseSong: Decodable { let album: NetEaseAlbum? }
    private struct NetEaseAlbum: Decodable {
        let id: Int
        let name: String
        let picUrl: String?
        let artists: [Artist]?
        let artist: Artist?
        struct Artist: Decodable { let name: String }
    }
}
