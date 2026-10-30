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

/// Pure viewport math shared by gesture preview and commit. The anchor is in viewport points.
struct WallCamera {
    var offset: CGPoint
    var scale: CGFloat

    func zoomed(to requestedScale: CGFloat, around anchor: CGPoint) -> WallCamera {
        let next = min(1.2, max(0.6, requestedScale.isFinite ? requestedScale : 1))
        let previous = min(1.2, max(0.6, scale.isFinite ? scale : 1))
        let ratio = next / previous
        return WallCamera(offset: CGPoint(x: anchor.x - (anchor.x - offset.x) * ratio,
                                          y: anchor.y - (anchor.y - offset.y) * ratio), scale: next)
    }
}

/// Geometry rules for controls, independent of SwiftUI rendering.
enum WallControlMetrics {
    static func dockWidth(viewport: CGFloat) -> CGFloat {
        // 16pt edges, 12pt gap and 46pt settings target remain outside the dock.
        max(48, min(420, viewport - 90))
    }

    static func seekTime(x: CGFloat, width: CGFloat, duration: Double) -> Double? {
        guard width.isFinite, width > 0, x.isFinite, duration.isFinite, duration > 0 else { return nil }
        return Double(min(1, max(0, x / width))) * duration
    }
}

/// iOS layout parity with the original wall: transform shared cell edges before
/// subtracting gutters. Mapping each rectangle independently would create gaps.
enum NativeWallReflow {
    static func frame(_ frame: CGRect, focus: CGRect?, size: CGSize, gap: CGFloat = 5) -> CGRect {
        guard let focus else { return frame }
        func coordinate(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat, _ length: CGFloat) -> CGFloat {
            let target = max(1, length), delta = (target - (upper - lower)) / 2
            if value <= lower { return value - delta }
            if value >= upper { return value + delta }
            return lower - delta + (value - lower) * target / (upper - lower)
        }
        let x = coordinate(frame.minX, focus.minX, focus.maxX + gap, size.width + gap)
        let right = coordinate(frame.maxX + gap, focus.minX, focus.maxX + gap, size.width + gap)
        let y = coordinate(frame.minY, focus.minY, focus.maxY + gap, size.height + gap)
        let bottom = coordinate(frame.maxY + gap, focus.minY, focus.maxY + gap, size.height + gap)
        return CGRect(x: x, y: y, width: right - x - gap, height: bottom - y - gap)
    }

    static func query(camera: WallCamera, viewport: CGSize, focus: CGRect?, size: CGSize, overscan: CGFloat) -> CGRect {
        func inverse(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat, _ length: CGFloat) -> CGFloat {
            let target = max(1, length), span = upper - lower, delta = (target - span) / 2
            if value <= lower - delta { return value + delta }
            if value >= upper + delta { return value - delta }
            return lower + (value - lower + delta) * span / target
        }
        var left = (-camera.offset.x - overscan) / camera.scale
        var right = (viewport.width - camera.offset.x + overscan) / camera.scale
        var top = (-camera.offset.y - overscan) / camera.scale
        var bottom = (viewport.height - camera.offset.y + overscan) / camera.scale
        if let focus {
            left = inverse(left, focus.minX, focus.maxX + 5, size.width + 5)
            right = inverse(right, focus.minX, focus.maxX + 5, size.width + 5)
            top = inverse(top, focus.minY, focus.maxY + 5, size.height + 5)
            bottom = inverse(bottom, focus.minY, focus.maxY + 5, size.height + 5)
        }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}

extension WeightedWallScene {
    func visibleReflow(camera: WallCamera, viewport: CGSize, focus: CGRect?, size: CGSize, overscan: CGFloat = 220) -> [Instance] {
        let query = NativeWallReflow.query(camera: camera, viewport: viewport, focus: focus, size: size, overscan: overscan)
        return visible(cameraX: -query.minX * camera.scale, cameraY: -query.minY * camera.scale, scale: camera.scale,
                       viewport: CGSize(width: query.width * camera.scale, height: query.height * camera.scale), overscan: 0)
    }
}

/// Same free-region budget as mobileWallViewport, measured from the UIKit host
/// so a transient WebKit layout during rotation cannot relocate the camera.
struct NativeWallViewport {
    let center: CGPoint
    let side: CGFloat
    init(size: CGSize, top: CGFloat, right: CGFloat, bottom: CGFloat, left: CGFloat) {
        let width = max(1, size.width - left - right), landscape = size.width > size.height
        let dockWidth = min(440, landscape ? min(size.height - 28, width * 0.48) : width - 28)
        let leading = landscape ? left + 16 + dockWidth + 16 : left
        let trailing = landscape ? size.width - right - 14 - 56 - 16 : size.width - right
        let available = max(120, trailing - leading)
        let upper = top + (landscape ? 12 : 80)
        let lower = size.height - bottom - (landscape ? 12 : 114)
        side = max(120, min(520, available - 12, lower - upper - 12))
        center = CGPoint(x: (leading + trailing) / 2, y: (upper + lower) / 2)
    }
}
