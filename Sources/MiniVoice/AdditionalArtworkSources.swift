import Foundation

enum AdditionalArtworkSources {
    static func qq(term: String, hasAlbum: Bool) async throws -> [OnlineArtworkResult] {
        let data = try await OnlineArtworkSearch.fetch("https://c.y.qq.com/soso/fcgi-bin/client_search_cp", query: [
            URLQueryItem(name: "w", value: term), URLQueryItem(name: "p", value: "1"),
            URLQueryItem(name: "n", value: "15"), URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "t", value: hasAlbum ? "8" : "0")
        ])
        return try parseQQ(data)
    }

    static func parseQQ(_ data: Data) throws -> [OnlineArtworkResult] {
        let payload = try JSONDecoder().decode(QQResponse.self, from: data)
        guard payload.code == 0 else { throw URLError(.badServerResponse) }
        let rows = (payload.data?.album?.list ?? []) + (payload.data?.song?.list ?? [])
        return rows.compactMap { row in
            guard let mid = row.albumMID ?? row.albummid,
                  mid.range(of: #"^[A-Za-z0-9]{1,64}$"#, options: .regularExpression) != nil else { return nil }
            let rawURL = row.albumPic ?? "https://y.gtimg.cn/music/photo_new/T002R180x180M000\(mid).jpg"
            guard let thumbnail = OnlineArtworkSearch.trustedImageURL(rawURL), thumbnail.host == "y.gtimg.cn" else { return nil }
            // T002M000 is the original image; R800x800 would cap large originals.
            let original = thumbnail.absoluteString.replacingOccurrences(of: #"T002R\d+x\d+M000"#, with: "T002M000", options: .regularExpression)
            guard let imageURL = URL(string: original), original != thumbnail.absoluteString else { return nil }
            let artist = row.singerName ?? row.singer?.map(\.name).joined(separator: " / ") ?? ""
            return OnlineArtworkResult(id: "qq:\(mid)", source: "QQ 音乐", album: row.albumName ?? row.albumname ?? "",
                                       artist: artist, thumbnailURL: thumbnail, imageURL: imageURL)
        }
    }

    static func kugou(term: String, hasAlbum: Bool) async throws -> [OnlineArtworkResult] {
        if hasAlbum { return try await kugouAlbums(term: term) }
        // Song search supplies the album name when the local file has no album tag.
        let data = try await OnlineArtworkSearch.fetch("https://songsearch.kugou.com/song_search_v2", query: [
            URLQueryItem(name: "keyword", value: term), URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pagesize", value: "3")
        ])
        let payload = try JSONDecoder().decode(KugouSongResponse.self, from: data)
        guard payload.status == 1 else { throw URLError(.badServerResponse) }
        var seen: Set<String> = []
        let queries = (payload.data?.lists ?? []).compactMap { row -> String? in
            guard let album = row.AlbumName, !album.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let query = [album, row.SingerName ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
            return seen.insert(query).inserted ? query : nil
        }
        return await withTaskGroup(of: [OnlineArtworkResult].self) { group in
            for query in queries { group.addTask { (try? await kugouAlbums(term: query)) ?? [] } }
            var results: [OnlineArtworkResult] = []
            for await response in group { results += response }
            return results
        }
    }

    private static func kugouAlbums(term: String) async throws -> [OnlineArtworkResult] {
        try parseKugou(await OnlineArtworkSearch.fetch("https://albumsearch.kugou.com/album_search", query: [
            URLQueryItem(name: "keyword", value: term), URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pagesize", value: "15")
        ]))
    }

    static func parseKugou(_ data: Data) throws -> [OnlineArtworkResult] {
        let payload = try JSONDecoder().decode(KugouResponse.self, from: data)
        guard payload.status == 1 else { throw URLError(.badServerResponse) }
        return (payload.data?.lists ?? []).compactMap { row in
            guard let thumbnail = OnlineArtworkSearch.trustedImageURL(row.img), thumbnail.host == "imge.kugou.com" else { return nil }
            let original = thumbnail.absoluteString.replacingOccurrences(of: #"/stdmusic/\d+/"#, with: "/stdmusic/0/", options: .regularExpression)
            guard let imageURL = URL(string: original) else { return nil }
            return OnlineArtworkResult(id: "kugou:\(row.albumid)", source: "酷狗音乐", album: row.albumname,
                                       artist: row.singer ?? "", thumbnailURL: thumbnail, imageURL: imageURL)
        }
    }

    private struct QQResponse: Decodable { let code: Int; let data: QQData? }
    private struct QQData: Decodable { let album: QQRows?; let song: QQRows? }
    private struct QQRows: Decodable { let list: [QQRow]? }
    private struct QQRow: Decodable {
        let albumMID: String?; let albummid: String?
        let albumName: String?; let albumname: String?
        let albumPic: String?; let singerName: String?; let singer: [Singer]?
        struct Singer: Decodable { let name: String }
    }
    private struct KugouResponse: Decodable { let status: Int; let data: KugouData? }
    private struct KugouData: Decodable { let lists: [KugouAlbum]? }
    private struct KugouAlbum: Decodable { let albumid: Int; let albumname: String; let singer: String?; let img: String? }
    private struct KugouSongResponse: Decodable { let status: Int; let data: KugouSongData? }
    private struct KugouSongData: Decodable { let lists: [KugouSong]? }
    private struct KugouSong: Decodable { let AlbumName: String?; let SingerName: String? }
}
