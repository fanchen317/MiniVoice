import SwiftUI
import AppKit

// MusicWallPlayer.swift: readable clock-driven lyrics and controls inside the expanded poster.
struct MusicWallPlayer: View, @MainActor Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isExpanded == rhs.isExpanded && lhs.isFavorite == rhs.isFavorite && lhs.track.id == rhs.track.id && lhs.track.title == rhs.track.title && lhs.track.artist == rhs.track.artist
            && lhs.track.lyrics == rhs.track.lyrics && lhs.track.duration == rhs.track.duration
            && lhs.track.artworkKey == rhs.track.artworkKey && lhs.showsArtwork == rhs.showsArtwork
            && lhs.track.resourcesLoaded == rhs.track.resourcesLoaded
            && lhs.track.artwork.map(ObjectIdentifier.init) == rhs.track.artwork.map(ObjectIdentifier.init)
    }
    @AppStorage("MiniVoice.musicWallLyricsStyle") private var lyricsStyle: MusicWallLyricsStyle = .scrolling
    @EnvironmentObject private var library: MusicLibrary
    let track: Track
    let onPlay: () -> Void
    let onExpand: () -> Void
    let isFavorite: Bool
    let onFavorite: () -> Void
    var showsArtwork = true
    var isExpanded = false
    var body: some View {
        GeometryReader { geometry in
            let sizing = MusicWallCardSizing(size: geometry.size)
            ZStack(alignment: .topLeading) {
                if showsArtwork {
                    MusicWallCover(track: track, prefersThumbnail: false).equatable()
                        .ignoresSafeArea(edges: isExpanded ? .all : [])
                }
                LinearGradient(stops: [.init(color: .black.opacity(0.86), location: 0),
                                       .init(color: .black.opacity(0.58), location: 0.55),
                                       .init(color: .black.opacity(0.2), location: 1)], startPoint: .leading, endPoint: .trailing)
                LinearGradient(stops: [.init(color: .clear, location: 0),
                                       .init(color: .black.opacity(0.12), location: 0.6),
                                       .init(color: .black.opacity(0.88), location: 1)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: geometry.size.width < 300 ? 8 : 16) {
                    VStack(alignment: .leading, spacing: sizing.spacing) {
                        HStack(spacing: 7) {
                            MusicWallPlaybackWaveform(active: track.id == library.playingID && library.isPlaying)
                                .frame(width: 16, height: 16)
                            Text(track.id == library.playingID ? (library.isPreparingPlayback ? "正在加载" : library.isPlaying ? "正在播放" : "已暂停") : "预览")
                        }
                            .fixedSize(horizontal: true, vertical: true)
                            .font(.system(size: sizing.status, weight: .bold)).tracking(1.5).foregroundStyle(.mint)
                            .padding(.horizontal, sizing.spacing).padding(.vertical, sizing.spacing * 0.65)
                            .background(.mint.opacity(0.18), in: Capsule())
                            .overlay { Capsule().strokeBorder(.mint.opacity(0.6), lineWidth: 1) }
                        Text(track.title).font(.system(size: sizing.title, weight: .bold)).lineLimit(2)
                        Text(track.artist).font(.system(size: sizing.artist, weight: .medium)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    }.fixedSize(horizontal: false, vertical: true)
                    MusicWallLyrics(track: track, style: isExpanded ? lyricsStyle : .scrolling)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(-1)
                        .clipped()
                    MusicWallTransport(track: track, onPlay: onPlay, onExpand: onExpand, isFavorite: isFavorite, onFavorite: onFavorite, isExpanded: isExpanded, lyricsStyle: $lyricsStyle, availableWidth: geometry.size.width - sizing.padding * 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(sizing.padding)
                .padding(.top, isExpanded ? 30 : 0)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
            .foregroundStyle(.white).clipped()
            .overlay {
                if !isExpanded { Rectangle().strokeBorder(Color.mint.opacity(0.85), lineWidth: 3).allowsHitTesting(false) }
            }
        }
    }
}

/// Only this subtree observes the playback clock; thousands of cover cards do not redraw on ticks.
private struct MusicWallLyrics: View {
    @EnvironmentObject private var clock: PlaybackClock
    @EnvironmentObject private var library: MusicLibrary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let track: Track
    var style: MusicWallLyricsStyle = .scrolling
    var body: some View {
        GeometryReader { geometry in
            let snapshot = track.lyricSnapshot
            let time = track.id == library.playingID ? clock.time : 0
            let active = snapshot.activeIndex(at: time) ?? 0
            let layout = MusicWallLyricsLayout(size: geometry.size)
            let compact = layout.singleLine
            let fontSize = layout.fontSize
            if track.lyricsAreLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small).tint(.white)
                    Text("正在加载歌词…").font(.callout).foregroundStyle(.white.opacity(0.65))
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else if snapshot.lines.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(track.title).font(.system(size: fontSize, weight: .bold))
                    Text("暂无歌词").font(.callout).foregroundStyle(.white.opacity(0.5))
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else if style == .kinetic {
                MusicWallKineticLyrics(track: track)
            } else {
                let rowHeight = layout.rowHeight
                // Keep each lyric's identity as it moves through the center. Reusing
                // three relative slots replaced text instantly instead of moving rows.
                ZStack(alignment: .leading) {
                    ForEach(max(0, active - (compact ? 0 : layout.visibleRadius))...min(snapshot.lines.count - 1, active + (compact ? 0 : layout.visibleRadius)), id: \.self) { index in
                            let relative = index - active
                            let line = snapshot.lines[index]
                            Button { if let time = line.timestamp, library.playingID == track.id { library.seek(to: time) } } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    TimedLyricText(line: relative == 0 ? LyricsDisplayTiming.line(line,
                                                   nextStart: snapshot.lines.dropFirst(index + 1).lazy.compactMap(\.timestamp).first(where: { $0 > (line.timestamp ?? 0) }),
                                                   trackDuration: track.duration) : line,
                                                   time: time, active: relative == 0 && track.id == library.playingID && snapshot.activeIndex(at: time) != nil,
                                                   baseColor: .white, pendingWordOpacity: 0.35, highlightColor: .white,
                                                   isPlaying: track.id == library.playingID && library.isPlaying, sampledAt: clock.sampledAt)
                                        .font(.system(size: fontSize, weight: .bold))
                                        .shadow(color: .black.opacity(0.75), radius: 5, y: 2)
                                        .lineLimit(line.translation == nil && rowHeight >= fontSize * 2 ? 2 : 1)
                                        .lineSpacing(4).multilineTextAlignment(.leading)
                                    if let translation = line.translation, rowHeight >= fontSize * 1.8 {
                                        Text(translation).font(.system(size: fontSize * 0.42)).foregroundStyle(.white.opacity(0.82)).lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: max(0, rowHeight - 6), alignment: .leading)
                            }.buttonStyle(.plain)
                                .background(MusicWallInputExclusion(allowsWallDrag: true))
                                .opacity(relative == 0 ? 1 : 0.58)
                                .blur(radius: relative == 0 ? 0 : 0.3)
                                .frame(height: rowHeight)
                                .scaleEffect(relative == 0 ? 1 : 0.94, anchor: .leading)
                                .offset(y: CGFloat(relative) * rowHeight)
                                .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .clipped()
                .mask {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.08),
                                           .init(color: .black, location: 0.92), .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.9), value: active)
            }
        }
    }
}

private struct MusicWallTransport: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var clock: PlaybackClock
    let track: Track
    let onPlay: () -> Void
    let onExpand: () -> Void
    let isFavorite: Bool
    let onFavorite: () -> Void
    let isExpanded: Bool
    @Binding var lyricsStyle: MusicWallLyricsStyle
    let availableWidth: CGFloat
    private var buttonSide: CGFloat { min(32, max(22, availableWidth * 0.085)) }
    @State private var scrub: Double?
    var body: some View {
        VStack(spacing: 7) {
            if availableWidth >= 340 {
                HStack(spacing: 12) {
                    transportButtons
                    timeLabel
                }
            } else {
                VStack(alignment: .trailing, spacing: 5) {
                    transportButtons
                    timeLabel
                }
            }
            MusicWallProgressSlider(value: Binding(get: { scrub ?? min(max(0, library.playingID == track.id ? clock.time : 0), max(1, track.duration)) }, set: { scrub = $0 }),
                   range: 0...max(1, track.duration), onEditingChanged: { editing in
                if !editing, let scrub { library.seek(to: scrub); self.scrub = nil }
            }).frame(height: 18).background(MusicWallInputExclusion()).help("播放进度").disabled(library.playingID != track.id)
        }
        .onChange(of: track.id) { _ in scrub = nil }
    }
    private var transportButtons: some View {
        HStack(spacing: 4) {
            control("backward.end", "上一曲") { library.skip(-1) }
            control((library.isPlaying || library.isPreparingPlayback) && library.playingID == track.id ? "pause.fill" : "play.fill", "播放 / 暂停", action: onPlay)
            control("forward.end", "下一曲") { library.skip(1) }
            control(isFavorite ? "heart.fill" : "heart", isFavorite ? "取消收藏" : "收藏歌曲", action: onFavorite)
            MusicWallModeMenu(side: buttonSide)
            Spacer(minLength: 0)
            if isExpanded {
                control(lyricsStyle.symbol, "歌词样式：\(lyricsStyle.title)，点击切换为\(lyricsStyle.next.title)") {
                    lyricsStyle = lyricsStyle.next
                }
                .accessibilityValue(lyricsStyle.title)
            }
            control(isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", isExpanded ? "收起播放器" : "展开播放器", action: onExpand)
        }
    }
    private var timeLabel: some View {
        Text("\(time(scrub ?? (library.playingID == track.id ? clock.time : 0))) / \(time(track.duration))")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
    }
    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: max(13, buttonSide * 0.5))).frame(width: buttonSide, height: buttonSide) }
            .buttonStyle(MusicWallControlStyle()).help(label).accessibilityLabel(label)
    }
    private func time(_ value: Double) -> String {
        let seconds = Int(max(0, value.isFinite ? value : 0))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// Draw the compact progress rail directly so its fill and thumb follow the
/// same geometry while the wall player changes size.
private struct MusicWallProgressSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    @Environment(\.isEnabled) private var enabled
    @State private var dragging = false
    private let thumbSize: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let fraction = PlaybackSliderMetrics.fraction(value: value, range: range)
            let travel = max(0, geometry.size.width - thumbSize)
            let center = thumbSize / 2 + travel * fraction
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.35)).frame(height: 2)
                Capsule().fill(.white).frame(width: center, height: 2)
                Circle().fill(.white).frame(width: thumbSize, height: thumbSize)
                    .offset(x: travel * fraction)
            }
            .frame(height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    guard enabled else { return }
                    if !dragging { dragging = true; onEditingChanged(true) }
                    value = PlaybackSliderMetrics.value(position: gesture.location.x,
                        width: geometry.size.width, thumbSize: thumbSize, range: range)
                }
                .onEnded { _ in
                    guard dragging else { return }
                    dragging = false
                    onEditingChanged(false)
                })
        }
        .focusable()
        .onMoveCommand { direction in
            guard enabled, direction == .left || direction == .right else { return }
            onEditingChanged(true)
            value = min(range.upperBound, max(range.lowerBound,
                value + (direction == .right ? 1 : -1) * (range.upperBound - range.lowerBound) / 100))
            onEditingChanged(false)
        }
        .accessibilityRepresentation {
            Slider(value: Binding(get: { value }, set: { value = $0; onEditingChanged(false) }), in: range)
                .accessibilityLabel("播放进度")
        }
        .onDisappear { if dragging { dragging = false; onEditingChanged(false) } }
    }
}

