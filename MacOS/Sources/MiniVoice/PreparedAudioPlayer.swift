import AVFoundation

/// Exclusive ownership moves from the preparation task to the main actor.
/// The worker never touches the player after returning this box.
final class PreparedAudioPlayer: @unchecked Sendable {
    let player: AVAudioPlayer

    init(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        guard player.prepareToPlay() else { throw PreparationError.unavailable }
    }

    static func load(_ url: URL) async throws -> PreparedAudioPlayer {
        try await Task.detached(priority: .userInitiated) {
            try PreparedAudioPlayer(url: url)
        }.value
    }

    private enum PreparationError: Error { case unavailable }
}
