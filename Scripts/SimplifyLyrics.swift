import Foundation

// Compile with ChineseLyricsScript.swift, FolderScanner.swift and LyricsStorage.swift.
// Dry-run by default. Sidecars override embedded lyrics without rewriting audio.
@main struct SimplifyLyrics {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 2 else { fatalError("Usage: simplify-lyrics ROOT [--apply]") }
        let root = URL(fileURLWithPath: args[1]).standardizedFileURL
        let apply = args.contains("--apply")
        let fm = FileManager.default
        let scan = FolderScanner.scan([root], recursive: true)
        guard scan.issues.isEmpty else { fatalError(scan.issues.joined(separator: "\n")) }
        let backup = root.appendingPathComponent("backup/lyrics-simplified-\(Int(Date().timeIntervalSince1970))")
        var changed: [[String: String]] = [], errors: [String] = []
        var effective: [String: String] = [:]
        var withLyrics = 0
        for audio in scan.urls {
            do {
                let sidecar = LyricsStorage.sidecarURL(for: audio)
                var original = LyricsStorage.read(sidecar)
                if original == nil {
                    let process = Process(), pipe = Pipe()
                    process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffprobe")
                    process.arguments = ["-v", "error", "-show_entries", "format_tags", "-of", "json", audio.path]
                    process.standardOutput = pipe
                    process.standardError = FileHandle.nullDevice
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else { throw CocoaError(.fileReadUnknown) }
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let format = json?["format"] as? [String: Any]
                    let tags = (format?["tags"] as? [String: String] ?? [:])
                        .reduce(into: [String: String]()) { $0[$1.key.lowercased()] = $1.value }
                    original = tags["lyrics"] ?? tags["unsyncedlyrics"]
                }
                guard let original, !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                withLyrics += 1
                let converted = ChineseLyricsScript.simplified(original)
                effective[audio.path] = converted
                guard original != converted else { continue }
                // Assert all timestamp/metadata brackets survive conversion unchanged.
                let regex = try NSRegularExpression(pattern: #"\[(?:\d[^\]]*|offset:[^\]]*)\]"#)
                func anchors(_ text: String) -> [String] {
                    regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                        (text as NSString).substring(with: $0.range)
                    }
                }
                guard anchors(original) == anchors(converted) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
                let relative = String(sidecar.path.dropFirst(root.path.count + 1))
                if apply {
                    let saved = backup.appendingPathComponent(relative)
                    try fm.createDirectory(at: saved.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if fm.fileExists(atPath: sidecar.path) { try fm.copyItem(at: sidecar, to: saved) }
                    else { try original.write(to: saved, atomically: true, encoding: .utf8) }
                    let existed = fm.fileExists(atPath: sidecar.path)
                    try LyricsStorage.write(converted, to: sidecar)
                    changed.append(["audio": audio.path, "sidecar": sidecar.path, "backup": saved.path, "created": String(!existed)])
                } else { changed.append(["audio": audio.path, "sidecar": sidecar.path]) }
            } catch { errors.append("\(audio.path): \(error)") }
        }
        if apply {
            let cache = root.appendingPathComponent(".minivoice-playlist.json")
            if fm.fileExists(atPath: cache.path) {
                let data = try Data(contentsOf: cache)
                var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                var tracks = json["tracks"] as! [[String: Any]]
                for index in tracks.indices {
                    if let path = tracks[index]["path"] as? String,
                       let lyrics = effective[root.appendingPathComponent(path).path] {
                        tracks[index]["lyrics"] = lyrics
                    }
                }
                try fm.createDirectory(at: backup, withIntermediateDirectories: true)
                try data.write(to: backup.appendingPathComponent(".minivoice-playlist.json"), options: .atomic)
                json["tracks"] = tracks
                try JSONSerialization.data(withJSONObject: json).write(to: cache, options: .atomic)
            }
            try fm.createDirectory(at: backup, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: ["changed": changed, "errors": errors], options: [.prettyPrinted, .sortedKeys])
                .write(to: backup.appendingPathComponent("manifest.json"), options: .atomic)
        }
        print("Scanned: \(scan.urls.count), with lyrics: \(withLyrics), changed: \(changed.count), errors: \(errors.count), applied: \(apply)")
        if apply { print("Backup: \(backup.path)") }
        for error in errors { print(error) }
    }
}
