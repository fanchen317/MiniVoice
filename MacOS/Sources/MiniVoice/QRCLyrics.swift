import Foundation
import zlib

/// QRC's public wire format uses a modified DES EDE transform, followed by zlib.
/// Keep this native and bounded: no Python runtime or alignment model is required.
enum QRCLyrics {
    static func decrypt(_ hex: String) throws -> String {
        let chars = Array(hex.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        guard !chars.isEmpty, chars.count <= 2_000_000, chars.count % 16 == 0 else { throw URLError(.cannotDecodeContentData) }
        func digit(_ c: UInt8) -> UInt8? {
            switch c { case 48...57: c - 48; case 65...70: c - 55; case 97...102: c - 87; default: nil }
        }
        var bytes: [UInt8] = []
        for i in stride(from: 0, to: chars.count, by: 2) {
            guard let a = digit(chars[i]), let b = digit(chars[i + 1]) else { throw URLError(.cannotDecodeContentData) }
            bytes.append(a * 16 + b)
        }
        var decoded: [UInt8] = []
        for i in stride(from: 0, to: bytes.count, by: 8) {
            var block = littleWords(Array(bytes[i..<i + 8])).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            for schedule in schedules { block = des(block, keys: schedule) }
            let output = (0..<8).map { UInt8(truncatingIfNeeded: block >> ((7 - $0) * 8)) }
            decoded += littleWords(output)
        }
        var buffer = [UInt8](repeating: 0, count: 2_000_000)
        var size = uLongf(buffer.count)
        guard uncompress(&buffer, &size, decoded, uLong(decoded.count)) == Z_OK,
              let text = String(bytes: buffer.prefix(Int(size)), encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        return text
    }

    static func convert(_ source: String) throws -> String {
        var text = source
        if source.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
            guard !source.localizedCaseInsensitiveContains("<!DOCTYPE"), !source.localizedCaseInsensitiveContains("<!ENTITY") else { throw URLError(.cannotDecodeContentData) }
            // QRC embeds literal newlines inside an XML attribute. XML's normal
            // attribute normalization otherwise folds the entire song into one line.
            let pattern = try NSRegularExpression(pattern: #"LyricContent\s*=\s*\"([^\"]*)\""#)
            var xml = source
            if let match = pattern.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
               let range = Range(match.range(at: 1), in: source) {
                let preserved = source[range].replacingOccurrences(of: "\r\n", with: "\n")
                    .replacingOccurrences(of: "\r", with: "\n").replacingOccurrences(of: "\n", with: "&#10;")
                xml.replaceSubrange(range, with: preserved)
            }
            let doc = try XMLDocument(xmlString: xml, options: [.nodeLoadExternalEntitiesNever])
            guard let attribute = try doc.nodes(forXPath: "//@LyricContent").first?.stringValue else { throw URLError(.cannotDecodeContentData) }
            text = attribute
        }
        let header = try NSRegularExpression(pattern: #"^\[(\d+),(\d+)\]"#)
        let word = try NSRegularExpression(pattern: #"\((\d+),(\d+)\)"#)
        return text.components(separatedBy: .newlines).map { row in
            let ns = row as NSString
            guard let h = header.firstMatch(in: row, range: NSRange(location: 0, length: ns.length)) else { return row }
            let start = (Double(ns.substring(with: h.range(at: 1))) ?? 0) / 1000
            let end = start + (Double(ns.substring(with: h.range(at: 2))) ?? 0) / 1000
            let body = ns.substring(from: NSMaxRange(h.range)) as NSString
            let matches = word.matches(in: body as String, range: NSRange(location: 0, length: body.length))
            var cursor = 0
            let words = matches.map { match -> LyricWord in
                let value = body.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                cursor = NSMaxRange(match.range)
                let begin = (Double(body.substring(with: match.range(at: 1))) ?? 0) / 1000
                return LyricWord(text: value, start: begin, end: begin + (Double(body.substring(with: match.range(at: 2))) ?? 0) / 1000)
            }
            let plain = word.stringByReplacingMatches(in: body as String, range: NSRange(location: 0, length: body.length), withTemplate: "")
            return LyricsTiming.encoded([LyricLine(timestamp: start, text: plain, endTime: end,
                words: LyricsTiming.validated(words, text: plain, start: start, end: end))])
        }.joined(separator: "\n")
    }

    private static func littleWords(_ bytes: [UInt8]) -> [UInt8] {
        [bytes[3], bytes[2], bytes[1], bytes[0], bytes[7], bytes[6], bytes[5], bytes[4]]
    }
    private static func permute(_ value: UInt64, width: Int, positions: [Int]) -> UInt64 {
        positions.reduce(0) { ($0 << 1) | ($1 <= width ? (value >> (width - $1)) & 1 : 0) }
    }
    private static let schedules: [[UInt64]] = {
        let key = Array("!@#)(*$%123ZXC!@!@#)(NHL".utf8) + [0]
        let keys = stride(from: 0, to: 24, by: 8).map { offset -> [UInt64] in
            let raw = littleWords(Array(key[offset..<offset + 8])).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            let selected = permute(raw, width: 64, positions: pc1)
            var left = selected >> 28, right = selected & 0xfffffff
            return shifts.map { shift in
                left = ((left << shift) | (left >> (28 - shift))) & 0xfffffff
                right = ((right << shift) | (right >> (28 - shift))) & 0xfffffff
                return permute((left << 28) | right, width: 56, positions: pc2)
            }
        }
        return [keys[2].reversed(), keys[1], keys[0].reversed()]
    }()
    private static func des(_ value: UInt64, keys: [UInt64]) -> UInt64 {
        let initial = permute(value, width: 64, positions: ip)
        var left = initial >> 32, right = initial & 0xffffffff
        for key in keys {
            let expanded = permute(right, width: 32, positions: expansion) ^ key
            var substituted: UInt64 = 0
            for box in 0..<8 {
                let six = Int((expanded >> ((7 - box) * 6)) & 63)
                let index = (six & 32) | ((six & 1) << 4) | ((six >> 1) & 15)
                substituted = (substituted << 4) | UInt64(sbox[box][index])
            }
            let next = left ^ permute(substituted, width: 32, positions: p)
            left = right; right = next
        }
        return permute((right << 32) | left, width: 64, positions: fp)
    }
    private static let shifts = [1,1,2,2,2,2,2,2,1,2,2,2,2,2,2,1]
    private static let ip = [58,50,42,34,26,18,10,2,60,52,44,36,28,20,12,4,62,54,46,38,30,22,14,6,64,56,48,40,32,24,16,8,57,49,41,33,25,17,9,1,59,51,43,35,27,19,11,3,61,53,45,37,29,21,13,5,63,55,47,39,31,23,15,7]
    private static let fp = [40,8,48,16,56,24,64,32,39,7,47,15,55,23,63,31,38,6,46,14,54,22,62,30,37,5,45,13,53,21,61,29,36,4,44,12,52,20,60,28,35,3,43,11,51,19,59,27,34,2,42,10,50,18,58,26,33,1,41,9,49,17,57,25]
    private static let pc1 = [57,49,41,33,25,17,9,1,58,50,42,34,26,18,10,2,59,51,43,35,27,19,11,3,60,52,44,36,63,55,47,39,31,23,15,7,62,54,46,38,30,22,14,6,61,53,45,37,29,21,13,5,28,20,12,4]
    // QRC advances the D-half selection by one bit, unlike standard DES.
    private static let pc2 = [14,17,11,24,1,5,3,28,15,6,21,10,23,19,12,4,26,8,16,7,27,20,13,2,42,53,32,38,48,56,31,41,52,46,34,49,45,50,40,57,35,54,47,43,51,37,30,33]
    private static let expansion = [32,1,2,3,4,5,4,5,6,7,8,9,8,9,10,11,12,13,12,13,14,15,16,17,16,17,18,19,20,21,20,21,22,23,24,25,24,25,26,27,28,29,28,29,30,31,32,1]
    private static let p = [16,7,20,21,29,12,28,17,1,15,23,26,5,18,31,10,2,8,24,14,32,27,3,9,19,13,30,6,22,11,4,25]
    private static let sbox = [
        [14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7,0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8,4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0,15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13],
        [15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10,3,13,4,7,15,2,8,15,12,0,1,10,6,9,11,5,0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15,13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9],
        [10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8,13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1,13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7,1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12],
        [7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15,13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9,10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4,3,15,0,6,10,10,13,8,9,4,5,11,12,7,2,14],
        [2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9,14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6,4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14,11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3],
        [12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11,10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8,9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6,4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13],
        [4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1,13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6,1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2,6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12],
        [13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7,1,15,13,8,10,3,7,4,12,5,6,11,0,14,9,2,7,11,4,1,9,12,14,2,0,6,10,13,15,3,5,8,2,1,14,7,4,10,8,13,15,12,9,0,3,5,6,11]
    ]
}
