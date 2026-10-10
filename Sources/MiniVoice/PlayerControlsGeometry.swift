import Foundation

/// Keep the same controls mounted while the window resizes. Side content first
/// narrows to make room, then moves up beside the progress/transport column.
struct PlayerControlsGeometry {
    let height: CGFloat
    let artworkSize: CGFloat
    let buttonSpacing: CGFloat
    let progress: CGRect
    let buttons: CGRect
    let song: CGRect
    let output: CGRect

    init(width: CGFloat, expanded: Bool = false) {
        let width = max(280, width)
        let inset: CGFloat = 12
        let innerWidth = width - inset * 2
        let buttonsWidth = min(300, innerWidth)
        let sideWidth = max(0, (width - buttonsWidth) / 2 - inset * 2)
        let sideProgress = Self.smoothStep((width - 620) / 100)
        let rowProgress = Self.smoothStep((width - 720) / 120)
        let narrowOutputWidth = min(180, max(110, width * 0.27))
        let outputWidth = Self.mix(narrowOutputWidth, min(240, sideWidth), sideProgress)
        let narrowSongWidth = min(280, innerWidth - narrowOutputWidth - 16)
        let songLimit = Self.mix(narrowSongWidth, min(240, sideWidth), sideProgress)
        let songWidth = songLimit

        artworkSize = 44 + (expanded ? 38 : 14) * Self.smoothStep((width - 280) / 260)
        let songHeight = max(58, artworkSize)
        height = Self.mix(176 + songHeight - 58, 106, rowProgress)
        // Four 36pt targets plus the 52pt primary button.
        buttonSpacing = (buttonsWidth - 36 * 4 - 52) / 4
        let rowCenter = Self.mix(height - inset - songHeight / 2, height / 2, rowProgress)
        let buttonsCenter = Self.mix(70, 68, rowProgress)
        // Keep the center stable regardless of the song title's length.
        buttons = CGRect(x: (width - buttonsWidth) / 2, y: buttonsCenter - 26,
                         width: buttonsWidth, height: 52)
        // The timeline belongs to the transport column, including when side
        // content wraps below it in a narrow window.
        progress = CGRect(x: buttons.minX, y: inset, width: buttonsWidth, height: 22)
        song = CGRect(x: inset, y: rowCenter - songHeight / 2, width: songWidth, height: songHeight)
        output = CGRect(x: width - inset - outputWidth, y: rowCenter - 29,
                        width: outputWidth, height: 58)
    }

    private static func smoothStep(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    private static func mix(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}
