import Foundation

/// Uses the public AMLL API's original TTML; its LrcLib-compatible endpoint
/// exports line timing only, so it must not be used for word-timed results.
enum AMLLLyrics {
    static func search(title: String, artist: String) async throws -> [OnlineLyricsResult] {
        var entries: [Int: Song] = [:]
        for variant in Array(Set([title, ChineseLyricsScript.traditional(title)])).sorted() {
            let data = try await fetch("search", query: [
                URLQueryItem(name: "musicName", value: variant), URLQueryItem(name: "pageSize", value: "12")
            ])
            let page = try JSONDecoder().decode(Response<Page>.self, from: data)
            guard page.status == 200 else { throw URLError(.badServerResponse) }
            for song in page.data.items { entries[song.id] = song }
        }
        let candidates = entries.values.sorted {
            $0.result(text: "", title: title).score(title: title, artist: artist, duration: 0)
                > $1.result(text: "", title: title).score(title: title, artist: artist, duration: 0)
        }.prefix(4)
        return await withTaskGroup(of: OnlineLyricsResult?.self) { group in
            for candidate in candidates {
                group.addTask {
                    guard let data = try? await fetch("get", query: [URLQueryItem(name: "id", value: String(candidate.id))]),
                          let response = try? JSONDecoder().decode(Response<Song>.self, from: data), response.status == 200,
                          let source = response.data.lyrics, let text = try? TTMLLyrics.convert(source), !text.isEmpty else { return nil }
                    return response.data.result(text: text, title: title)
                }
            }
            var results: [OnlineLyricsResult] = []
            for await result in group { if let result { results.append(result) } }
            return results
        }
    }

