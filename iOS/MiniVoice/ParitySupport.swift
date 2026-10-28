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
