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

    private weak var library: MusicLibrary?
    private var cancellables = Set<AnyCancellable>()
    private var panel: NSPanel?
    private var panelMoveObserver: NSObjectProtocol?
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
        if let library, let track = library.playingTrack ?? library.selectedTrack {
            let lines = track.lyricLines
            if let active = library.activeLyricIndex(for: lines) {
                primary = lines[active].text
                secondary = lines.dropFirst(active + 1).first(where: { !$0.text.isEmpty })?.text ?? track.artist
            } else {
                primary = track.title
                secondary = track.artist
            }
        }
        if primaryLine != primary { primaryLine = primary }
        if secondaryLine != secondary { secondaryLine = secondary }
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
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 118),
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
            panelMoveObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: panel,
                queue: .main
            ) { [weak self, weak panel] _ in
                Task { @MainActor [weak self, weak panel] in
                    guard let self, let panel else { return }
                    self.savePosition(panel.frame.origin)
                }
            }
        }
        restoreOrPositionPanel()
        panel?.orderFrontRegardless()
    }

    private func restoreOrPositionPanel() {
        guard let screen = NSScreen.main, let panel else { return }
        if let values = UserDefaults.standard.array(forKey: positionKey) as? [CGFloat], values.count == 2 {
            let origin = NSPoint(x: values[0], y: values[1])
            if screen.visibleFrame.intersects(NSRect(origin: origin, size: panel.frame.size)) {
                panel.setFrameOrigin(origin)
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
        super.init(frame: NSRect(x: 0, y: 0, width: 760, height: 118))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.alphaValue = 0.68
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
        lockButton.frame = NSRect(x: bounds.width - 56, y: bounds.height - 49, width: 32, height: 32)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) { lockButton.isHidden = false }
    override func mouseExited(with event: NSEvent) { lockButton.isHidden = true }
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
        controller.primaryLine + "\u{001F}" + controller.secondaryLine
    }

    var body: some View {
        ZStack {
            VStack(spacing: 5) {
                Text(controller.primaryLine)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(controller.secondaryLine)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .id(lyricKey)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
        }
        .padding(.horizontal, 52)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .animation(.easeInOut(duration: 0.38), value: lyricKey)
    }
}
