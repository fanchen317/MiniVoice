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

        artworkSize = 44 + (expanded ? 52 : 38) * Self.smoothStep((width - 280) / 260)
        let sideHeight = max(58, artworkSize)
        let centerHeight = max(82, artworkSize)
        let regionHeight = Self.mix(sideHeight, centerHeight, rowProgress)
        height = Self.mix(centerHeight + sideHeight + 32, centerHeight + 24, rowProgress)
        // Four 36pt targets plus the 52pt primary button.
        buttonSpacing = (buttonsWidth - 36 * 4 - 52) / 4
        let centerX = (width - buttonsWidth) / 2
        progress = CGRect(x: centerX, y: inset, width: buttonsWidth, height: 22)
        buttons = CGRect(x: centerX, y: inset + centerHeight - 52,
                         width: buttonsWidth, height: 52)
        // All three columns have the same top and bottom in the wide layout.
        let sideY = Self.mix(height - inset - regionHeight, inset, rowProgress)
        song = CGRect(x: inset, y: sideY, width: songWidth, height: regionHeight)
        output = CGRect(x: width - inset - outputWidth, y: sideY,
                        width: outputWidth, height: regionHeight)
    }

    var center: CGRect { progress.union(buttons) }

    private static func smoothStep(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    private static func mix(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}
