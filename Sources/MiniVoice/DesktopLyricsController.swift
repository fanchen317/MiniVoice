import AppKit
import Combine
import SwiftUI

@MainActor
final class DesktopLyricsController: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "MiniVoice.desktopLyrics")
            updatePanelVisibility()
        }
    }
    @Published var isLocked: Bool {
        didSet {
            UserDefaults.standard.set(isLocked, forKey: "MiniVoice.desktopLyricsLocked")
        }
    }
    @Published private(set) var primaryLine = "MiniVoice"
    @Published private(set) var secondaryLine = "桌面歌词"
    @Published private(set) var lineProgress: Double?
    @Published private(set) var lineIdentity = ""

    private weak var library: MusicLibrary?
    private var cancellables = Set<AnyCancellable>()
    private var panel: NSPanel?
    private var panelMoveObserver: AnyCancellable?
    private var refreshPending = false
    private let positionKey = "MiniVoice.desktopLyricsPosition"

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: "MiniVoice.desktopLyrics")
        isLocked = UserDefaults.standard.bool(forKey: "MiniVoice.desktopLyricsLocked")
    }

    func connect(library: MusicLibrary) {
        guard self.library !== library else { return }
        self.library = library
        cancellables.removeAll()
        library.clock.$time.sink { [weak self] _ in self?.scheduleRefresh() }.store(in: &cancellables)
        library.$playingID.sink { [weak self] _ in self?.scheduleRefresh() }.store(in: &cancellables)
        library.$tracks.sink { [weak self] _ in self?.scheduleRefresh() }.store(in: &cancellables)
        refreshText()
        updatePanelVisibility()
    }

    func toggle() { isEnabled.toggle() }
    func toggleLock() { isLocked.toggle() }

    private func scheduleRefresh() {
        guard isEnabled, !refreshPending else { return }
        refreshPending = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.refreshPending = false
            self.refreshText()
        }
    }

    private func refreshText() {
        guard isEnabled else { return }
        var primary = "MiniVoice"
        var secondary = "桌面歌词"
        var progress: Double?
        var identity = "idle"
        if let library, let track = library.playingTrack ?? library.selectedTrack {
            let lines = track.lyricLines
            if let active = library.activeLyricIndex(for: lines) {
                let start = lines[active].timestamp ?? 0
                let end = lines.dropFirst(active + 1).compactMap(\.timestamp).first(where: { $0 > start }) ?? track.duration
                progress = DesktopLyricScroll.progress(time: library.playbackTime, start: start, end: end)
                identity = "\(track.id)-\(active)"
                primary = lines[active].text
                secondary = lines.dropFirst(active + 1).first(where: { !$0.text.isEmpty })?.text
                    ?? "\(track.title) - \(track.artist)"
            } else {
                identity = "\(track.id)-title"
                primary = track.title
                secondary = track.artist
            }
        }
        if primaryLine != primary { primaryLine = primary }
        if secondaryLine != secondary { secondaryLine = secondary }
        if lineProgress != progress { lineProgress = progress }
        if lineIdentity != identity { lineIdentity = identity }
    }

    private func updatePanelVisibility() {
        if isEnabled {
            refreshText()
            showPanel()
        } else {
            panel?.orderOut(nil)
        }
    }

    private func showPanel() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 104),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovableByWindowBackground = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            let contentView = DesktopLyricsPanelView(controller: self)
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
            panel.contentView = contentView
            self.panel = panel
            // Restore before observing movement so initial placement cannot overwrite it.
            restoreOrPositionPanel()
            panelMoveObserver = NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: panel)
                .sink { [weak self, weak panel] _ in
                    MainActor.assumeIsolated {
                        guard let self, let panel else { return }
                        self.savePosition(panel.frame.origin)
                    }
                }
        }

        panel?.orderFrontRegardless()
        (panel?.contentView as? DesktopLyricsPanelView)?.refreshHoverState()
    }

    private func restoreOrPositionPanel() {
        guard let screen = NSScreen.main, let panel else { return }
        if let values = UserDefaults.standard.array(forKey: positionKey) as? [CGFloat], values.count == 2 {
            let origin = NSPoint(x: values[0], y: values[1])
            let frame = NSRect(origin: origin, size: panel.frame.size)
            if WindowPlacementStore.isValid(frame) {
                panel.setFrameOrigin(WindowPlacementStore.visibleFrame(frame, screens: NSScreen.screens.map(\.visibleFrame)).origin)
                return
            }
        }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 86))
    }

    private func savePosition(_ origin: NSPoint) {
        UserDefaults.standard.set([origin.x, origin.y], forKey: positionKey)
    }
}

/// Owns mouse events independently of SwiftUI's animated lyric hierarchy.
private final class DesktopLyricsPanelView: NSView {
    private let controller: DesktopLyricsController
    private let glass = NSVisualEffectView()
    private let lyrics: DesktopLyricsHostingView
    private let lockButton = NSButton()
    private var lockSubscription: AnyCancellable?
    private var hoverArea: NSTrackingArea?

