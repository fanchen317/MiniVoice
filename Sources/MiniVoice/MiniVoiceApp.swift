import SwiftUI

@main
struct MiniVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var statusBar = StatusBarController()
    @StateObject private var systemVolume = SystemVolume()
    @StateObject private var library = MusicLibrary()
    @StateObject private var shortcuts = PlaybackShortcutController()
    @StateObject private var windowToggle = WindowToggleController()
    @StateObject private var desktopLyrics = DesktopLyricsController()
    @StateObject private var lyricsSync = LyricsSyncCoordinator()
    @AppStorage("MiniVoice.appearance") private var appearance = AppAppearance.system.rawValue

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
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
                .onAppear {
                    shortcuts.connect(library: library)
                    desktopLyrics.connect(library: library)
                }
        }
        .windowStyle(.hiddenTitleBar)
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
