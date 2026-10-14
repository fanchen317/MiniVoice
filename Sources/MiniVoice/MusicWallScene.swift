import Foundation

// MusicWallScene.swift: one atomic geometry snapshot is usable on the first render.
struct MusicWallScene {
    let count: Int
    let tiles: [MusicWallTile]
    let world: CGSize
    let horizontalStride: Int
    init(count: Int, viewport: CGSize, density: CGFloat) {
        self.count = count
        let width: CGFloat = 1920
        let layout = MusicWallLayout(count: count, activeIndex: nil, width: width, density: density)
        tiles = layout.bands.flatMap { band in
            band.tiles.map { MusicWallTile(index: $0.index,
                frame: $0.frame.offsetBy(dx: 0, dy: CGFloat(band.id) * (layout.bandHeight + layout.gap)), slot: $0.slot) }
        }
        world = CGSize(width: width + layout.gap,
                       height: max(1, CGFloat(layout.bands.count) * (layout.bandHeight + layout.gap)))
        var stride = max(1, layout.bands.first?.tiles.filter { $0.slot == nil }.count ?? 1)
        while count > 1 && Self.gcd(stride, count) != 1 { stride += 1 }
        horizontalStride = stride
    }
    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = a, y = b
        while y != 0 { let next = x % y; x = y; y = next }
        return x
    }
}

struct MusicWallChromeMetrics {
    let dockWidth: CGFloat
    let toolsAboveDock: Bool
    let toolsBottom: CGFloat
    init(width: CGFloat, leadingInset: CGFloat) {
        let available = max(240, width - leadingInset)
        dockWidth = min(460, max(240, available - 40))
        toolsAboveDock = (available - dockWidth) / 2 < 130
        toolsBottom = toolsAboveDock ? 104 : 20
    }
}
