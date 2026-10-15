import Foundation

// MusicWallLayout.swift: bounded mosaic bands allow offscreen artwork to stay unmounted.
struct MusicWallTile: Identifiable {
    let index: Int
    let frame: CGRect
    var slot: Int? = nil
    var id: Int { slot ?? index }
}

struct MusicWallBand: Identifiable {
    let id: Int
    var tiles: [MusicWallTile]
}

struct MusicWallLayout {
    let bands: [MusicWallBand]
    let bandHeight: CGFloat
    let gap: CGFloat = 5

    /// Reserve the playing poster first, then pack mixed portrait/landscape covers around it.
    init(count: Int, activeIndex: Int?, width: CGFloat, density: CGFloat = 1) {
        guard count > 0, width.isFinite, width > 0 else { bands = []; bandHeight = 0; return }
        let gap: CGFloat = 5
        let columns = max(3, min(12, Int(width / (160 * max(0.6, min(1.4, density))))))
        let unit = (width + gap) / CGFloat(columns)
        bandHeight = unit * 3 - gap
        var occupied: [[Bool]] = []
        var output: [[MusicWallTile]] = []
        func ensure(_ band: Int) {
            while occupied.count <= band {
                occupied.append(Array(repeating: false, count: columns * 3)); output.append([])
            }
        }
        func fits(_ band: Int, _ x: Int, _ y: Int, _ w: Int, _ h: Int) -> Bool {
            guard x + w <= columns, y + h <= 3 else { return false }
            return (y..<(y + h)).allSatisfy { row in
                (x..<(x + w)).allSatisfy { !occupied[band][row * columns + $0] }
            }
        }
        func place(_ index: Int, _ band: Int, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
            for row in y..<(y + h) { for col in x..<(x + w) { occupied[band][row * columns + col] = true } }
            output[band].append(MusicWallTile(index: index, frame: CGRect(
                x: CGFloat(x) * unit, y: CGFloat(y) * unit,
                width: CGFloat(w) * unit - gap, height: CGFloat(h) * unit - gap)))
        }
        let active = activeIndex.flatMap { (0..<count).contains($0) ? $0 : nil }
        if let active {
            let band = active / max(1, columns * 2)
            ensure(band)
            place(active, band, (columns - 3) / 2, 0, 3, 3)
        }
        var firstBand = 0
        for index in 0..<count where index != active {
            let span: (Int, Int)
            // Alternate complete runs of square, portrait and landscape slots rather
            // than repeating one visual rhythm across the whole library.
            let phase = (index / 18) % 3
            let position = index % 18
            if phase == 0 {
                switch position {
                case 0, 8: span = (2, 2)
                case 3, 12: span = (1, 2)
                case 5, 15: span = (2, 1)
                default: span = (1, 1)
                }
            } else if phase == 1 {
                switch position {
                case 0: span = (3, 2)
                case 2, 10: span = (1, 3)
                case 5, 11: span = (2, 2)
                case 6, 14: span = (2, 1)
                default: span = (1, 1)
                }
            } else {
                switch position {
                case 0, 12: span = (2, 3)
                case 4, 8: span = (3, 1)
                case 3, 11: span = (1, 2)
                default: span = (1, 1)
                }
            }
            var band = firstBand
            search: while true {
                ensure(band)
                for y in 0..<3 { for x in 0..<columns {
                    if fits(band, x, y, span.0, span.1) {
                        place(index, band, x, y, span.0, span.1); break search
                    }
                } }
                band += 1
            }
            while firstBand < occupied.count && occupied[firstBand].allSatisfy({ $0 }) { firstBand += 1 }
        }
        // Keep unused terminal cells empty: filling them with earlier songs creates
        // nearby duplicates and makes a song's location unpredictable.
        bands = output.enumerated().map { MusicWallBand(id: $0.offset, tiles: $0.element) }
    }
}
