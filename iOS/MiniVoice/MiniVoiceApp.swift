import SwiftUI

@main
struct MiniVoiceApp: App {
    @StateObject private var library = MusicLibrary()
    @StateObject private var player = MusicPlayer()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(library)
                .environmentObject(player)
                .preferredColorScheme(.dark)
                .onAppear { library.restoreAndScan() }
        }
    }
}
