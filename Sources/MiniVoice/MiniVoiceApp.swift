import SwiftUI

@main
struct MiniVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var statusBar: StatusBarController
    @StateObject private var systemVolume: SystemVolume
    @StateObject private var library: MusicLibrary
    @StateObject private var shortcuts: PlaybackShortcutController
    @StateObject private var windowToggle: WindowToggleController
    @StateObject private var desktopLyrics: DesktopLyricsController
    @StateObject private var lyricsSync: LyricsSyncCoordinator
    @AppStorage private var appearance: String

    init() {
        // Migrate before any controller or AppStorage reads the new domain.
        PreferencesMigration.runIfNeeded()
        _statusBar = StateObject(wrappedValue: StatusBarController())
        let playbackLibrary = MusicLibrary()
        let volumeController = SystemVolume()
        volumeController.connect(library: playbackLibrary)
        _systemVolume = StateObject(wrappedValue: volumeController)
        _library = StateObject(wrappedValue: playbackLibrary)
        _shortcuts = StateObject(wrappedValue: PlaybackShortcutController())
        _windowToggle = StateObject(wrappedValue: WindowToggleController())
        _desktopLyrics = StateObject(wrappedValue: DesktopLyricsController())
        _lyricsSync = StateObject(wrappedValue: LyricsSyncCoordinator())
        _appearance = AppStorage(wrappedValue: AppAppearance.system.rawValue, "MiniVoice.appearance")
    }

    var body: some Scene {
        Window("MiniVoice", id: "main") {
            ContentView(statusBar: statusBar)
                .environmentObject(library)
                .environmentObject(library.clock)
                .environmentObject(systemVolume)
                .environmentObject(shortcuts)
                .environmentObject(windowToggle)
                .environmentObject(desktopLyrics)
                .environmentObject(lyricsSync)
                .background(WindowCloseObserver(library: library))
                .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
                .onAppear {
                    shortcuts.connect(library: library)
                    desktopLyrics.connect(library: library)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandMenu("播放") {
                Button(library.isPlaying ? "暂停" : "播放") { library.togglePlayback() }.disabled(library.selectedTrack == nil)
                Button("上一曲") { library.skip(-1) }.disabled(library.selectedTrack == nil)
                Button("下一曲") { library.skip(1) }.disabled(library.selectedTrack == nil)
            }
        }
        Settings {
            AppSettings()
                .environmentObject(lyricsSync)
                .environmentObject(library)
                .environmentObject(library.clock)
                .environmentObject(systemVolume)
                .environmentObject(shortcuts)
                .environmentObject(windowToggle)
                .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
        }
    }
}
