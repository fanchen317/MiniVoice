import Foundation

/// Resource identities must survive slashes, Unicode, percent signs and same-name files.
enum SongResourceToken {
    static func encode(_ id: String) -> String {
        Data(id.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    static func decode(_ token: String) -> String? {
        guard !token.isEmpty, token.count <= 16384,
              token.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_").contains($0) }) else { return nil }
        var value = token.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        value += String(repeating: "=", count: (4 - value.count % 4) % 4)
        guard let data = Data(base64Encoded: value), let id = String(data: data, encoding: .utf8), encode(id) == token else { return nil }
        return id
    }
}

/// Android experience playback policy, in queue indices. nil means stop at the end.
enum ExperiencePlaybackPolicy {
    static func next(index: Int, count: Int, mode: Int, manual: Bool, random: (Int) -> Int = { Int.random(in: 0..<$0) }) -> Int? {
        guard count > 0, index >= 0, index < count else { return nil }
        if !manual && mode == 0 { return nil }
        if !manual && mode == 3 { return index }
        if mode == 2 && count > 1 {
            let candidate = min(count - 2, max(0, random(count - 1)))
            return candidate >= index ? candidate + 1 : candidate
        }
        if index + 1 < count { return index + 1 }
        return manual || mode == 4 ? 0 : nil
    }
    static func previous(index: Int, count: Int) -> Int? {
        guard count > 0, index >= 0, index < count else { return nil }
        return index > 0 ? index - 1 : count - 1
    }
}

enum ScopedCacheFiles {
    struct Entry: Sendable {
        let id: String
        let url: URL
        let bytes: Int
        var dto: [String: Any] { ["id": id, "name": url.lastPathComponent, "bytes": bytes] }
    }
    static func list(root: URL) throws -> [Entry] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        guard (try root.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else { throw failure("缓存目录不可为链接") }
        let canonical = root.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        var failureSeen: Error?
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey], errorHandler: { _, error in failureSeen = error; return false }) else { throw failure("无法读取缓存目录") }
        var entries: [Entry] = []
        for case let url as URL in walker {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            if values.isSymbolicLink == true { walker.skipDescendants(); continue }
            guard values.isRegularFile == true, url.resolvingSymlinksInPath().path.hasPrefix(canonical) else { continue }
            entries.append(Entry(id: SongResourceToken.encode(String(url.path.dropFirst(root.path.count + 1))), url: url, bytes: values.fileSize ?? 0))
        }
        if let failureSeen { throw failureSeen }
        return entries.sorted { $0.id < $1.id }
    }
    static func clear(root: URL, ids: [String]? = nil) throws -> Int {
        let entries = try list(root: root)
        let selection: [Entry]
        if let ids {
            let known = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
            guard !ids.isEmpty, ids.allSatisfy({ known[$0] != nil }) else { throw failure("缓存列表已变化，请刷新后重试") }
            selection = Set(ids).compactMap { known[$0] }
        } else { selection = entries }
        // Only the freshly enumerated, scoped regular files are eligible. Never follow a swapped symlink.
        let canonical = root.resolvingSymlinksInPath().path + "/"
        for entry in selection {
            let values = try entry.url.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true, entry.url.resolvingSymlinksInPath().path.hasPrefix(canonical) else { throw failure("缓存路径已改变，已停止清理") }
        }
        var removed = 0
        for entry in selection { try FileManager.default.removeItem(at: entry.url); removed += 1 }
        return removed
    }
    private static func failure(_ text: String) -> NSError { NSError(domain: "MiniVoice.Cache", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
}

/// Small standards-compliant ZIP (stored entries), avoiding a third-party archive dependency.
enum DiagnosticArchive {
    static func zip(name: String, data: Data) -> Data {
        precondition(data.count < Int(UInt32.max))
        let filename = Data(name.utf8)
        var output = Data()
        func u16(_ value: UInt16) { var n = value.littleEndian; withUnsafeBytes(of: &n) { output.append(contentsOf: $0) } }
        func u32(_ value: UInt32) { var n = value.littleEndian; withUnsafeBytes(of: &n) { output.append(contentsOf: $0) } }
        var crc: UInt32 = 0xffffffff
        for byte in data { crc ^= UInt32(byte); for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1 } }
        crc ^= 0xffffffff
        u32(0x04034b50); u16(20); u16(0x800); u16(0); u16(0); u16(33); u32(crc); u32(UInt32(data.count)); u32(UInt32(data.count)); u16(UInt16(filename.count)); u16(0)
        output.append(filename); output.append(data)
        let central = UInt32(output.count)
        u32(0x02014b50); u16(20); u16(20); u16(0x800); u16(0); u16(0); u16(33); u32(crc); u32(UInt32(data.count)); u32(UInt32(data.count)); u16(UInt16(filename.count)); u16(0); u16(0); u16(0); u16(0); u32(0); u32(0); output.append(filename)
        let size = UInt32(output.count) - central
        u32(0x06054b50); u16(0); u16(0); u16(1); u16(1); u32(size); u32(central); u16(0)
        return output
    }
}

struct DiagnosticRecord: Codable, Sendable {
    enum Kind: String, Codable, Sendable { case event, failure, crash }
    let id: String
    let timestamp: Date
    let kind: Kind
    let detail: String

    init(id: String = UUID().uuidString, timestamp: Date = Date(), kind: Kind, detail: String) {
        self.id = id; self.timestamp = timestamp; self.kind = kind
        let scrubbed = Self.scrub(detail)
        self.detail = String(decoding: scrubbed.utf8.prefix(kind == .crash ? 16384 : 512), as: UTF8.self)
    }

