import SwiftUI

@main
struct MiniVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var statusBar = StatusBarController()
    @StateObject private var systemVolume = SystemVolume()
    @StateObject private var library = MusicLibrary()

    var body: some Scene {
        WindowGroup("MiniVoice", id: "main") {
            ContentView(statusBar: statusBar)
                .environmentObject(library)
                .environmentObject(systemVolume)
                .background(WindowCloseObserver(library: library))
                .frame(minWidth: 980, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandMenu("播放") {
                Button(library.isPlaying ? "暂停" : "播放") { library.togglePlayback() }.keyboardShortcut("p", modifiers: .command).disabled(library.selectedTrack == nil)
                Button("上一曲") { library.skip(-1) }.keyboardShortcut(.leftArrow, modifiers: .command).disabled(library.selectedTrack == nil)
                Button("下一曲") { library.skip(1) }.keyboardShortcut(.rightArrow, modifiers: .command).disabled(library.selectedTrack == nil)
            }
        }
        Settings { AppSettings().environmentObject(library) }
    }
}
