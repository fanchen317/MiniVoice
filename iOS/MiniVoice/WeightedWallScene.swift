import CoreGraphics
import Foundation

/// The same weighted, repeatable partition used by Android's WallLayout.
struct WeightedWallScene {
    struct Tile {
        let index: Int
        let frame: CGRect
    }

    struct Instance: Identifiable {
        let tile: Tile
        let column: Int
        let row: Int
        let frame: CGRect
        var id: String { "\(tile.index):\(column):\(row)" }
    }

    let width: CGFloat
    let height: CGFloat
    let tiles: [Tile]
    private let bucket: CGFloat = 640
    private let buckets: [Int64: [Int]]

    init(count: Int) {
        guard count > 0 else {
            width = 1
            height = 1
            tiles = []
            buckets = [:]
            return
        }
        let pattern = [2, 1, 1, 3, 1, 2, 1, 1, 2, 4, 1, 2]
        var sums = [CGFloat](repeating: 0, count: count + 1)
        for index in 0..<count { sums[index + 1] = sums[index] + CGFloat(pattern[index % pattern.count]) }
        let area = sums[count] * 180 * 180
        width = sqrt(area * 1.6)
        height = sqrt(area / 1.6)
        var output: [Tile] = []
        output.reserveCapacity(count)
        func divide(_ first: Int, _ end: Int, _ frame: CGRect) {
            if end - first == 1 {
                output.append(Tile(index: first, frame: CGRect(x: frame.minX, y: frame.minY,
                                                               width: max(1, frame.width - 5), height: max(1, frame.height - 5))))
                return
            }
            let middle = first + (end - first) / 2
            let fraction = (sums[middle] - sums[first]) / (sums[end] - sums[first])
            if frame.width >= frame.height {
                let firstWidth = frame.width * fraction
                divide(first, middle, CGRect(x: frame.minX, y: frame.minY, width: firstWidth, height: frame.height))
                divide(middle, end, CGRect(x: frame.minX + firstWidth, y: frame.minY,
                                           width: frame.width - firstWidth, height: frame.height))
            } else {
                let firstHeight = frame.height * fraction
                divide(first, middle, CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: firstHeight))
                divide(middle, end, CGRect(x: frame.minX, y: frame.minY + firstHeight,
                                           width: frame.width, height: frame.height - firstHeight))
            }
        }
        divide(0, count, CGRect(x: 0, y: 0, width: width, height: height))
        tiles = output.sorted { $0.index < $1.index }
        var index: [Int64: [Int]] = [:]
        for tile in tiles {
            for y in Int(floor(tile.frame.minY / bucket))...Int(floor(tile.frame.maxY / bucket)) {
                for x in Int(floor(tile.frame.minX / bucket))...Int(floor(tile.frame.maxX / bucket)) {
                    index[Self.key(x, y), default: []].append(tile.index)
                }
            }
        }
        buckets = index
    }

    func visible(cameraX: CGFloat, cameraY: CGFloat, scale: CGFloat, viewport: CGSize, overscan: CGFloat = 150) -> [Instance] {
        guard !tiles.isEmpty, scale > 0, viewport.width > 0, viewport.height > 0 else { return [] }
        let left = (-cameraX - overscan) / scale
        let right = (viewport.width - cameraX + overscan) / scale
        let top = (-cameraY - overscan) / scale
        let bottom = (viewport.height - cameraY + overscan) / scale
        var output: [Instance] = []
        for row in Int(floor(top / height))...Int(floor(bottom / height)) {
            for column in Int(floor(left / width))...Int(floor(right / width)) {
                let localLeft = max(0, left - CGFloat(column) * width)
                let localRight = min(width, right - CGFloat(column) * width)
                let localTop = max(0, top - CGFloat(row) * height)
                let localBottom = min(height, bottom - CGFloat(row) * height)
                guard localRight >= localLeft, localBottom >= localTop else { continue }
                var candidateIndices = Set<Int>()
                for y in Int(floor(localTop / bucket))...Int(floor(localBottom / bucket)) {
                    for x in Int(floor(localLeft / bucket))...Int(floor(localRight / bucket)) {
                        candidateIndices.formUnion(buckets[Self.key(x, y)] ?? [])
                    }
                }
                for index in candidateIndices.sorted() {
                    let tile = tiles[index]
                    guard tile.frame.maxX > localLeft, tile.frame.minX < localRight,
                          tile.frame.maxY > localTop, tile.frame.minY < localBottom else { continue }
                    output.append(Instance(tile: tile, column: column, row: row,
                                           frame: tile.frame.offsetBy(dx: CGFloat(column) * width, dy: CGFloat(row) * height)))
                }
            }
        }
        return output
    }

    private static func key(_ x: Int, _ y: Int) -> Int64 {
        (Int64(x) << 32) ^ Int64(UInt32(truncatingIfNeeded: y))
    }
}