/// A visible hit area and immediate press feedback for the poster transport.
struct MusicWallControlStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        Feedback(configuration: configuration, reduceMotion: reduceMotion)
    }
    private struct Feedback: View {
        let configuration: ButtonStyleConfiguration
        let reduceMotion: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var hovered = false
        var body: some View {
            configuration.label.padding(3)
                .background(.white.opacity(!enabled ? 0 : configuration.isPressed ? 0.25 : hovered ? 0.13 : 0),
                            in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(configuration.isPressed ? Color.mint : Color.white)
                .scaleEffect(reduceMotion || !enabled ? 1 : configuration.isPressed ? 0.88 : hovered ? 1.06 : 1)
                .opacity(enabled ? 1 : 0.4)
                .contentShape(Rectangle())
                .background(MusicWallInputExclusion(allowsWallDrag: true))
                .onHover { hovered = $0 }
                .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovered)
        }
    }
}

/// One appearance for playback-mode menus in the card and floating dock.
struct MusicWallModeMenu: View {
    var side: CGFloat = 32
    @EnvironmentObject private var library: MusicLibrary
    @State private var showingModes = false
    var body: some View {
        Button { showingModes.toggle() } label: {
            Image(systemName: library.playbackMode.symbolName)
                .font(.system(size: max(13, side * 0.5))).foregroundStyle(.white).frame(width: side, height: side)
        }
        .buttonStyle(MusicWallControlStyle())
        .background(MusicWallInputExclusion(allowsWallDrag: true))
        .popover(isPresented: $showingModes, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("播放模式").font(.headline).padding(.horizontal, 8).padding(.bottom, 5)
                ForEach(PlaybackMode.allCases) { mode in
                    Button {
                        library.playbackMode = mode
                        showingModes = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: mode.symbolName).frame(width: 20)
                            Text(mode.title)
                            Spacer()
                            if library.playbackMode == mode { Image(systemName: "checkmark").foregroundStyle(.mint) }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).frame(height: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MusicWallControlStyle())
                }
            }
            .padding(12).frame(width: 208)
            .background(Color(red: 0.12, green: 0.14, blue: 0.14))
            .environment(\.colorScheme, .dark).foregroundStyle(.white)
        }
        .help("播放模式：" + library.playbackMode.title)
        .accessibilityLabel("播放模式：" + library.playbackMode.title)
    }
}

