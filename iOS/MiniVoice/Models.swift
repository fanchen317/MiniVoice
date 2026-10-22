import Foundation
import MiniVoiceShared

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
        guard let source, let lines = try? SharedEngine.parseLyrics(source) else {return []}
        return lines.enumerated().map {LyricLine(id: $0.offset, time: $0.element.ms < 0 ? -1 : Double($0.element.ms) / 1000, text: $0.element.displayText)}
    }
}
