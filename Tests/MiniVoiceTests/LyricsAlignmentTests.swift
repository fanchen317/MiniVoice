import XCTest
@testable import MiniVoice

final class LyricsAlignmentTests: XCTestCase {
    func testFormatRouting() {
        XCTAssertTrue(LyricsAlignment.needsAlignment("第一句\n第二句"))
        XCTAssertTrue(LyricsAlignment.needsAlignment("[00:02.00]第一句\n第二句"))
        XCTAssertFalse(LyricsAlignment.needsAlignment("[ar:歌手]\n[00:02.00]第一句\n[00:04.00]第二句"))
        XCTAssertFalse(LyricsAlignment.needsAlignment(" \n"))
        XCTAssertFalse(LyricsAlignment.needsAlignment("[ar:歌手]"))
        XCTAssertFalse(LyricsAlignment.needsAlignment("1\n00:00:02,000 --> 00:00:03,000\n第一句"))
    }

    func testCreditsDoNotBecomeSungLines() {
        let text = LyricsAlignment.alignmentSource("幻听 - 许嵩\n词：许嵩\n曲：许嵩\n[Verse 1]\n在远方的时候", title: "幻听")
        XCTAssertEqual(LRCParser.parse(text, placeholder: false).map(\.text), ["在远方的时候"])
        XCTAssertTrue(text.contains("[note:词：许嵩]"))
    }

    func testMergePreservesRepeatedLinesAndAnchors() throws {
        let source = "[note:词：作者]\n[00:02.00]重复\n第二句\n重复"
        let result = [AlignedLyric(text: "重复", start: 1, end: 3),
                      AlignedLyric(text: "第二句", start: 8, end: 10),
                      AlignedLyric(text: "重复", start: 18, end: 20)]
        let merged = try LyricsAlignment.merge(result, source: source, duration: 25)
        XCTAssertTrue(merged.contains("[note:词：作者]"))
        XCTAssertEqual(LRCParser.parse(merged).compactMap(\.timestamp), [2, 8, 18])
        XCTAssertEqual(LRCParser.parse(merged).map(\.text), ["重复", "第二句", "重复"])
    }

    func testRejectInvalidAlignment() {
        for bad in [AlignedLyric(text: "错词", start: 1, end: 2),
                    AlignedLyric(text: "原文", start: .nan, end: 2),
                    AlignedLyric(text: "原文", start: -1, end: 2),
                    AlignedLyric(text: "原文", start: 1, end: 1),
                    AlignedLyric(text: "原文", start: 1, end: 200)] {
            XCTAssertThrowsError(try LyricsAlignment.merge([bad], source: "原文", duration: 10))
        }
        XCTAssertThrowsError(try LyricsAlignment.merge([], source: "原文", duration: 10))
        XCTAssertThrowsError(try LyricsAlignment.merge([
            AlignedLyric(text: "甲", start: 3, end: 4), AlignedLyric(text: "乙", start: 2, end: 3)
        ], source: "甲\n乙", duration: 10))
    }

    func testOffsetIsAppliedOnlyOnceAndRoundingCarries() throws {
        let result = [AlignedLyric(text: "甲", start: 1, end: 3), AlignedLyric(text: "乙", start: 5, end: 6)]
        let merged = try LyricsAlignment.merge(result, source: "[offset:500]\n[00:01.00]甲\n乙", duration: 10)
        XCTAssertEqual(LRCParser.parse(merged).compactMap(\.timestamp), [1.5, 5])
        XCTAssertEqual(LRCParser.stamp(59.999, text: "跨分钟"), "[01:00.00] 跨分钟")
    }

    @MainActor func testTimedLyricsBypassRuntime() async throws {
        let source = "[00:02.00]不用模型"
        let result = try await LyricsAlignment().align(source: source, audioURL: URL(fileURLWithPath: "/missing"), duration: 10)
        XCTAssertEqual(result, source)
    }

    @MainActor func testCancellationBeforeStarting() async {
        let task = Task { try await LyricsAlignment().align(source: "第一句", audioURL: URL(fileURLWithPath: "/missing"), duration: 10) }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    /// Opt-in integration check uses the actual bundled worker/runtime/model, never library audio.
    @MainActor func testLocalModelIntegration() async throws {
        guard ProcessInfo.processInfo.environment["MINIVOICE_TEST_AI"] == "1" else {
            throw XCTSkip("Set MINIVOICE_TEST_AI=1 to exercise the local model")
        }
        let audio = FileManager.default.temporaryDirectory.appendingPathComponent("MiniVoice-AI-\(UUID()).aiff")
        defer { try? FileManager.default.removeItem(at: audio) }
        let speech = Process()
        speech.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        speech.arguments = ["-v", "Samantha", "-o", audio.path, "Hello my friend, welcome to the music. We sing together, under the morning sun."]
        try speech.run()
        speech.waitUntilExit()
        XCTAssertEqual(speech.terminationStatus, 0)
        let result = try await LyricsAlignment().align(
            source: "Hello my friend, welcome to the music.\nWe sing together, under the morning sun.",
            audioURL: audio, duration: 10)
        let lines = LRCParser.parse(result)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].timestamp ?? -1, 0.2, accuracy: 1)
        XCTAssertEqual(lines[1].timestamp ?? -1, 2.52, accuracy: 1)

        let service = LyricsAlignment()
        let task = Task { try await service.align(source: "Hello again", audioURL: audio, duration: 10) }
        for _ in 0..<100 {
            if !service.status.isEmpty { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertFalse(service.status.isEmpty)
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation during model startup") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(service.status, "")
    }
}
