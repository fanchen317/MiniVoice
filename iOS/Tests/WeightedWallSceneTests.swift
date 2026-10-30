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
        print("PASS: iOS 加权音乐墙分区、可见区域和周期重复")
    }
}
