import Foundation

@main
struct WeightedWallSceneTests {
    static func main() {
        let scene = WeightedWallScene(count: 128)
        precondition(scene.tiles.count == 128)
        precondition(Set(scene.tiles.map(\.index)).count == 128)
        precondition(scene.tiles.allSatisfy { $0.frame.width > 0 && $0.frame.height > 0 })
        let visible = scene.visible(cameraX: 12, cameraY: 40, scale: 1,
                                    viewport: CGSize(width: 390, height: 740))
        precondition(!visible.isEmpty)
        precondition(visible.allSatisfy { $0.tile.index >= 0 && $0.tile.index < 128 })
        let shifted = scene.visible(cameraX: scene.width + 12, cameraY: 40, scale: 1,
                                    viewport: CGSize(width: 390, height: 740))
        precondition(Set(visible.map { $0.tile.index }) == Set(shifted.map { $0.tile.index }))
        let focus = CGRect(x: 100, y: 50, width: 95, height: 195)
        let square = CGSize(width: 300, height: 300)
        let mapped = NativeWallReflow.frame(focus, focus: focus, size: square)
        precondition(abs(mapped.width - 300) < 0.001 && abs(mapped.height - 300) < 0.001)
        precondition(abs(mapped.midX - focus.midX) < 0.001 && abs(mapped.midY - focus.midY) < 0.001)
        let right = NativeWallReflow.frame(CGRect(x: 200, y: 50, width: 95, height: 195), focus: focus, size: square)
        precondition(abs(right.minX - mapped.maxX - 5) < 0.001, "reflow preserves shared gutter")
        let below = NativeWallReflow.frame(CGRect(x: 100, y: 250, width: 195, height: 95), focus: focus, size: square)
        precondition(abs(below.minY - mapped.maxY - 5) < 0.001)
        let large = WeightedWallScene(count: 1037)
        let chosen = large.tiles[100].frame
        for scale: CGFloat in [0.6, 1, 1.2] {
            for delta: CGFloat in [-550, 0, 550] {
                let camera = WallCamera(offset: CGPoint(x: 195 - chosen.midX * scale + delta,
                                                        y: 370 - chosen.midY * scale), scale: scale)
                let viewport = CGSize(width: 390, height: 740)
                let found = large.visibleReflow(camera: camera, viewport: viewport, focus: chosen, size: square, overscan: 0)
                var expected = Set<String>()
                for row in -1...1 { for column in -1...1 { for tile in large.tiles {
                    let base = tile.frame.offsetBy(dx: CGFloat(column) * large.width, dy: CGFloat(row) * large.height)
                    let frame = NativeWallReflow.frame(base, focus: chosen, size: square)
                    let projected = CGRect(x: camera.offset.x + frame.minX * scale, y: camera.offset.y + frame.minY * scale,
                                           width: frame.width * scale, height: frame.height * scale)
                    if projected.intersects(CGRect(origin: .zero, size: viewport)) { expected.insert("\(tile.index):\(column):\(row)") }
                } } }
                let actual = Set(found.filter {
                    let frame = NativeWallReflow.frame($0.frame, focus: chosen, size: square)
                    return CGRect(x: camera.offset.x + frame.minX * scale, y: camera.offset.y + frame.minY * scale,
                                  width: frame.width * scale, height: frame.height * scale).intersects(CGRect(origin: .zero, size: viewport))
                }.map(\.id))
                precondition(actual == expected, "inverse visibility must not cull reflowed covers")
            }
        }
        let portrait = NativeWallViewport(size: CGSize(width: 390, height: 844), top: 44, right: 0, bottom: 34, left: 0)
        precondition(portrait.center == CGPoint(x: 195, y: 410) && portrait.side == 378)
        let landscape = NativeWallViewport(size: CGSize(width: 844, height: 390), top: 0, right: 44, bottom: 21, left: 44)
        precondition(abs(landscape.center.x - 576) < 0.001 && abs(landscape.center.y - 184.5) < 0.001 && abs(landscape.side - 264) < 0.001)
        print("PASS: native square reflow, shared gutters and 1037-cover inverse visibility at three scales")
        print("PASS: iOS 加权音乐墙分区、可见区域和周期重复")
    }
}
