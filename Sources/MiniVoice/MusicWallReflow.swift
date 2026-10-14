import Foundation

// MusicWallReflow.swift: monotone space expansion preserves the mosaic's shared edges.
enum MusicWallReflow {
    /// Expand the selected slot in the wall itself. Neighbours share the same mapping,
    /// so no poster covers another and collapsing restores the original coordinates.
    static func frame(_ frame: CGRect, focus: CGRect?, size: CGSize) -> CGRect {
        guard let focus, focus.width > 0, focus.height > 0 else { return frame }
        let x0 = coordinate(frame.minX, lower: focus.minX, upper: focus.maxX, length: size.width)
        let x1 = coordinate(frame.maxX, lower: focus.minX, upper: focus.maxX, length: size.width)
        let y0 = coordinate(frame.minY, lower: focus.minY, upper: focus.maxY, length: size.height)
        let y1 = coordinate(frame.maxY, lower: focus.minY, upper: focus.maxY, length: size.height)
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
    static func interpolate(_ start: CGRect, _ end: CGRect, progress: CGFloat) -> CGRect {
        let p = min(1, max(0, progress))
        return CGRect(x: start.minX + (end.minX - start.minX) * p,
                      y: start.minY + (end.minY - start.minY) * p,
                      width: start.width + (end.width - start.width) * p,
                      height: start.height + (end.height - start.height) * p)
    }
    private static func coordinate(_ value: CGFloat, lower: CGFloat, upper: CGFloat, length: CGFloat) -> CGFloat {
        let delta = (max(1, length) - (upper - lower)) / 2
        if value <= lower { return value - delta }
        if value >= upper { return value + delta }
        return lower - delta + (value - lower) * max(1, length) / (upper - lower)
    }
}