    private static func fetch(_ path: String, query: [URLQueryItem]) async throws -> Data {
        var url = URLComponents(string: "https://api.amll.dev/v1/lyrics/\(path)")!
        url.queryItems = query
        var request = URLRequest(url: url.url!)
        request.timeoutInterval = 8
        request.setValue("MiniVoice/macOS (lyrics search)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 2_000_000 else { throw URLError(.badServerResponse) }
        return data
    }

    private struct Response<T: Decodable>: Decodable { let status: Int; let data: T }
    private struct Page: Decodable { let items: [Song] }
    private struct Song: Decodable, Sendable {
        let id: Int
        let musicNames: [String]
        let artistNames: [String]
        let albumNames: [String]
        let lyrics: String?
        func result(text: String, title: String) -> OnlineLyricsResult {
            let name = musicNames.first { ChineseLyricsScript.simplified($0).lowercased() == ChineseLyricsScript.simplified(title).lowercased() }
                ?? musicNames.first ?? title
            return OnlineLyricsResult(id: "amll:\(id)", source: "AMLL TTML", trackName: name,
                                      artistName: artistNames.joined(separator: " / "), albumName: albumNames.first,
                                      duration: nil, syncedLyrics: text, plainLyrics: nil)
        }
    }
}

enum TTMLLyrics {
    static func convert(_ source: String) throws -> String {
        guard source.utf8.count <= 2_000_000, !source.localizedCaseInsensitiveContains("<!DOCTYPE"),
              !source.localizedCaseInsensitiveContains("<!ENTITY") else { throw URLError(.cannotDecodeContentData) }
        // XMLDocument stores inter-element whitespace as formatting rather than
        // text nodes. SAX preserves sung spaces between adjacent word spans.
        let document = TTMLDocument()
        let parser = XMLParser(data: Data(source.utf8))
        parser.shouldResolveExternalEntities = false
        parser.delegate = document
        guard parser.parse(), let root = document.root, root.name == "tt" else { throw URLError(.cannotDecodeContentData) }
        var lines: [LyricLine] = []
        var translations: [String] = []
        for paragraph in root.descendants("p") {
            var words: [LyricWord] = []
            var text = ""
            let start = time(paragraph.attribute("begin"))
            let end = time(paragraph.attribute("end"))
            func visit(_ node: TTMLNode, begin: Double?, end: Double?, timed: Bool) {
                if node.name != "#text" {
                    let element = node
                    let role = element.attribute("role") ?? ""
                    if ["x-translation", "x-roman", "x-bg"].contains(role) { return }
                    let ownBegin = time(element.attribute("begin")) ?? begin
                    let ownEnd = time(element.attribute("end"))
                        ?? time(element.attribute("dur")).flatMap { d in ownBegin.map { $0 + d } } ?? end
                    for child in element.children {
                        visit(child, begin: ownBegin, end: ownEnd, timed: timed || element.attribute("begin") != nil)
                    }
                } else {
                    let content = node.value
                    // XML indentation is not a sung segment; retain deliberate inter-word spaces.
                    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && content.contains("\n") { return }
                    text += content
                    if timed, let begin {
                        words.append(LyricWord(text: content, start: begin, end: end))
                    } else if content.trimmingCharacters(in: .whitespaces).isEmpty, !words.isEmpty {
                        words[words.count - 1].text += content
                    }
                }
            }
            for child in paragraph.children { visit(child, begin: start, end: end, timed: false) }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if !words.isEmpty {
                words[0].text = words[0].text.replacingOccurrences(of: #"^\s+"#, with: "", options: .regularExpression)
                words[words.count - 1].text = words[words.count - 1].text.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
            }
            let lineStart = start ?? words.first?.start
            let lineEnd = end ?? words.last?.end
            lines.append(LyricLine(timestamp: lineStart, text: text, endTime: lineEnd,
                                  words: LyricsTiming.validated(words, text: text, start: lineStart, end: lineEnd)))
            if let lineStart {
                for translated in paragraph.descendants("span") {
                    if translated.attribute("role") == "x-translation", !translated.text.isEmpty {
                        translations.append(LRCParser.stamp(lineStart, text: translated.text))
                    }
                }
            }
        }
        return LyricsTranslation.attaching(translations.isEmpty ? nil : translations.joined(separator: "\n"), to: LyricsTiming.encoded(lines))
    }

    static func time(_ source: String?) -> Double? {
        guard let source else { return nil }
        let value: Double?
        if source.hasSuffix("ms") { value = Double(source.dropLast(2)).map { $0 / 1000 } }
        else if source.hasSuffix("s") { value = Double(source.dropLast()) }
        else {
            let parts = source.split(separator: ":").compactMap { Double($0) }
            guard parts.count == source.split(separator: ":").count, (1...3).contains(parts.count) else { return nil }
            value = parts.reduce(0) { $0 * 60 + $1 }
        }
        return value.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
}

private final class TTMLNode {
    let name: String
    let attributes: [String: String]
    var children: [TTMLNode] = []
    var value = ""
    init(name: String, attributes: [String: String] = [:]) { self.name = name; self.attributes = attributes }
    var text: String { name == "#text" ? value : children.map(\.text).joined() }
    func attribute(_ name: String) -> String? { attributes.first { $0.key.split(separator: ":").last == Substring(name) }?.value }
    func descendants(_ name: String) -> [TTMLNode] { children.flatMap { ($0.name == name ? [$0] : []) + $0.descendants(name) } }
}

private final class TTMLDocument: NSObject, XMLParserDelegate {
    var root: TTMLNode?
    private var stack: [TTMLNode] = []
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        guard stack.count < 128 else { parser.abortParsing(); return }
        let node = TTMLNode(name: String(elementName.split(separator: ":").last ?? Substring(elementName)), attributes: attributeDict)
        if let parent = stack.last { parent.children.append(node) } else { root = node }
        stack.append(node)
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { _ = stack.popLast() }
    func parser(_ parser: XMLParser, foundCharacters string: String) { append(string) }
    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) { append(whitespaceString) }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let text = String(data: CDATABlock, encoding: .utf8) { append(text) }
    }
    private func append(_ string: String) {
        guard let parent = stack.last else { return }
        if let last = parent.children.last, last.name == "#text" { last.value += string }
        else { let text = TTMLNode(name: "#text"); text.value = string; parent.children.append(text) }
    }
}
