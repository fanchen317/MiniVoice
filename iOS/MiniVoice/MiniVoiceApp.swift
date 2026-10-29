import SwiftUI

@main
struct MiniVoiceApp: App {
    @StateObject private var library = MusicLibrary()
    @StateObject private var player = MusicPlayer()

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("ios.appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            SharedPlayerView()
                .environmentObject(library)
                .environmentObject(player)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "light" ? .light : .dark)
                .onOpenURL { url in if url.scheme == "minivoice", url.host == "playing" { player.requestNavigation() } }
                .onChange(of: scenePhase) { old, new in
                    IOSDiagnostics.shared.record(.event, "scene state=\(new)")
                    if new == .active {
                        library.restoreAndScan()
                        if old == .background, player.current != nil { player.requestNavigation() }
                    }
                }
                .onAppear {
                    IOSDiagnostics.shared.start()
                    library.restoreAndScan()
                    #if targetEnvironment(simulator)
                    if ProcessInfo.processInfo.arguments.contains("--mv-ui-fixture"), let song = library.songs.first {
                        player.play(song, queue: library.songs, library: library)
                        player.pause()
                    }
                    #endif
                }
        }
    }
}
