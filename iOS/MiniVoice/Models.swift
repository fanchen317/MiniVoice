import Foundation

struct Song: Codable, Identifiable, Hashable {
    let id: String
    let folderID: String
    let relativePath: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artworkFile: String?
    let lyrics: String?

    static func == (lhs: Song, rhs: Song) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct MusicFolder: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let bookmark: Data
}

struct MusicPlaylist: Codable, Identifiable {
    let id: UUID
    var name: String
    var songIDs: [String]
}

enum PlaybackMode: Int, CaseIterable, Identifiable {
    case single, sequential, shuffle, repeatOne, repeatAll
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .single: return "单曲播放"
        case .sequential: return "列表播放"
        case .shuffle: return "随机播放"
        case .repeatOne: return "单曲循环"
        case .repeatAll: return "列表循环"
        }
    }
    var detail: String {
        switch self {
        case .single: return "当前歌曲结束后停止"
        case .sequential: return "按顺序播放，到列表末尾停止"
        case .shuffle: return "随机播放队列中的歌曲"
        case .repeatOne: return "重复播放当前歌曲"
        case .repeatAll: return "顺序播放并循环整个列表"
        }
    }
    var symbol: String {
        switch self {
        case .single: return "stop.circle"
        case .sequential: return "arrow.right"
        case .shuffle: return "shuffle"
        case .repeatOne: return "repeat.1"
        case .repeatAll: return "repeat"
        }
    }
}

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: TimeInterval
    let text: String
}

enum LRCParser {
    static func parse(_ source: String?) -> [LyricLine] {
        guard let source, !source.isEmpty else { return [] }
        let pattern = #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
        let wordPattern = #"<(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?>"#
        guard let stamp = try? NSRegularExpression(pattern: pattern),
              let word = try? NSRegularExpression(pattern: wordPattern) else { return [] }
        let offsetPattern = try? NSRegularExpression(pattern: #"(?im)^\s*\[offset:([+-]?\d{1,9})\]\s*$"#)
        let full = source as NSString
        let offsetMatch = offsetPattern?.firstMatch(in: source, range: NSRange(location: 0, length: full.length))
        let offset = offsetMatch.flatMap { Int(full.substring(with: $0.range(at: 1))) } ?? 0
        var timed: [(TimeInterval, String)] = []
        var plain: [String] = []
        for row in source.replacingOccurrences(of: "\u{FEFF}", with: "").components(separatedBy: .newlines) {
            let ns = row as NSString
            let range = NSRange(location: 0, length: ns.length)
            let matches = stamp.matches(in: row, range: range)
            let withoutStamps = stamp.stringByReplacingMatches(in: row, range: range, withTemplate: "")
            let body = word.stringByReplacingMatches(in: withoutStamps, range: NSRange(location: 0, length: (withoutStamps as NSString).length), withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            let effective = matches.isEmpty ? word.matches(in: row, range: range).prefix(1).map { $0 } : matches
            if effective.isEmpty {
                if !row.trimmingCharacters(in: .whitespaces).hasPrefix("[") { plain.append(body) }
                continue
            }
            for match in effective {
                let minute = Int(ns.substring(with: match.range(at: 1))) ?? 0
                let second = Int(ns.substring(with: match.range(at: 2))) ?? 0
                guard second < 60 else { continue }
                let fraction = match.range(at: 3).location == NSNotFound ? "" : ns.substring(with: match.range(at: 3))
                let millisecond = Int(String((fraction + "000").prefix(3))) ?? 0
                let time = max(0, Double(minute * 60_000 + second * 1000 + millisecond + offset) / 1000)
                timed.append((time, body))
            }
        }
        if timed.isEmpty { return plain.enumerated().map { LyricLine(id: $0.offset, time: -1, text: $0.element) } }
        return timed.sorted { $0.0 < $1.0 }.enumerated().map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }
}
