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

    func testProductionCreditsBecomeNotes() {
        let text = LyricsAlignment.alignmentSource("音乐总监：甲\n制作总监：乙\n编曲：丙\n录音棚：丁\n第一句歌词", title: "测试")
        XCTAssertTrue(text.contains("[note:音乐总监：甲]"))
        XCTAssertTrue(text.contains("[note:制作总监：乙]"))
        XCTAssertTrue(text.contains("[note:编曲：丙]"))
        XCTAssertEqual(LRCParser.parse(text, placeholder: false).map(\.text), ["第一句歌词"])
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

    func testTextCleanupAndPhraseSplittingPreserveWords() {
        let source = "\n 为爱飞行 脱离地心引力的热情 寻找你每一个身影 \n\n第二句\r\n\r\n"
        let normalized = LyricsText.normalized(source)
        XCTAssertFalse(normalized.contains("\n\n"))
        XCTAssertGreaterThan(normalized.components(separatedBy: "\n").count, 2)
        XCTAssertEqual(normalized.filter { !$0.isWhitespace }, source.filter { !$0.isWhitespace })
        XCTAssertEqual(LyricsText.normalized("\n[00:03.00] 很长的歌词 保留已有时间点\n\n[00:06.00]\n"),
                       "[00:03.00] 很长的歌词 保留已有时间点\n[00:06.00]")
    }

    func testCreditsAndRepeatedTitle() {
        let cleaned = LyricsAlignment.alignmentSource("阿刁 (Live) - 张韶涵\nRap填词：作者\n原唱：作者\nProgram：作者\n伴唱：作者\n童声：作者\n第一句\n阿刁", title: "阿刁")
        XCTAssertEqual(LRCParser.parse(cleaned, placeholder: false).map(\.text), ["第一句", "阿刁"])
    }

    func testPartialAlignmentRetainsEveryLineWithoutInventingTime() throws {
        let result = [AlignedLyric(text: "甲", start: 1, end: 2),
                      AlignedLyric(text: "乙", start: nil, end: nil),
                      AlignedLyric(text: "丙", start: 5, end: 6),
                      AlignedLyric(text: "丁", start: 7, end: 8)]
        let merged = try LyricsAlignment.merge(result, source: "甲\n乙\n丙\n丁", duration: 10)
        let parsed = LRCParser.parse(merged)
        XCTAssertEqual(parsed.map(\.text), ["甲", "乙", "丙", "丁"])
        XCTAssertNil(parsed[1].timestamp)
        XCTAssertEqual(parsed.compactMap(\.timestamp), [1, 5, 7])
        XCTAssertThrowsError(try LyricsAlignment.merge([AlignedLyric(text: "甲", start: nil, end: nil)], source: "甲", duration: 10))
    }

    func testIsolatedInvalidTimesDoNotDiscardValidLyrics() throws {
        let result = [AlignedLyric(text: "甲", start: 1, end: 2),
                      AlignedLyric(text: "乙", start: 3, end: 200),
                      AlignedLyric(text: "丙", start: 5, end: 6),
                      AlignedLyric(text: "丁", start: 7, end: 8)]
        let merged = try LyricsAlignment.merge(result, source: "甲\n乙\n丙\n丁", duration: 10)
        let lines = LRCParser.parse(merged)
        XCTAssertEqual(lines.map(\.text), ["甲", "乙", "丙", "丁"])
        XCTAssertNil(lines[1].timestamp)
        XCTAssertEqual(lines.compactMap(\.timestamp), [1, 5, 7])
    }

    /// Optional local regression fixtures; never writes audio or the user's library.
    @MainActor func testAudioRegressionFixtures() async throws {
        guard let path = ProcessInfo.processInfo.environment["MINIVOICE_AI_FIXTURES"] else {
            throw XCTSkip("No local audio regression fixtures supplied")
        }
        struct Fixture: Decodable { let path: String; let lyrics: String?; let lyricsFile: String?; let title: String; let duration: Double }
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        for fixture in fixtures {
            let source = try fixture.lyricsFile.map { try String(contentsOf: URL(fileURLWithPath: $0), encoding: .utf8) } ?? fixture.lyrics ?? ""
            let result = try await LyricsAlignment().align(source: source, audioURL: URL(fileURLWithPath: fixture.path), duration: fixture.duration, title: fixture.title)
            let expected = LRCParser.parse(LyricsAlignment.alignmentSource(source, title: fixture.title), placeholder: false)
            let actual = LRCParser.parse(result, placeholder: false)
            XCTAssertEqual(actual.map(\.text), expected.map(\.text))
            XCTAssertGreaterThanOrEqual(Double(actual.filter { $0.timestamp != nil }.count) / Double(actual.count), 0.65)
            print("AI fixture validated: \(fixture.title), \(actual.filter { $0.timestamp != nil }.count)/\(actual.count) timed lines")
        }
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
            audioURL: audio, duration: 6)
        let lines = LRCParser.parse(result)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].timestamp ?? -1, 0.2, accuracy: 1)
        XCTAssertEqual(lines[1].timestamp ?? -1, 2.52, accuracy: 1)

        let service = LyricsAlignment()
        let task = Task { try await service.align(source: "Hello again", audioURL: audio, duration: 6) }
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
