import Foundation
import MiniVoiceShared

@main
struct ParitySupportTests {
    static func main() async throws {
        let identities = ["ui-fixture-0", "/private/Music/歌手 #1%/曲目.mp3", "/one/同名.mp3", "/two/同名.mp3", "空 格/?#%🙂"]
        for id in identities {
            let token = SongResourceToken.encode(id)
            let url = URL(string: "minivoice://app/artwork/\(token).png?v=1")!
            precondition(SongResourceToken.decode(String(url.lastPathComponent.dropLast(4))) == id)
        }
        precondition(SongResourceToken.decode("../outside") == nil)
        precondition(SongResourceToken.decode("a") == nil)
        precondition(Set(identities.map(SongResourceToken.encode)).count == identities.count)

        for mode in 0...4 {
            precondition(ExperiencePlaybackPolicy.previous(index: 0, count: 3) == 2)
            precondition(ExperiencePlaybackPolicy.next(index: 2, count: 3, mode: mode, manual: true, random: { _ in 0 }) != nil)
        }
        precondition(ExperiencePlaybackPolicy.next(index: 0, count: 3, mode: 0, manual: false) == nil)
        precondition(ExperiencePlaybackPolicy.next(index: 2, count: 3, mode: 1, manual: false) == nil)
        precondition(ExperiencePlaybackPolicy.next(index: 2, count: 3, mode: 4, manual: false) == 0)
        precondition(ExperiencePlaybackPolicy.next(index: 1, count: 3, mode: 3, manual: false) == 1)
        for index in 0..<3 { for random in 0..<2 {
            let result = ExperiencePlaybackPolicy.next(index: index, count: 3, mode: 2, manual: false, random: { _ in random })
            precondition(result != nil && result != index)
        }}
        precondition(ExperiencePlaybackPolicy.next(index: 0, count: 0, mode: 2, manual: true) == nil)

        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("mv-parity-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temp) }
        let cache = temp.appendingPathComponent("Artwork")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let original = temp.appendingPathComponent("music.mp3")
        try Data("original music".utf8).write(to: original)
        try Data([1,2,3]).write(to: cache.appendingPathComponent("cover.jpg"))
        try FileManager.default.createSymbolicLink(at: cache.appendingPathComponent("outside"), withDestinationURL: original)
        let entries = try ScopedCacheFiles.list(root: cache)
        precondition(entries.count == 1 && entries[0].bytes == 3)
        do { _ = try ScopedCacheFiles.clear(root: cache, ids: [entries[0].id, "forged"]); preconditionFailure("stale selection accepted") } catch {}
        precondition(FileManager.default.fileExists(atPath: entries[0].url.path))
        let removed = try ScopedCacheFiles.clear(root: cache)
        let retained = try String(contentsOf: original, encoding: .utf8)
        precondition(removed == 1 && retained == "original music")
        let link = temp.appendingPathComponent("linked-cache")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: temp)
        do { _ = try ScopedCacheFiles.list(root: link); preconditionFailure("root symlink accepted") } catch {}

        let old = Data(#"{"id":"old","folderID":"folder","relativePath":"a.mp3","title":"song","artist":"artist","album":"album","duration":1}"#.utf8)
        let decoded = try JSONDecoder().decode(Song.self, from: old)
        precondition(decoded.sourceAdded == nil && decoded.originalArtworkFile == nil && decoded.id == "old")
        var history = DiagnosticHistory()
        for i in 0..<240 { history.append(DiagnosticRecord(id: "event-\(i)", kind: .event, detail: String(repeating: "中文", count: 1000))) }
        for i in 0..<8 { history.append(DiagnosticRecord(id: "crash-\(i)", kind: .crash, detail: "synthetic crash")) }
        history.append(DiagnosticRecord(id: "crash-7", kind: .crash, detail: "duplicate"))
        precondition(history.records.count == 205 && history.crashCount == 5)
        precondition(history.records.filter { $0.kind == .event }.allSatisfy { $0.detail.utf8.count <= 515 })
        let scrubbed = DiagnosticRecord(kind: .failure, detail: "file:///private/a.mp3 content://provider/id /Users/example/Music/song.mp3 /var/mobile/secret token")
        precondition(!scrubbed.detail.contains("secret") && !scrubbed.detail.contains("provider") && !scrubbed.detail.contains("example"))
        let rawMetric = try JSONSerialization.data(withJSONObject: ["frames": [["path": "/private/var/music/song.wav", "url": "file:///Users/test/secret.mp3"]]])
        let redactedMetric = try DiagnosticRecord.metricDetail(rawMetric)
        precondition(!redactedMetric.contains("secret") && !redactedMetric.contains("song.wav"))
        let logURL = temp.appendingPathComponent("diagnostics/history.json")
        let store = DiagnosticStore(url: logURL)
        _ = try await store.append(scrubbed)
        _ = try await store.append(DiagnosticRecord(id: "stable-crash", kind: .crash, detail: "synthetic"))
        let restartedStore = DiagnosticStore(url: logURL)
        let restoredHistory = try await restartedStore.snapshot()
        precondition(restoredHistory.records.count == 2 && restoredHistory.crashCount == 1)
        let deduplicated = try await restartedStore.append(DiagnosticRecord(id: "stable-crash", kind: .crash, detail: "redelivered"))
        precondition(deduplicated.crashCount == 1)
        let corruptURL = temp.appendingPathComponent("corrupt-history.json")
        try Data("invalid JSON".utf8).write(to: corruptURL)
        do { _ = try await DiagnosticStore(url: corruptURL).append(scrubbed); preconditionFailure("corrupt history silently replaced") } catch {}
        let corruptRetained = try String(contentsOf: corruptURL, encoding: .utf8)
        precondition(corruptRetained == "invalid JSON")
        do { _ = try await DiagnosticStore(url: original.appendingPathComponent("history.json")).append(scrubbed); preconditionFailure("write failure silently accepted") } catch {}
        print("PASS: bounded diagnostics, redaction, crash redelivery, restart persistence and visible write/corruption failures")
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let flac = try FLACMetadata.read(repository.appendingPathComponent("Android/ui-tests/assets/tags.flac"))
        precondition(abs((flac.duration ?? 0) - 1) < 0.001)
        var picture = Data()
        func big(_ value: Int) { var v = UInt32(value).bigEndian; withUnsafeBytes(of: &v) { picture.append(contentsOf: $0) } }
        let image = Data([137,80,78,71,13,10,26,10])
        big(3); big(9); picture.append(Data("image/png".utf8)); big(0)
        big(1); big(1); big(24); big(0); big(image.count); picture.append(image)
        var artificial = Data("fLaC".utf8)
        artificial.append(contentsOf: [0x86, UInt8((picture.count >> 16) & 255), UInt8((picture.count >> 8) & 255), UInt8(picture.count & 255)])
        artificial.append(picture)
        let pictureURL = temp.appendingPathComponent("picture.flac"); try artificial.write(to: pictureURL)
        let readPicture = try FLACMetadata.read(pictureURL); precondition(readPicture.artwork == image)
        try artificial.dropLast().write(to: pictureURL)
        do { _ = try FLACMetadata.read(pictureURL); preconditionFailure("truncated FLAC picture accepted") } catch {}
        var comments = Data()
        func little(_ value: Int) { var v = UInt32(value).littleEndian; withUnsafeBytes(of: &v) { comments.append(contentsOf: $0) } }
        let tags = ["TITLE=测试曲目", "ARTIST=歌手", "ALBUM=专辑", "LYRICS=[00:00.00]歌词"]
        little(0); little(tags.count)
        for tag in tags { let bytes = Data(tag.utf8); little(bytes.count); comments.append(bytes) }
        var tagged = Data("fLaC".utf8)
        tagged.append(contentsOf: [0x84, UInt8((comments.count >> 16) & 255), UInt8((comments.count >> 8) & 255), UInt8(comments.count & 255)])
        tagged.append(comments); try tagged.write(to: pictureURL)
        let readTags = try FLACMetadata.read(pictureURL)
        precondition(readTags.title == "测试曲目" && readTags.artist == "歌手" && readTags.album == "专辑" && readTags.lyrics == "[00:00.00]歌词")
        do { _ = try SharedEngine.execute(["op":"not-a-real-operation"]); preconditionFailure("unknown core operation accepted") }
        catch { precondition(error.localizedDescription.contains("Unknown core operation")) }
        print("PASS FLAC STREAMINFO duration, VORBIS tags/lyrics, PICTURE bytes, truncation and readable core errors")
        let zip = DiagnosticArchive.zip(name: "diagnostics.json", data: Data("{\"ok\":true}".utf8))
        try zip.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("PASS: path identity round trips, five Android playback policies, scoped cache deletion, legacy index decode and ZIP export")
    }
}
