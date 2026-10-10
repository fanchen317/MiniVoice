import Foundation

/// A standard LRC metadata row keeps the bilingual document together in tags
/// or a sidecar file, while other LRC readers can ignore the extra metadata.
enum LyricsTranslation {
    private static let tag = try! NSRegularExpression(pattern: #"(?m)^\s*\[translation:([A-Za-z0-9+/=]+)\]\s*$"#)

    static func text(in source: String) -> String? {
        guard let match = tag.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let range = Range(match.range(at: 1), in: source), source[range].utf8.count <= 1_400_000,
              let data = Data(base64Encoded: String(source[range])), let text = String(data: data, encoding: .utf8) else { return nil }
        return text.isEmpty ? nil : text
    }

    static func original(_ source: String) -> String {
        tag.stringByReplacingMatches(in: source, range: NSRange(source.startIndex..., in: source), withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func attaching(_ translation: String?, to source: String) -> String {
        let original = original(source)
        guard let translation, !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return original }
        return "[translation:\(Data(self.original(translation).utf8).base64EncodedString())]\n\(original)"
    }

    static func apply(to lines: [LyricLine], source: String, offset: Double) -> [LyricLine] {
        guard let text = text(in: source) else { return lines }
        let translated = LRCParser.parse(original(text), placeholder: false)
        var result = lines
        let timed = lines.indices.filter { lines[$0].timestamp != nil }
        if timed.isEmpty {
            if translated.count == lines.count {
                for index in lines.indices { result[index].translation = translated[index].text }
            }
            return result
        }
        for row in translated where !row.text.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let time = row.timestamp.map({ $0 + offset }) else { continue }
            let nearest = timed.min { abs(lines[$0].timestamp! - time) < abs(lines[$1].timestamp! - time) }
            let index: Int?
            if let nearest, abs(lines[nearest].timestamp! - time) <= 0.75 { index = nearest }
            else { index = timed.last { lines[$0].timestamp! <= time } }
            guard let index else { continue }
            let existing = result[index].translation
            if existing?.components(separatedBy: "\n").contains(row.text) != true {
                result[index].translation = [existing, row.text].compactMap { $0 }.joined(separator: "\n")
            }
        }
        return result
    }

    static func fromKRC(_ source: String) -> String? {
        guard let row = source.components(separatedBy: .newlines).first(where: { $0.hasPrefix("[language:") && $0.hasSuffix("]") }),
              let data = Data(base64Encoded: String(row.dropFirst(10).dropLast())),
              let file = try? JSONDecoder().decode(KRCLanguage.self, from: data),
              let translations = file.content.first(where: { $0.type == 1 })?.lyricContent else { return nil }
        let timed = LyricsTiming.krc(source).replacingOccurrences(of: #"(?m)^\[offset:[+-]?\d+\]\s*"#, with: "", options: .regularExpression)
        let lines = LRCParser.parse(timed, placeholder: false)
        guard translations.count == lines.count else { return nil }
        let rows = zip(lines, translations).compactMap { line, translation -> String? in
            let text = translation.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, let time = line.timestamp else { return nil }
            return LRCParser.stamp(time, text: text)
        }
        return rows.isEmpty ? nil : rows.joined(separator: "\n")
    }

    private struct KRCLanguage: Decodable {
        let content: [Entry]
        struct Entry: Decodable { let type: Int; let lyricContent: [[String]] }
    }
}
