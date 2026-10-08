import Foundation

/// Keep the same controls mounted while the window resizes. Side content first
/// narrows to make room, then moves up beside the centered transport buttons.
struct PlayerControlsGeometry {
    let height: CGFloat
    let artworkSize: CGFloat
    let buttonSpacing: CGFloat
    let progress: CGRect
    let buttons: CGRect
    let song: CGRect
    let output: CGRect

    init(width: CGFloat, songIdealWidth: CGFloat? = nil) {
        let width = max(280, width)
        let inset: CGFloat = 12
        let innerWidth = width - inset * 2
        let buttonsWidth = min(300, innerWidth)
        let sideWidth = max(0, (width - buttonsWidth) / 2 - inset * 2)
        let sideProgress = Self.smoothStep((width - 620) / 100)
        let rowProgress = Self.smoothStep((width - 720) / 120)
        let narrowOutputWidth = min(180, max(110, width * 0.27))
        let outputWidth = Self.mix(narrowOutputWidth, min(200, sideWidth), sideProgress)
        let narrowSongWidth = min(280, innerWidth - narrowOutputWidth - 16)
        let songLimit = Self.mix(narrowSongWidth, min(240, sideWidth), sideProgress)
        let songWidth = min(songLimit, songIdealWidth ?? songLimit)

        height = Self.mix(176, 124, rowProgress)
        artworkSize = 44 + 14 * Self.smoothStep((width - 280) / 260)
        // Four 36pt targets plus the 52pt primary button.
        buttonSpacing = (buttonsWidth - 36 * 4 - 52) / 4
        progress = CGRect(x: inset, y: inset, width: innerWidth, height: 22)
        let rowCenter = height - inset - 29
        let buttonsCenter = Self.mix(70, 83, rowProgress)
        // Balance the visible gaps, not reserved columns. Short song titles
        // occupy less space than a volume slider plus output-device name.
        let horizontalOffset = (songWidth - outputWidth) * rowProgress / 2
        buttons = CGRect(x: (width - buttonsWidth) / 2 + horizontalOffset, y: buttonsCenter - 26,
                         width: buttonsWidth, height: 52)
        song = CGRect(x: inset, y: rowCenter - 29, width: songWidth, height: 58)
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
