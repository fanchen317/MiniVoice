import Foundation
import SwiftUI
import Yams

struct LyricWord: Equatable {
    var text: String
    var start: TimeInterval
    var end: TimeInterval?
}

enum LyricTimingKind: Int {
    case plain, line, word
    var title: String {
        switch self {
        case .plain: "普通文本"
        case .line: "逐行"
        case .word: "逐字"
        }
    }
    static func detect(_ lines: [LyricLine]) -> Self {
        if lines.contains(where: { !$0.words.isEmpty }) { return .word }
        return lines.contains(where: { $0.timestamp != nil }) ? .line : .plain
    }
}

enum LyricsTiming {
    static func krc(_ source: String) -> String {
        let wordsPattern = try! NSRegularExpression(pattern: #"<(\d+),(\d+),\d+>"#)
        var rows: [String] = []
        for raw in source.components(separatedBy: .newlines) {
            let ns = raw as NSString
            guard let header = durationLine.firstMatch(in: raw, range: NSRange(location: 0, length: ns.length)) else {
                if !raw.hasPrefix("[language:") { rows.append(raw) }
                continue
            }
            let start = (Double(ns.substring(with: header.range(at: 1))) ?? 0) / 1000
            let end = start + (Double(ns.substring(with: header.range(at: 2))) ?? 0) / 1000
            let body = ns.substring(from: NSMaxRange(header.range))
            let bodyNS = body as NSString
            let matches = wordsPattern.matches(in: body, range: NSRange(location: 0, length: bodyNS.length))
            let text = wordsPattern.stringByReplacingMatches(in: body, range: NSRange(location: 0, length: bodyNS.length), withTemplate: "")
            let words = matches.enumerated().map { index, match -> LyricWord in
                let lower = NSMaxRange(match.range)
                let upper = index + 1 < matches.count ? matches[index + 1].range.location : bodyNS.length
                let wordStart = start + (Double(bodyNS.substring(with: match.range(at: 1))) ?? 0) / 1000
                return LyricWord(text: bodyNS.substring(with: NSRange(location: lower, length: upper - lower)), start: wordStart,
                                 end: wordStart + (Double(bodyNS.substring(with: match.range(at: 2))) ?? 0) / 1000)
            }
            rows.append(encoded([LyricLine(timestamp: start, text: text, endTime: end,
                                          words: validated(words, text: text, start: start, end: end))]))
        }
        return rows.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let markers = try! NSRegularExpression(pattern: #"<(\d+):(\d{2}(?:\.\d{1,3})?)>"#)
    private static let durationLine = try! NSRegularExpression(pattern: #"^\[(\d+),(\d+)\]"#)
    private static let durationWord = try! NSRegularExpression(pattern: #"\((\d+),(\d+),\d+\)"#)

    static func validated(_ words: [LyricWord], text: String, start: Double?, end: Double?) -> [LyricWord] {
        guard let start, !words.isEmpty, words.map(\.text).joined() == text else { return [] }
        var previous = start
        for word in words {
            guard word.start.isFinite, word.start >= previous, word.start >= start,
                  word.end.map({ $0.isFinite && $0 >= word.start }) ?? true,
                  end.map({ word.start <= $0 && (word.end ?? word.start) <= $0 }) ?? true else { return [] }
            previous = word.start
        }
        return words
    }

    /// Enhanced LRC: a marker precedes each timed segment; empty terminal markers
    /// retain its end time. Untimed prefixes or invalid ordering fall back to line sync.
    static func enhanced(_ source: String, offset: Double) -> (text: String, words: [LyricWord], end: Double?) {
        let matches = markers.matches(in: source, range: NSRange(source.startIndex..., in: source))
        guard let first = matches.first else { return (source.trimmingCharacters(in: .whitespaces), [], nil) }
        let ns = source as NSString
        let prefix = ns.substring(to: first.range.location)
        var words: [LyricWord] = []
        var terminal: Double?
        for (index, match) in matches.enumerated() {
            let minute = Double(ns.substring(with: match.range(at: 1))) ?? 0
            let seconds = Double(ns.substring(with: match.range(at: 2))) ?? 60
            let start = max(0, minute * 60 + seconds + offset)
            let lower = NSMaxRange(match.range)
            let upper = index + 1 < matches.count ? matches[index + 1].range.location : ns.length
            let text = ns.substring(with: NSRange(location: lower, length: upper - lower))
            if text.isEmpty {
                if !words.isEmpty { words[words.count - 1].end = start }
                terminal = start
            } else {
                words.append(LyricWord(text: text, start: seconds < 60 ? start : .nan, end: nil))
                terminal = nil
            }
        }
        let text = (prefix + words.map(\.text).joined()).trimmingCharacters(in: .whitespaces)
        if !prefix.trimmingCharacters(in: .whitespaces).isEmpty { return (text, [], terminal) }
        // Remove outer whitespace in the same way as the line text, preserving internal spaces.
        if !words.isEmpty {
            words[0].text = words[0].text.replacingOccurrences(of: #"^\s+"#, with: "", options: .regularExpression)
            words[words.count - 1].text = words[words.count - 1].text.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
        }
        for index in words.indices.dropLast() where words[index].end == nil {
            words[index].end = words[index + 1].start
        }
        return (text, words.filter { !$0.text.isEmpty }, terminal)
    }

    static func yrcLine(_ source: String, offset: Double) -> LyricLine? {
        let ns = source as NSString
        guard let header = durationLine.firstMatch(in: source, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let start = (Double(ns.substring(with: header.range(at: 1))) ?? 0) / 1000 + offset
        let end = start + (Double(ns.substring(with: header.range(at: 2))) ?? 0) / 1000
        let body = ns.substring(from: NSMaxRange(header.range))
        let bodyNS = body as NSString
        let matches = durationWord.matches(in: body, range: NSRange(location: 0, length: bodyNS.length))
        var words: [LyricWord] = []
        for (index, match) in matches.enumerated() {
            let lower = NSMaxRange(match.range)
            let upper = index + 1 < matches.count ? matches[index + 1].range.location : bodyNS.length
            let wordStart = (Double(bodyNS.substring(with: match.range(at: 1))) ?? 0) / 1000 + offset
            words.append(LyricWord(text: bodyNS.substring(with: NSRange(location: lower, length: upper - lower)),
                                   start: max(0, wordStart), end: max(0, wordStart + (Double(bodyNS.substring(with: match.range(at: 2))) ?? 0) / 1000)))
        }
        let text = durationWord.stringByReplacingMatches(in: body, range: NSRange(location: 0, length: bodyNS.length), withTemplate: "")
        return LyricLine(timestamp: max(0, start), text: text, endTime: max(0, end),
                         words: validated(words, text: text, start: max(0, start), end: max(0, end)))
    }

    static func encoded(_ lines: [LyricLine]) -> String {
        lines.map { line in
            guard let start = line.timestamp else { return line.text }
            guard !line.words.isEmpty else { return LRCParser.stamp(start, text: line.text) }
            var result = marker(start).replacingOccurrences(of: "<", with: "[").replacingOccurrences(of: ">", with: "]")
            for word in line.words {
                result += marker(word.start) + word.text
                if let end = word.end { result += marker(end) }
            }
            if line.words.last?.end == nil, let end = line.endTime { result += marker(end) }
            return result
        }.joined(separator: "\n")
    }

    private static func marker(_ time: Double) -> String {
        let ms = Int((max(0, time) * 1000).rounded())
        return String(format: "<%02d:%02d.%03d>", ms / 60000, (ms / 1000) % 60, ms % 1000)
    }

    static func lyricsfile(_ source: String) -> String? {
        guard source.utf8.count <= 1_000_000,
              let file = try? YAMLDecoder().decode(LyricsFile.self, from: source), file.version == "1.0" else { return nil }
        let lines = (file.lines ?? []).compactMap { row -> LyricLine? in
            guard let startMS = row.start_ms, startMS >= 0 else { return LyricLine(timestamp: nil, text: row.text) }
            let start = startMS / 1000
            let end = row.end_ms.flatMap { $0 >= startMS ? $0 / 1000 : nil }
            let words = (row.words ?? []).map { LyricWord(text: $0.text, start: ($0.start_ms ?? -1) / 1000, end: $0.end_ms.map { $0 / 1000 }) }
            return LyricLine(timestamp: start, text: row.text, endTime: end,
                             words: validated(words, text: row.text, start: start, end: end))
        }
        if !lines.isEmpty { return encoded(lines) }
        return file.plain?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct LyricsFile: Decodable { let version: String; let lines: [FileLine]?; let plain: String? }
    private struct FileLine: Decodable { let text: String; let start_ms: Double?; let end_ms: Double?; let words: [FileWord]? }
    private struct FileWord: Decodable { let text: String; let start_ms: Double?; let end_ms: Double? }
}

/// A single Text retains native wrapping and font scaling. Only valid timed
/// segments in the active line are colored; unaligned lines retain line highlighting.
struct TimedLyricText: View {
    let line: LyricLine
    let time: Double
    let active: Bool
    let baseColor: Color
    var pendingWordOpacity: Double = 0.72
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let activeColor = Color(red: 0.06, green: 0.66, blue: 0.46)

    var body: some View {
        Text(attributedText)
    }

    private var attributedText: AttributedString {
        guard active else { return AttributedString(line.text.isEmpty ? "•••" : line.text) }
        guard !line.words.isEmpty else {
            var text = AttributedString(line.text.isEmpty ? "•••" : line.text)
            text.foregroundColor = Self.activeColor
            return text
        }
        var result = AttributedString()
        for word in line.words {
            var segment = AttributedString(word.text)
            // Keep the whole current line in the same palette as line-synced
            // lyrics. Real word starts gently bring each segment to full strength.
            let duration = min(0.18, max(0.06, (word.end.map { $0 - word.start } ?? 0.72) * 0.25))
            let progress = reduceMotion ? (time >= word.start ? 1.0 : 0.0) : min(1, max(0, (time - word.start) / duration))
            let opacity = pendingWordOpacity + (1 - pendingWordOpacity) * progress
            segment.foregroundColor = Self.activeColor.opacity(opacity)
            result.append(segment)
        }
        return result
    }
}

struct OnlineLyricsPreview: View {
    let source: String
    @State private var time: Double = 0

    var body: some View {
        let lines = LRCParser.parse(source, placeholder: false)
        let kind = LyricTimingKind.detect(lines)
        let active = MusicLibrary.activeLyricIndex(for: lines, at: time)
        let end = previewEnd(lines)
        VStack(alignment: .leading, spacing: 12) {
            Text("\(kind.title)歌词预览").font(.headline)
            if kind != .plain {
                HStack {
                    Slider(value: $time, in: 0...end).accessibilityLabel("歌词时间轴预览")
                    Text(String(format: "%02d:%05.2f", Int(time / 60), time.truncatingRemainder(dividingBy: 60)))
                        .font(.caption.monospacedDigit()).frame(width: 70)
                }
                Text("拖动时间轴查看高亮；应用后随歌曲播放跟随。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        if kind != .plain {
                                            Text(line.timestamp.map { LRCParser.stamp($0, text: "").trimmingCharacters(in: .whitespaces) } ?? "—")
                                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                .foregroundStyle(Color.primary.opacity(0.75))
                                                .frame(width: 82, alignment: .leading)
                                        }
                                        TimedLyricText(line: line, time: time, active: active == index,
                                                       baseColor: .primary, pendingWordOpacity: 0.85)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(active == index ? Color.accentColor : Color.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    if let translation = line.translation {
                                        Text(translation).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                                            .padding(.leading, kind == .plain ? 0 : 94)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }.id(index)
                            }
                        }.textSelection(.enabled)
                        DisclosureGroup("查看原始时间标签") {
                            Text(LyricsTranslation.original(source))
                                .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }
                    }.padding(.vertical, 8)

                }
                .onChange(of: active) { index in
                    if let index { proxy.scrollTo(index, anchor: .center) }
                }
            }
        }
    }

    private func previewEnd(_ lines: [LyricLine]) -> Double {
        var latest = 1.0
        for line in lines {
            latest = max(latest, line.timestamp ?? 0, line.endTime ?? 0)
            for word in line.words { latest = max(latest, word.start, word.end ?? word.start) }
        }
        return latest + 3
    }
}
