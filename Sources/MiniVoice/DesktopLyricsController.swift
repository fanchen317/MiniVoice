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
    @Published private(set) var line = "MiniVoice"
    @Published private(set) var subtitle = "桌面歌词"

    private weak var library: MusicLibrary?
    private var cancellables = Set<AnyCancellable>()
    private var panel: NSPanel?

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: "MiniVoice.desktopLyrics")
    }

    func connect(library: MusicLibrary) {
        guard self.library !== library else { return }
        self.library = library
        cancellables.removeAll()
        library.$playbackTime.sink { [weak self] _ in self?.refreshText() }.store(in: &cancellables)
        library.$selectedID.sink { [weak self] _ in self?.refreshText() }.store(in: &cancellables)
        library.$tracks.sink { [weak self] _ in self?.refreshText() }.store(in: &cancellables)
        refreshText()
        updatePanelVisibility()
    }

    func toggle() {
        isEnabled.toggle()
    }

    private func refreshText() {
        guard let library, let track = library.selectedTrack else {
            line = "MiniVoice"
            subtitle = "桌面歌词"
            return
        }
        let lines = track.lyricLines
        if let active = library.activeLyricIndex(for: lines), lines.indices.contains(active) {
            line = lines[active].text
        } else {
            line = track.title
        }
        subtitle = track.artist
    }

    private func updatePanelVisibility() {
        if isEnabled {
            showPanel()
        } else {
            panel?.orderOut(nil)
        }
    }

    private func showPanel() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 92),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.ignoresMouseEvents = true
            panel.contentView = NSHostingView(rootView: DesktopLyricsOverlay(controller: self))
            self.panel = panel
        }
        positionPanel()
        panel?.orderFrontRegardless()
    }

    private func positionPanel() {
        guard let screen = NSScreen.main, let panel else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 86))
    }
}

private struct DesktopLyricsOverlay: View {
    @ObservedObject var controller: DesktopLyricsController

    var body: some View {
        VStack(spacing: 5) {
            Text(controller.line)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(controller.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        .padding(10)
    }
}
