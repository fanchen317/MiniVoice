import XCTest
@testable import MiniVoice

final class PlayerTests: XCTestCase {
    func testAutomaticPlaybackModesAndManualBoundaries() {
        let ids = [UUID(), UUID(), UUID()]
        var queue = PlaybackQueue()
        XCTAssertNil(queue.destination(current: ids[0], ids: ids, mode: .single, automatic: true))
        XCTAssertEqual(queue.destination(current: ids[0], ids: ids, mode: .repeatOne, automatic: true), ids[0])
        XCTAssertEqual(queue.destination(current: ids[0], ids: ids, mode: .list, automatic: true), ids[1])
        XCTAssertNil(queue.destination(current: ids[2], ids: ids, mode: .list, automatic: true))
        XCTAssertEqual(queue.destination(current: ids[2], ids: ids, mode: .repeatAll, automatic: true), ids[0])
        XCTAssertEqual(queue.destination(current: ids[0], ids: ids, mode: .single, direction: -1), ids[2])
        XCTAssertEqual(queue.destination(current: ids[2], ids: ids, mode: .repeatOne), ids[0])
        XCTAssertNil(queue.destination(current: nil, ids: [], mode: .shuffle))
    }

    func testShuffleRoundAndHistory() throws {
        let ids = (0..<12).map { _ in UUID() }
        var queue = PlaybackQueue()
        queue.reset(current: ids[0], ids: ids)
        var visited = [ids[0]]
        for _ in 1..<ids.count {
            visited.append(try XCTUnwrap(queue.destination(current: visited.last, ids: ids, mode: .shuffle)))
        }
        XCTAssertEqual(Set(visited), Set(ids))
        let previous = queue.destination(current: visited.last, ids: ids, mode: .shuffle, direction: -1)
        XCTAssertEqual(previous, visited[visited.count - 2])
        XCTAssertEqual(queue.destination(current: previous, ids: ids, mode: .shuffle), visited.last)
        XCTAssertNotEqual(queue.destination(current: visited.last, ids: ids, mode: .shuffle), visited.last)
    }

    func testFolderScanRecursionDeduplicationAndMissingFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let child = root.appendingPathComponent("child")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for file in ["one.MP3", "child/two.flac", "cover.png", ".hidden.mp3", "one.mp3.minivoice-backup-123"] {
            try Data().write(to: root.appendingPathComponent(file))
        }
        XCTAssertEqual(FolderScanner.scan([root], recursive: false).urls.count, 1)
        XCTAssertEqual(FolderScanner.scan([root, child], recursive: true).urls.count, 2)
        XCTAssertEqual(FolderScanner.scan([root.appendingPathComponent("missing")], recursive: true).issues.count, 1)
    }

    @MainActor
    func testNaturalEndAdvancesThenStops() async throws {
        let name = "MiniVoiceCompletion-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
        for file in ["a.wav", "b.wav"] {
            _ = try MediaTools.run("ffmpeg", ["-v", "error", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", "0.25", root.appendingPathComponent(file).path])
        }
        let library = MusicLibrary(defaults: defaults, scanOnLaunch: false)
        library.volume = 0; library.addFolders([root])
        for _ in 0..<500 {
            if !library.isImporting { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(library.tracks.count, 2)
        library.playbackMode = .list; library.play()
        for _ in 0..<500 {
            if !library.isPlaying { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.selectedID, library.tracks.last?.id)
        XCTAssertFalse(library.isPlaying)
        library.stop()
    }

    @MainActor
    func testLibraryRescanAndTransport() async throws {
        let name = "MiniVoiceTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
        for file in ["a.wav", "b.wav"] {
            _ = try MediaTools.run("ffmpeg", ["-v", "error", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", "10", root.appendingPathComponent(file).path])
        }
        let library = MusicLibrary(defaults: defaults, scanOnLaunch: false)
        library.volume = 0
        library.addFolders([root, root])
        func waitForScan() async throws {
            for _ in 0..<1000 {
                if !library.isImporting { return }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTFail("Scan did not complete")
        }
        try await waitForScan()
        XCTAssertEqual(library.folders.count, 1)
        XCTAssertEqual(library.tracks.count, 2)
        let first = try XCTUnwrap(library.selectedID)
        library.seek(to: 4); library.skip(-1)
        XCTAssertEqual(library.selectedID, first)
        XCTAssertEqual(library.playbackTime, 0)
        library.play()
        XCTAssertTrue(library.isPlaying)
        library.skip(1)
        XCTAssertNotEqual(library.selectedID, first)
        XCTAssertTrue(library.isPlaying)
        library.playbackMode = .single
        library.playbackFinished(successfully: true)
        XCTAssertFalse(library.isPlaying)
        library.play()
        XCTAssertTrue(library.isPlaying)
        XCTAssertEqual(library.playbackTime, 0)
        library.pause()
        let selected = library.selectedID
        library.rescan(); try await waitForScan()
        XCTAssertEqual(library.selectedID, selected)
        XCTAssertEqual(defaults.stringArray(forKey: "MiniVoice.musicFolders"), [root.path])
        library.removeFolder(root); try await waitForScan()
        XCTAssertTrue(library.tracks.isEmpty)
        XCTAssertNil(library.selectedID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("a.wav").path))
    }
}
