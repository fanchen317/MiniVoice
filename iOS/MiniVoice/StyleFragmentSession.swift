import UIKit

/// The same shared curl samples as Android, animated on UIKit snapshot layers.
/// No WKWebView.takeSnapshot, pixel readback, JPEG encoding or JS image upload.
@MainActor
final class StyleFragmentSession {
    private var overlay: UIView?
    private var token: String?
    private var cells: [[String: Any]] = []
    private var timeout: DispatchWorkItem?
    private var completion: (() -> Void)?

    func prepare(in view: UIView, cells: [[String: Any]]) -> String? {
        cancel()
        guard view.window != nil, !cells.isEmpty, cells.count <= 24 else { return nil }
        let surface = UIView(frame: view.bounds)
        surface.isUserInteractionEnabled = false
        surface.accessibilityElementsHidden = true
        for cell in cells {
            guard let x = cell["x"] as? Double, let y = cell["y"] as? Double,
                  let w = cell["width"] as? Double, let h = cell["height"] as? Double,
                  [x,y,w,h].allSatisfy(\.isFinite), w > 0, h > 0,
                  let frames = cell["frames"] as? [[String: Double]], frames.count == 17 else { return nil }
            let rect = CGRect(x: x, y: y, width: w, height: h)
            guard view.bounds.insetBy(dx: -1, dy: -1).contains(rect),
                  let tile = view.resizableSnapshotView(from: rect, afterScreenUpdates: false, withCapInsets: .zero) else { return nil }
            tile.frame = rect
            surface.addSubview(tile)
        }
        // Add only after all samples are captured, so no fragment captures its siblings.
        view.addSubview(surface)
        let id = UUID().uuidString
        overlay = surface; token = id; self.cells = cells
        let expiry = DispatchWorkItem { [weak self] in self?.cancel() }
        timeout = expiry
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: expiry)
        return id
    }

    func animate(_ id: String, completion: @escaping () -> Void) {
        guard token == id, let overlay else { completion(); return }
        self.completion = completion
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in if self?.token == id { self?.cancel() } }
        for (tile, cell) in zip(overlay.subviews, cells) {
            guard let frames = cell["frames"] as? [[String: Double]] else { continue }
            let transform = CAKeyframeAnimation(keyPath: "transform")
            transform.values = frames.map { sample in
                let matrix = CGAffineTransform(translationX: sample["dx"] ?? 0, y: sample["dy"] ?? 0)
                    .rotated(by: (sample["angle"] ?? 0) * .pi / 180)
                    .scaledBy(x: sample["scale"] ?? 1, y: sample["scale"] ?? 1)
                return NSValue(caTransform3D: CATransform3DMakeAffineTransform(matrix))
            }
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = frames.map { $0["opacity"] ?? 1 }
            let times = frames.map { NSNumber(value: $0["offset"] ?? 0) }
            transform.keyTimes = times; opacity.keyTimes = times
            let group = CAAnimationGroup()
            group.animations = [transform, opacity]; group.duration = 0.48
            group.beginTime = CACurrentMediaTime() + min(0.2, max(0, (cell["delay"] as? Double ?? 0) / 1000))
            group.fillMode = .both; group.isRemovedOnCompletion = false
            tile.layer.add(group, forKey: "MiniVoice.styleFragments")
        }
        CATransaction.commit()
    }

    func cancel(_ id: String? = nil) {
        guard id == nil || token == id else { return }
        timeout?.cancel(); timeout = nil
        let done = completion; completion = nil
        token = nil; cells = []; overlay?.removeFromSuperview(); overlay = nil
        done?()
    }
}
