import Foundation

enum PlaybackMode: String, CaseIterable, Identifiable {
    case single, list, shuffle, repeatOne, repeatAll
    var id: String { rawValue }
    var title: String {
        switch self {
        case .single: return "单曲播放"
        case .list: return "列表播放"
        case .shuffle: return "随机播放"
        case .repeatOne: return "单曲循环"
        case .repeatAll: return "列表循环"
        }
    }
    var explanation: String {
        switch self {
        case .single: return "当前歌曲播完停止。"
        case .list: return "按开始播放时的列表顺序播放，最后一首播完停止。"
        case .shuffle: return "在开始播放时的列表内随机播放，一轮内不重复；上一曲返回实际播放历史。"
        case .repeatOne: return "当前歌曲循环播放。"
        case .repeatAll: return "按开始播放时的列表顺序循环，最后一首后回到第一首。"
        }
    }
    var symbolName: String {
        switch self {
        case .single: return "play.circle"
        case .list: return "text.line.first.and.arrowtriangle.forward"
        case .shuffle: return "shuffle"
        case .repeatOne: return "repeat.1"
        case .repeatAll: return "repeat"
        }
    }
}

struct PlaybackQueue {
    private var history: [UUID] = []
    private var cursor = -1
    private var remaining: [UUID] = []

    mutating func reset(current: UUID?, ids: [UUID]) {
        history = current.map { [$0] } ?? []; cursor = history.count - 1
        remaining = ids.filter { $0 != current }.shuffled()
    }

    mutating func destination(current: UUID?, ids: [UUID], mode: PlaybackMode, direction: Int = 1, automatic: Bool = false) -> UUID? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else { return ids.first }
        if automatic && mode == .single { return nil }
        if automatic && mode == .repeatOne { return current }
        if mode == .shuffle {
            if direction < 0 {
                guard cursor > 0 else { return current }
                cursor -= 1; return history[cursor]
            }
            if cursor + 1 < history.count { cursor += 1; return history[cursor] }
            remaining.removeAll { !ids.contains($0) || $0 == current }
            if remaining.isEmpty { remaining = ids.filter { $0 != current }.shuffled() }
            let next = remaining.popLast() ?? current
            history.append(next); cursor = history.count - 1
            return next
        }
        let next = index + (direction < 0 ? -1 : 1)
        if automatic && mode == .list && next == ids.count { return nil }
        return ids[(next + ids.count) % ids.count]
    }
}
