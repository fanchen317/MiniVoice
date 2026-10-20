import Foundation

enum LyricsStorage {
    static func sidecarURL(for audioURL: URL) -> URL {
        let parent = audioURL.deletingLastPathComponent()
        let stem = audioURL.deletingPathExtension().lastPathComponent
        return parent
            .appendingPathComponent("lrc", isDirectory: true)
            .appendingPathComponent(stem)
            .appendingPathExtension("lrc")
    }

    static func read(_ url: URL) -> String? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : raw
    }

    static func write(_ lyrics: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try lyrics.write(to: url, atomically: true, encoding: .utf8)
    }

    static func delete(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
