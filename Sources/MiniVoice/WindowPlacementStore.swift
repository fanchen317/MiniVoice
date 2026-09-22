import Foundation

/// Uses desktop coordinates across all displays, independent of the active screen.
struct WindowPlacementStore {
    let key: String
    var defaults: UserDefaults = .standard

    func load() -> CGRect? {
        guard let values = defaults.array(forKey: key) as? [Double], values.count == 4 else { return nil }
        let frame = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
        return Self.isValid(frame) ? frame : nil
    }

    func save(_ frame: CGRect) {
        guard Self.isValid(frame) else { return }
        defaults.set([Double(frame.minX), Double(frame.minY), Double(frame.width), Double(frame.height)], forKey: key)
    }

    static func isValid(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite && frame.origin.y.isFinite && frame.size.width.isFinite && frame.size.height.isFinite
            && frame.size.width > 0 && frame.size.height > 0
    }

    static func visibleFrame(_ frame: CGRect, screens: [CGRect]) -> CGRect {
        guard isValid(frame), let fallback = screens.first else { return frame }
        // Preserve intentional partial overlap if the window can still be dragged.
        let handle = CGRect(x: frame.minX, y: frame.maxY - min(28, frame.height), width: frame.width, height: min(28, frame.height))
        if screens.contains(where: {
            let intersection = $0.intersection(handle)
            return intersection.width >= min(80, frame.width) && intersection.height >= handle.height
        }) { return frame }

        // A disconnected display or changed resolution must not strand the window.
        let target = screens.max {
            area($0.intersection(frame)) < area($1.intersection(frame))
        }.flatMap { area($0.intersection(frame)) > 0 ? $0 : nil } ?? fallback
        var result = frame
        result.origin.x = max(target.minX, min(frame.minX, target.maxX - frame.width))
        result.origin.y = max(target.minY, min(frame.minY, target.maxY - frame.height))
        if frame.height > target.height { result.origin.y = target.maxY - frame.height }
        return result
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }
}