private struct MusicWallPlaybackWaveform: NSViewRepresentable {
    let active: Bool
    func makeNSView(context: Context) -> WaveformView {
        let view = WaveformView()
        view.setActive(active)
        return view
    }
    func updateNSView(_ view: WaveformView, context: Context) { view.setActive(active) }

    final class WaveformView: NSView {
        private let bars: [CALayer] = (0..<3).map { index in
            let bar = CALayer()
            bar.bounds = CGRect(x: 0, y: 0, width: 2.5, height: 14)
            bar.position = CGPoint(x: 3 + CGFloat(index) * 5, y: 8)
            bar.cornerRadius = 1.25
            bar.backgroundColor = NSColor.systemMint.cgColor
            bar.setAffineTransform(CGAffineTransform(scaleX: 1, y: 0.35))
            return bar
        }
        private var animated = false

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            bars.forEach { layer?.addSublayer($0) }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        override var intrinsicContentSize: NSSize { NSSize(width: 16, height: 16) }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func setActive(_ active: Bool) {
            guard animated != active else { return }
            animated = active
            for (index, bar) in bars.enumerated() {
                bar.removeAnimation(forKey: "pulse")
                guard active else { continue }
                let pulse = CABasicAnimation(keyPath: "transform.scale.y")
                pulse.fromValue = 0.35
                pulse.toValue = 1
                pulse.duration = 0.46 + Double(index) * 0.08
                pulse.beginTime = CACurrentMediaTime() + Double(index) * 0.1
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                bar.add(pulse, forKey: "pulse")
            }
        }
    }
}

/// Keep nearby lines visible without stretching their spacing to fill a tall player.
struct MusicWallLyricsLayout {
    let singleLine: Bool
    let fontSize: CGFloat
    let rowHeight: CGFloat
    let visibleRadius: Int
    init(size: CGSize) {
        singleLine = size.height < 60
        fontSize = min(58, max(12, min(size.width * 0.062, size.height / (singleLine ? 2.8 : 11))))
        rowHeight = singleLine ? size.height : min(size.height / 3, fontSize * 2.15 + 8)
        visibleRadius = singleLine ? 0 : max(4, Int(ceil(size.height / max(1, rowHeight))))
    }
}

struct MusicWallCardSizing {
    let title: CGFloat
    let artist: CGFloat
    let status: CGFloat
    let spacing: CGFloat
    let padding: CGFloat
    init(size: CGSize) {
        let scale = min(1, max(0.65, min(size.width / 430, size.height / 430)))
        title = max(16, 28 * scale)
        artist = max(10, 14 * scale)
        status = max(9, 11 * scale)
        spacing = 12 * scale
        padding = max(12, 22 * scale)
    }
}
