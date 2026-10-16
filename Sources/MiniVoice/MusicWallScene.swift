import Foundation

// MusicWallScene.swift: one atomic geometry snapshot is usable on the first render.
struct MusicWallScene {
    let count: Int
    let tiles: [MusicWallTile]
    let world: CGSize
    let horizontalStride: Int
    private let buckets: [String: [Int]]
    private let bucketSide: CGFloat = 640
    init(count: Int, viewport: CGSize, density: CGFloat) {
        self.count = count
        // Partition the entire field, including its final row. Every leaf owns one
        // song; no filler songs or unoccupied blocks are needed at the repeat seam.
        let pattern: [CGFloat] = [2, 1, 1, 3, 1, 2, 1, 1, 2, 4, 1, 2]
        var weights: [CGFloat] = [0]
        for i in 0..<max(0, count) { weights.append(weights.last! + pattern[i % pattern.count]) }
        let unit = 180 * max(0.6, min(1.4, density))
        let area = max(1, weights.last!) * unit * unit
        world = CGSize(width: sqrt(area * 1.6), height: sqrt(area / 1.6))
        var output: [MusicWallTile] = []
        func partition(_ range: Range<Int>, _ rect: CGRect) {
            guard !range.isEmpty else { return }
            if range.count == 1 {
                output.append(MusicWallTile(index: range.lowerBound,
                    frame: CGRect(x: rect.minX, y: rect.minY, width: rect.width - 5, height: rect.height - 5)))
                return
            }
            let middle = range.lowerBound + range.count / 2
            let fraction = (weights[middle] - weights[range.lowerBound]) / (weights[range.upperBound] - weights[range.lowerBound])
            if rect.width >= rect.height {
                let firstWidth = rect.width * fraction
                partition(range.lowerBound..<middle, CGRect(x: rect.minX, y: rect.minY, width: firstWidth, height: rect.height))
                partition(middle..<range.upperBound, CGRect(x: rect.minX + firstWidth, y: rect.minY, width: rect.width - firstWidth, height: rect.height))
            } else {
                let firstHeight = rect.height * fraction
                partition(range.lowerBound..<middle, CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: firstHeight))
                partition(middle..<range.upperBound, CGRect(x: rect.minX, y: rect.minY + firstHeight, width: rect.width, height: rect.height - firstHeight))
            }
        }
        partition(0..<max(0, count), CGRect(origin: .zero, size: world))
        tiles = output
        horizontalStride = 0
        var index: [String: [Int]] = [:]
        for (i, tile) in tiles.enumerated() {
            for y in Int(floor(tile.frame.minY / 640))...Int(floor(tile.frame.maxY / 640)) {
                for x in Int(floor(tile.frame.minX / 640))...Int(floor(tile.frame.maxX / 640)) {
                    index["\(x):\(y)", default: []].append(i)
                }
            }
        }
        buckets = index
    }

    /// Query only nearby spatial buckets; scrolling cost does not grow with the library.
    func visibleInstances(viewport: CGSize, offset: CGSize, focusedID: String?) -> [MusicWallInstance] {
        guard count > 0, viewport.width > 0, viewport.height > 0 else { return [] }
        let visible = CGRect(x: -offset.width, y: -offset.height, width: viewport.width, height: viewport.height)
            .insetBy(dx: -500, dy: -500)
        var result: [MusicWallInstance] = []
        for cy in Int(floor(visible.minY / world.height))...Int(floor(visible.maxY / world.height)) {
            for cx in Int(floor(visible.minX / world.width))...Int(floor(visible.maxX / world.width)) {
                let local = visible.offsetBy(dx: -CGFloat(cx) * world.width, dy: -CGFloat(cy) * world.height)
                    .intersection(CGRect(origin: .zero, size: world))
                guard !local.isNull else { continue }
                var candidates = Set<Int>()
                for y in Int(floor(local.minY / bucketSide))...Int(floor(local.maxY / bucketSide)) {
                    for x in Int(floor(local.minX / bucketSide))...Int(floor(local.maxX / bucketSide)) {
                        candidates.formUnion(buckets["\(x):\(y)"] ?? [])
                    }
                }
                for i in candidates.sorted() where tiles[i].frame.intersects(local) {
                    let tile = tiles[i]
                    result.append(MusicWallInstance(tile: tile, copyX: cx, copyY: cy,
                        frame: tile.frame.offsetBy(dx: CGFloat(cx) * world.width, dy: CGFloat(cy) * world.height)))
                }
            }
        }
        return result
    }
}

struct MusicWallWorkspaceMetrics {
    let sidebarWidth: CGFloat
    let overlaysSidebar: Bool
    let leadingInset: CGFloat

    init(width: CGFloat, sidebarVisible: Bool) {
        sidebarWidth = min(260, max(230, width * 0.25))
        let minimumContentWidth: CGFloat = 540
        overlaysSidebar = width < sidebarWidth + minimumContentWidth + 48
        // Release the reserved space continuously as the window narrows. Changing
        // the sidebar's presentation must not move the wall and dock by half a sidebar.
        leadingInset = sidebarVisible
            ? min(sidebarWidth + 24, max(0, width - minimumContentWidth - 24)) : 0
    }
}

struct MusicWallViewportLayout: Equatable {
    let size: CGSize
    let leadingInset: CGFloat
    var center: CGPoint { CGPoint(x: (size.width + leadingInset) / 2, y: size.height / 2) }
    func displacement(from previous: Self) -> CGSize {
        CGSize(width: center.x - previous.center.x, height: center.y - previous.center.y)
    }
}

struct MusicWallDockMetrics {
    let detailProgress: CGFloat
    var spacing: CGFloat { 8 + 4 * detailProgress }
    var horizontalPadding: CGFloat { 12 + 4 * detailProgress }
    var playButtonSide: CGFloat { 40 + 6 * detailProgress }
    var playButtonFont: CGFloat { 18 + 3 * detailProgress }
    init(width: CGFloat) {
        let progress = min(1, max(0, (width - 340) / 100))
        detailProgress = progress * progress * (3 - 2 * progress)
    }
}

struct MusicWallChromeMetrics {
    let dockWidth: CGFloat
    let toolsAboveDock: Bool
    let toolsBottom: CGFloat
    init(width: CGFloat, leadingInset: CGFloat, toolsLeadingInset: CGFloat? = nil) {
        let available = max(240, width - leadingInset)
        dockWidth = min(460, max(240, available - 40))
        let buttonWidth: CGFloat = 38
        let trailingInset: CGFloat = 16
        let gap: CGFloat = 12
        let sideSpace = (available - dockWidth) / 2
        toolsAboveDock = sideSpace < buttonWidth + trailingInset + gap
        // The dock is 64pt tall, 18pt above the bottom. Keep the button centered
        // beside it, or leave one consistent gap above its top edge.
        toolsBottom = toolsAboveDock ? 18 + 64 + gap : 18 + (64 - buttonWidth) / 2
    }
}