    init(controller: DesktopLyricsController) {
        self.controller = controller
        lyrics = DesktopLyricsHostingView(rootView: DesktopLyricsOverlay(controller: controller))
        super.init(frame: NSRect(x: 0, y: 0, width: 520, height: 104))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.alphaValue = 0.68
        glass.isHidden = true
        addSubview(glass)
        addSubview(lyrics)
        lockButton.isBordered = false
        lockButton.bezelStyle = .regularSquare
        lockButton.target = self
        lockButton.action = #selector(toggleLock)
        lockButton.isHidden = true
        addSubview(lockButton)
        lockSubscription = controller.$isLocked.sink { [weak self] locked in
            self?.lockButton.image = NSImage(systemSymbolName: locked ? "lock.fill" : "lock.open", accessibilityDescription: locked ? "解锁桌面歌词位置" : "锁定桌面歌词位置")
            self?.lockButton.toolTip = locked ? "解锁桌面歌词位置" : "锁定桌面歌词位置"
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
        glass.frame = bounds
        glass.wantsLayer = true
        glass.layer?.cornerRadius = bounds.height / 2
        glass.layer?.masksToBounds = true
        // Mask the backdrop sampling itself, not only the foreground layer.
        let maskBounds = NSRect(origin: .zero, size: bounds.size)
        glass.maskImage = NSImage(size: bounds.size, flipped: false) { _ in
            NSColor.white.setFill()
            NSBezierPath(roundedRect: maskBounds, xRadius: maskBounds.height / 2, yRadius: maskBounds.height / 2).fill()
            return true
        }
        lyrics.frame = bounds
        lockButton.frame = NSRect(x: bounds.midX - 10, y: bounds.height - 18, width: 20, height: 18)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    private func setHovered(_ hovered: Bool) {
        glass.isHidden = !hovered
        lockButton.isHidden = !hovered
    }

    func refreshHoverState() {
        guard let window, window.isVisible else {
            setHovered(false)
            return
        }
        let point = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        setHovered(bounds.contains(point))
    }

    override func mouseEntered(with event: NSEvent) { setHovered(true) }
    override func mouseExited(with event: NSEvent) { setHovered(false) }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).contains(local) else { return nil }
        if !lockButton.isHidden && lockButton.frame.contains(local) { return lockButton }
        return self
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        guard !controller.isLocked else { return }
        window?.performDrag(with: event)
        refreshHoverState()
    }
    @objc private func toggleLock() { controller.toggleLock() }
}

private final class DesktopLyricsHostingView: NSHostingView<DesktopLyricsOverlay> {
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct DesktopLyricsOverlay: View {
    @ObservedObject var controller: DesktopLyricsController

    private var lyricKey: String {
        controller.lineIdentity + controller.primaryLine + "\u{001F}" + controller.secondaryLine
    }

    var body: some View {
        ZStack {
            VStack(spacing: 5) {
                DesktopLyricMarquee(text: controller.primaryLine, size: 27, weight: .semibold, progress: controller.lineProgress)
                DesktopLyricMarquee(text: controller.secondaryLine, size: 18, weight: .medium, progress: controller.lineProgress)
                    .foregroundStyle(.secondary)
            }
            .id(lyricKey)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.38), value: lyricKey)
    }
}

/// Timed lyrics reveal the whole line within its actual playback interval.
private struct DesktopLyricMarquee: View {
    let text: String
    let size: CGFloat
    let weight: Font.Weight
    let progress: Double?
    @State private var textWidth: CGFloat = 0
    @State private var startedAt = Date()

    var body: some View {
        GeometryReader { geometry in
            let overflow = max(0, textWidth - geometry.size.width)
            TimelineView(.animation(paused: overflow <= 0 || progress != nil)) { context in
                Text(text)
                    .font(.system(size: size, weight: weight, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(GeometryReader { measurement in
                        Color.clear.preference(key: DesktopLyricWidthKey.self, value: measurement.size.width)
                    })
                    .offset(x: overflow > 0 ? -scrollOffset(at: context.date, overflow: overflow) : 0)
                    .animation(.linear(duration: 0.18), value: progress)
                    .frame(width: geometry.size.width, height: geometry.size.height,
                           alignment: overflow > 0 ? .leading : .center)
            }
            .onPreferenceChange(DesktopLyricWidthKey.self) { width in
                if textWidth != width {
                    textWidth = width
                    startedAt = Date()
                }
            }
            .onChange(of: text) { _ in startedAt = Date() }
            .onChange(of: geometry.size.width) { _ in startedAt = Date() }
        }
        .frame(height: size * 1.35)
        .accessibilityLabel(text)
    }

    private func scrollOffset(at date: Date, overflow: CGFloat) -> CGFloat {
        guard overflow > 0 else { return 0 }
        if let progress { return overflow * progress }
        let duration = Double(overflow) / 30
        // Pause at both ends, then begin another pass from the start.
        let elapsed = max(0, date.timeIntervalSince(startedAt))
            .truncatingRemainder(dividingBy: duration + 3)
        return min(overflow, CGFloat(max(0, elapsed - 1.5) * 30))
    }
}

enum DesktopLyricScroll {
    static func progress(time: TimeInterval, start: TimeInterval, end: TimeInterval) -> Double {
        guard time.isFinite, start.isFinite, end.isFinite, end > start else { return 0 }
        // A brief proportional opening pause; finish early enough to read the end.
        let fraction = (time - start) / (end - start)
        return min(1, max(0, (fraction - 0.08) / 0.72))
    }
}

private struct DesktopLyricWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
