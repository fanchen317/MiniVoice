import Foundation

/// Keep controls mounted while switching directly between two full rows and
/// three columns. Live resize must never leave partially collapsed rows.
struct PlayerControlsGeometry {
    static let singleRowMinimumWidth: CGFloat = 680
    static let twoRowHeight: CGFloat = 172
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
        let singleRow = width >= Self.singleRowMinimumWidth
        let buttonsWidth = min(300, innerWidth)
        let progressWidth = singleRow ? buttonsWidth : innerWidth
        let sideWidth = singleRow
            ? min(240, (width - buttonsWidth) / 2 - inset * 2)
            : (innerWidth - 16) / 2
        let outputWidth = min(240, sideWidth)
        let songWidth = sideWidth

        // Growing artwork while still in two rows also grew the entire footer.
        // Keep that mode's dimensions fixed; enlarge artwork only in one row.
        artworkSize = singleRow ? (expanded ? 96 : 82) : 44
        let sideHeight = max(58, artworkSize)
        let centerHeight = max(82, artworkSize)
        let regionHeight = singleRow ? centerHeight : sideHeight
        height = singleRow ? centerHeight + 24 : Self.twoRowHeight
        // Four 36pt targets plus the 52pt primary button.
        buttonSpacing = (buttonsWidth - 36 * 4 - 52) / 4
        let centerX = (width - buttonsWidth) / 2
        // Both narrow rows span the available width until all three columns fit.
        let centerY = singleRow ? inset : inset + sideHeight + 8
        progress = CGRect(x: (width - progressWidth) / 2, y: centerY, width: progressWidth, height: 22)
        buttons = CGRect(x: centerX, y: centerY + centerHeight - 52,
                         width: buttonsWidth, height: 52)
        // All three columns have the same top and bottom in the wide layout.
        let sideY = inset
        song = CGRect(x: inset, y: sideY, width: songWidth, height: regionHeight)
        output = CGRect(x: width - inset - outputWidth, y: sideY,
                        width: outputWidth, height: regionHeight)
    }

    var center: CGRect { progress.union(buttons) }

}
