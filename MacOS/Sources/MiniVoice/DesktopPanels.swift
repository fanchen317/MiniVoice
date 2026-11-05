import AppKit

/// Native integration only. All player, settings and editor content belongs to Electron.
@MainActor
final class DesktopPanels {
    private let shortcuts = PlaybackShortcutController()
    private let windowToggle = WindowToggleController()
    private let statusBar = StatusBarController()
    private var appearanceValue: String?

    init(library: MusicLibrary, shell: @escaping (String) -> Void) {
        shortcuts.connect(library: library)
        windowToggle.onToggle = { shell("toggleWindow") }
        statusBar.onQuit = { shell("quit") }
        statusBar.activatesNativeApp = false
        statusBar.start(library: library, openMainWindow: { shell("showWindow") })
    }

    func applyAppearance(_ value: String) {
        guard appearanceValue != value else { return }
        appearanceValue = value
        NSApp.appearance = value == "dark" ? NSAppearance(named: .darkAqua) : value == "light" ? NSAppearance(named: .aqua) : nil
    }

    func configureWindowShortcut(_ shortcut: PlaybackShortcut) { windowToggle.configure(shortcut) }
}
