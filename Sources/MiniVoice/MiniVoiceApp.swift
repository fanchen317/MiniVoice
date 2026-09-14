import SwiftUI

@main
struct MiniVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var statusBar = StatusBarController()
    @StateObject private var systemVolume = SystemVolume()
    @StateObject private var library = MusicLibrary()
    @StateObject private var shortcuts = PlaybackShortcutController()

    var body: some Scene {
        WindowGroup("MiniVoice", id: "main") {
            ContentView(statusBar: statusBar)
                .environmentObject(library)
                .environmentObject(systemVolume)
                .environmentObject(shortcuts)
                .background(WindowCloseObserver(library: library))
                .frame(minWidth: 800, minHeight: 600)
                .onAppear { shortcuts.connect(library: library) }
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
                .environmentObject(library)
                .environmentObject(systemVolume)
                .environmentObject(shortcuts)
        }
    }
}
