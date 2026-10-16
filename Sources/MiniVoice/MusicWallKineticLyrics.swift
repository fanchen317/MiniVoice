import SwiftUI
import AppKit

enum MusicWallLyricsStyle: String {
    case scrolling, kinetic

    var title: String { self == .scrolling ? "滚动歌词" : "灵动逐字" }
    var symbol: String { self == .scrolling ? "text.alignleft" : "textformat.size" }
    var next: Self { self == .scrolling ? .kinetic : .scrolling }
}

/// Presentation-only character timings. Real word boundaries remain authoritative.
enum KineticLyricsTiming {
    static func characters(in line: LyricLine) -> [LyricWord] {
        line.words.enumerated().flatMap { index, word -> [LyricWord] in
            let characters = Array(word.text)
            guard !characters.isEmpty else { return [] }
            let end = word.end ?? (index + 1 < line.words.count ? line.words[index + 1].start : line.endTime ?? word.start + 0.5)
            let step = max(0, end - word.start) / Double(characters.count)
            return characters.enumerated().map { offset, character in
                LyricWord(text: String(character), start: word.start + Double(offset) * step,
                          end: word.start + Double(offset + 1) * step)
            }
        }
    }
}

/// The animation reads the playback clock, so pauses and seeks never leave a queued animation behind.
struct MusicWallKineticLyrics: View {
    @EnvironmentObject private var clock: PlaybackClock
    @EnvironmentObject private var library: MusicLibrary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("MiniVoice.showLyricsTranslation") private var showTranslation = true
    let track: Track

    var body: some View {
        let snapshot = track.lyricSnapshot
        let time = track.id == library.playingID ? clock.time : 0
        let active = snapshot.activeIndex(at: time)
        let index = active ?? 0
        let original = snapshot.lines[index]
        let line = LyricsDisplayTiming.line(original,
            nextStart: snapshot.lines.dropFirst(index + 1).compactMap(\.timestamp).first { $0 > (original.timestamp ?? 0) },
            trackDuration: track.duration)
        let playing = library.playingID == track.id && library.isPlaying
        let waiting = active == nil && snapshot.kind != .plain
        GeometryReader { viewport in
          VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                if waiting || line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("•••")
                        .font(.system(size: 32, weight: .bold)).tracking(10)
                        .foregroundStyle(.cyan.opacity(0.75))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .accessibilityLabel("等待歌词")
                } else if line.words.isEmpty || reduceMotion || library.playingID != track.id {
                    Text(line.text).font(.system(size: min(54, geometry.size.width * 0.09), weight: .bold))
                        .minimumScaleFactor(0.4).multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    KineticLyricsGlyphs(characters: KineticLyricsTiming.characters(in: line),
                        size: geometry.size, time: time, sampledAt: clock.sampledAt, isPlaying: playing)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(line.text)
                }
            }
            .id(original.id)
            .transition(.opacity.combined(with: .offset(y: 12)))
            .frame(height: max(80, viewport.size.height * 0.58))
            if showTranslation, !waiting, let translation = line.translation {
                Text(translation).font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7)).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 4)
            if !waiting {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(snapshot.lines.dropFirst(index + 1).prefix(2).enumerated()), id: \.element.id) { offset, upcoming in
                        Text(upcoming.text)
                            .font(.system(size: min(30, viewport.size.width * 0.052), weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.white.opacity(offset == 0 ? 0.52 : 0.34))
                            .blur(radius: offset == 0 ? 1.1 : 2.2)
                            .scaleEffect(offset == 0 ? 0.96 : 0.92, anchor: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 12)
          .frame(width: viewport.size.width, height: viewport.size.height, alignment: .topLeading)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.82), value: index)
        .id(track.id)
    }
}

struct KineticLyricsGlyphs: View {
    let characters: [LyricWord]
    let size: CGSize
    let time: Double
    var sampledAt: Date? = nil
    var isPlaying = false

    var body: some View {
        let layout = KineticLyricsLayout(characters: characters, size: size)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { timeline in
            let displayTime = LyricsSweep.displayTime(time, sampledAt: sampledAt, now: timeline.date, playing: isPlaying)
            Canvas { context, _ in
                for (index, glyph) in layout.glyphs.enumerated() {
                    let word = characters[index]
                    let entrance = LyricsSweep.progress(time: displayTime, start: word.start, end: word.start + 0.34)
                    let progress = LyricsSweep.progress(time: displayTime, start: word.start, end: max(word.start + 0.24, word.end ?? word.start + 0.5))
                    let pulse = displayTime >= word.start ? max(0, sin(progress * .pi)) : 0
                    let bounce = sin(entrance * .pi) * (1 - entrance) * layout.fontSize * 0.19
                    var ink = context
                    ink.opacity = displayTime < word.start ? 0.26 : 0.82 + 0.18 * entrance
                    ink.translateBy(x: glyph.x, y: glyph.y + (1 - entrance) * layout.fontSize * 0.12 - bounce - pulse * layout.fontSize * 0.08)
                    ink.rotate(by: .degrees(sin(Double(index) * 1.7) * 3 * sin(entrance * .pi)))
                    let scale = 0.94 + 0.06 * entrance + 0.12 * pulse
                    ink.scaleBy(x: scale, y: scale)
                    let color = Color(red: 1 - 0.45 * pulse, green: 1 - 0.12 * pulse, blue: 1)
                    ink.addFilter(.shadow(color: .cyan.opacity(pulse * 0.6), radius: 10 * pulse))
                    ink.draw(Text(word.text).font(.system(size: layout.fontSize, weight: .bold)).foregroundColor(color), at: .zero)
                }
            }
        }
    }
}

/// Wrap long phrases and fit both dimensions, leaving room for the lifted glyphs.
struct KineticLyricsLayout {
    let fontSize: CGFloat
    let glyphs: [CGPoint]

    init(characters: [LyricWord], size: CGSize) {
        let width = max(1, size.width - 32)
        let height = max(1, size.height - 32)
        var fontSize = min(58, max(20, size.width * 0.095))
        var positions: [CGPoint] = []
        var totalHeight: CGFloat = 0
        for attempt in 0..<24 {
            let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
            let rowHeight = fontSize * 1.8
            var x: CGFloat = 0
            var row = 0
            positions = characters.map { word in
                let advance = max(fontSize * 0.3, (word.text as NSString).size(withAttributes: [.font: font]).width) + fontSize * 0.12
                if x > 0 && x + advance > width { row += 1; x = 0 }
                let point = CGPoint(x: 16 + x + advance / 2, y: CGFloat(row) * rowHeight + rowHeight / 2)
                x += advance
                return point
            }
            totalHeight = CGFloat(row + 1) * rowHeight
            if totalHeight <= height || attempt == 23 { break }
            fontSize *= 0.82
        }
        self.fontSize = fontSize
        self.glyphs = positions.map { CGPoint(x: $0.x, y: $0.y + (size.height - totalHeight) / 2) }
    }
}
