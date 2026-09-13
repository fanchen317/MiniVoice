import Foundation

enum LRCParser {
    static func parse(_ source: String) -> [LyricLine] {
        let timestamp = try! NSRegularExpression(pattern: #"\[(\d+):(\d{2}(?:\.\d{1,3})?)\]"#)
        let offsetPattern = try! NSRegularExpression(pattern: #"(?im)^\s*\[offset:([+-]?\d+)\]\s*$"#)
        var offset: Double = 0
        if let match = offsetPattern.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
           let range = Range(match.range(at: 1), in: source) { offset = (Double(source[range]) ?? 0) / 1000 }
        var parsed: [LyricLine] = []
        for raw in source.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
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
        return parsed.isEmpty ? [LyricLine(timestamp: nil, text: "尚未添加歌词")] : parsed
    }

    static func timestamped(_ plainText: String, every seconds: TimeInterval = 4) -> String {
        plainText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.enumerated().map { index, text in
                let point = Double(index) * seconds
                return String(format: "[%02d:%05.2f] %@", Int(point / 60), point.truncatingRemainder(dividingBy: 60), text)
            }.joined(separator: "\n")
    }
}
