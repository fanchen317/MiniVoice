import Foundation

/// Clean imported text without changing words or existing timing anchors.
enum LyricsText {
    static func normalized(_ source: String) -> String {
        LRCParser.imported(source).replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .flatMap { line -> [String] in
                // Keep timed lines, metadata and credits intact. Their timing cannot be guessed.
                guard !line.hasPrefix("["), !line.contains("："), !line.contains(":") else { return [line] }
                let hasCJK = line.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) }
                let limit = hasCJK ? 18 : 58
                guard line.count > limit else { return [line] }
                // Prefer phrase boundaries, retaining all punctuation and words.
                let pattern = hasCJK ? #"(?<=[，。！？；、,!?;])|\s+"# : #"(?<=[.!?;])\s+|\s+"#
                let regex = try! NSRegularExpression(pattern: pattern)
                let marked = regex.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "\n")
                let phrases = marked.components(separatedBy: "\n").filter { !$0.isEmpty }
                var output: [String] = [], current = ""
                for phrase in phrases {
                    let separator = current.isEmpty ? "" : " "
                    if !current.isEmpty && current.count + separator.count + phrase.count > limit {
                        output.append(current); current = phrase
                    } else { current += separator + phrase }
                }
                if !current.isEmpty { output.append(current) }
                return output
            }.joined(separator: "\n")
    }
}
