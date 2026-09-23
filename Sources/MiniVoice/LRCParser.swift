import Foundation

enum LRCParser {
    static func parse(_ source: String, placeholder: Bool = true) -> [LyricLine] {
        let timestamp = try! NSRegularExpression(pattern: #"\[(\d+):(\d{2}(?:\.\d{1,3})?)\]"#)
        let offsetPattern = try! NSRegularExpression(pattern: #"(?im)^\s*\[offset:([+-]?\d+)\]\s*$"#)
        var offset: Double = 0
        if let match = offsetPattern.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
           let range = Range(match.range(at: 1), in: source) { offset = (Double(source[range]) ?? 0) / 1000 }
        var parsed: [LyricLine] = []
        for raw in source.components(separatedBy: .newlines) {
            let line = raw.replacingOccurrences(of: #"<\d+:\d{2}(?:\.\d{1,3})?>"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            let matches = timestamp.matches(in: line, range: NSRange(line.startIndex..., in: line))
            if matches.isEmpty {
                if line.range(of: #"^\[[A-Za-z]+:.*\]$"#, options: .regularExpression) == nil {
                    parsed.append(LyricLine(timestamp: nil, text: line))
                }
                continue
            }
            let text = timestamp.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "").trimmingCharacters(in: .whitespaces)
            for match in matches {
                guard let m = Range(match.range(at: 1), in: line), let s = Range(match.range(at: 2), in: line),
                      let minutes = Double(line[m]), let seconds = Double(line[s]), seconds < 60 else { continue }
                parsed.append(LyricLine(timestamp: max(0, minutes * 60 + seconds + offset), text: text))
            }
        }
        if !parsed.isEmpty && parsed.allSatisfy({ $0.timestamp != nil }) {
            parsed = parsed.enumerated().sorted {
                let a = $0.element.timestamp!, b = $1.element.timestamp!
                return a == b ? $0.offset < $1.offset : a < b
            }.map(\.element)
        }
        return parsed.isEmpty && placeholder ? [LyricLine(timestamp: nil, text: "尚未添加歌词")] : parsed
    }

    static func stamp(_ time: TimeInterval, text: String) -> String {
        let ticks = Int((max(0, time.isFinite ? time : 0) * 100).rounded())
        return String(format: "[%02d:%02d.%02d] %@", ticks / 6000, (ticks / 100) % 60, ticks % 100, text)
    }

    /// Shift every LRC timing mark while preserving metadata and lyric text.
    /// Existing [offset:] metadata is folded into the timestamps so the result
    /// also behaves consistently in players that ignore that tag.
    static func shifted(_ source: String, by seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return source }
        let offsetPattern = try! NSRegularExpression(pattern: #"(?im)^\s*\[offset:([+-]?\d+)\]\s*\n?"#)
        let offset: Double
        if let match = offsetPattern.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
           let range = Range(match.range(at: 1), in: source) {
            offset = (Double(source[range]) ?? 0) / 1000
        } else { offset = 0 }
        let withoutOffset = offsetPattern.stringByReplacingMatches(in: source, range: NSRange(source.startIndex..., in: source), withTemplate: "")
        let pattern = try! NSRegularExpression(pattern: #"([\[<])(\d+):(\d{2}(?:\.\d{1,3})?)([\]>])"#)
        let matches = pattern.matches(in: withoutOffset, range: NSRange(withoutOffset.startIndex..., in: withoutOffset))
        guard !matches.isEmpty else { return source }
        var result = withoutOffset
        for match in matches.reversed() {
            guard let full = Range(match.range, in: result),
                  let minuteRange = Range(match.range(at: 2), in: result),
                  let secondRange = Range(match.range(at: 3), in: result),
                  let minutes = Double(result[minuteRange]),
                  let remaining = Double(result[secondRange]), remaining < 60 else { continue }
            let adjusted = max(0, minutes * 60 + remaining + offset + seconds)
            let ticks = Int((adjusted * 100).rounded())
            let opening = (result as NSString).substring(with: match.range(at: 1))
            let closing = (result as NSString).substring(with: match.range(at: 4))
            result.replaceSubrange(full, with: String(format: "%@%02d:%02d.%02d%@", opening, ticks / 6000, (ticks / 100) % 60, ticks % 100, closing))
        }
        return result
    }

    /// Converts common SRT subtitles to timed lyrics, leaving LRC/plain text intact.
    static func imported(_ source: String) -> String {
        let normalized = source.replacingOccurrences(of: "\u{FEFF}", with: "").replacingOccurrences(of: "\r\n", with: "\n")
        let expression = try! NSRegularExpression(pattern: #"(?m)^(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->.*$"#)
        guard expression.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil else { return normalized }
        return normalized.components(separatedBy: "\n\n").compactMap { block in
            let lines = block.components(separatedBy: "\n")
            guard let index = lines.firstIndex(where: { $0.contains("-->") }),
                  let match = expression.firstMatch(in: lines[index], range: NSRange(lines[index].startIndex..., in: lines[index])) else { return nil }
            let values = (1...4).map { Double((lines[index] as NSString).substring(with: match.range(at: $0))) ?? 0 }
            let time = values[0] * 3600 + values[1] * 60 + values[2] + values[3] / 1000
            return stamp(time, text: lines.dropFirst(index + 1).joined(separator: " / "))
        }.joined(separator: "\n")
    }

    static func timestamped(_ plainText: String, every seconds: TimeInterval = 4) -> String {
        plainText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.enumerated().map { index, text in
                let point = Double(index) * seconds
                return String(format: "[%02d:%05.2f] %@", Int(point / 60), point.truncatingRemainder(dividingBy: 60), text)
            }.joined(separator: "\n")
    }
}