    static func scrub(_ detail: String) -> String {
        detail.replacingOccurrences(of: #"(?:file|content|https?)://[^\s\"<>]+"#, with: "[uri]", options: .regularExpression)
            .replacingOccurrences(of: #"/(?:Users|private|var|Volumes|storage|sdcard|data/user)/[^\s\"<>]+"#, with: "[path]", options: .regularExpression)
    }

    static func metricDetail(_ data: Data) throws -> String {
        func sanitize(_ value: Any) -> Any {
            if let text = value as? String { return scrub(text) }
            if let array = value as? [Any] { return array.map(sanitize) }
            if let object = value as? [String: Any] { return object.mapValues(sanitize) }
            return value
        }
        let object = try JSONSerialization.jsonObject(with: data)
        let scrubbed = try JSONSerialization.data(withJSONObject: sanitize(object), options: [.sortedKeys, .withoutEscapingSlashes])
        return String(decoding: scrubbed, as: UTF8.self)
    }
}

struct DiagnosticHistory: Codable, Sendable {
    private(set) var records: [DiagnosticRecord] = []
    var crashCount: Int { records.filter { $0.kind == .crash }.count }
    mutating func append(_ record: DiagnosticRecord) {
        guard !records.contains(where: { $0.id == record.id }) else { return }
        records.append(record)
        records.sort { $0.timestamp < $1.timestamp }
        let crashes = records.filter { $0.kind == .crash }.suffix(5)
        let events = records.filter { $0.kind != .crash }.suffix(200)
        records = (Array(crashes) + Array(events)).sorted { $0.timestamp < $1.timestamp }
    }
}

/// Serial actor owns disk access. A failed write never publishes a successful saved state.
actor DiagnosticStore {
    private let url: URL
    private var history: DiagnosticHistory?
    init(url: URL) { self.url = url }
    func snapshot() throws -> DiagnosticHistory {
        if let history { return history }
        let loaded: DiagnosticHistory
        do { loaded = try JSONDecoder().decode(DiagnosticHistory.self, from: Data(contentsOf: url)) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { loaded = DiagnosticHistory() }
        history = loaded
        return loaded
    }
    func append(_ record: DiagnosticRecord) throws -> DiagnosticHistory {
        var next = try snapshot()
        next.append(record)
        let data = try JSONEncoder().encode(next)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        history = next
        return next
    }
}

/// FLAC's native metadata blocks are not consistently exposed as AVFoundation commonMetadata.
struct FLACMetadata {
    var title: String?
    var artist: String?
    var album: String?
    var lyrics: String?
    var duration: Double?
    var artwork: Data?

    static func read(_ url: URL) throws -> FLACMetadata {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        func bytes(_ count: Int) throws -> Data {
            guard let data = try file.read(upToCount: count), data.count == count else { throw CocoaError(.fileReadCorruptFile) }
            return data
        }
        guard try bytes(4) == Data("fLaC".utf8) else { throw CocoaError(.fileReadCorruptFile) }
        var result = FLACMetadata(), total = 0, front = false
        while true {
            let header = [UInt8](try bytes(4)), last = header[0] & 0x80 != 0, type = header[0] & 0x7f
            let count = Int(header[1]) << 16 | Int(header[2]) << 8 | Int(header[3])
            total += count + 4
            guard total <= 64 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
            if type == 0 || type == 4 || type == 6 {
                let block = [UInt8](try bytes(count))
                var offset = 0
                func number(_ little: Bool = false) throws -> Int {
                    guard offset + 4 <= block.count else { throw CocoaError(.fileReadCorruptFile) }
                    let parts = Array(block[offset..<offset + 4]); offset += 4
                    return (little ? Array(parts.reversed()) : parts).reduce(0) { ($0 << 8) | Int($1) }
                }
                func take(_ n: Int) throws -> Data {
                    guard n >= 0, n <= block.count - offset else { throw CocoaError(.fileReadCorruptFile) }
                    defer { offset += n }; return Data(block[offset..<offset + n])
                }
                if type == 0 {
                    guard count == 34 else { throw CocoaError(.fileReadCorruptFile) }
                    let packed = block[10..<18].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
                    let rate = packed >> 44, samples = packed & 0xfffffffff
                    if rate > 0 { result.duration = Double(samples) / Double(rate) }
                } else if type == 4 {
                    _ = try take(number(true)); let entries = try number(true)
                    guard entries <= block.count / 4 else { throw CocoaError(.fileReadCorruptFile) }
                    for _ in 0..<entries {
                        let text = String(decoding: try take(number(true)), as: UTF8.self)
                        let pair = text.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                        guard pair.count == 2 else { continue }
                        let value = String(pair[1])
                        switch pair[0].uppercased() {
                        case "TITLE": result.title = value
                        case "ARTIST": result.artist = value
                        case "ALBUM": result.album = value
                        case "LYRICS", "UNSYNCEDLYRICS": result.lyrics = value
                        default: break
                        }
                    }
                } else {
                    let pictureType = try number()
                    _ = try take(number()); _ = try take(number())
                    for _ in 0..<4 { _ = try number() }
                    let picture = try take(number())
                    if !picture.isEmpty && (!front || pictureType == 3) { result.artwork = picture; front = pictureType == 3 }
                }
            } else { try file.seek(toOffset: file.offset() + UInt64(count)) }
            if last { break }
        }
        return result
    }
}
