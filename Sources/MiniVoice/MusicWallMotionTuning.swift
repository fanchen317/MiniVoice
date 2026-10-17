import Foundation

/// Match Folia's measured/reference motion parameters using native camera physics.
/// All durations are seconds, distances are screen points, and velocities points/s.
enum MusicWallMotionTuning {
    static let minimumReleaseSpeed: CGFloat = 40
    static let maximumReleaseSpeed: CGFloat = 4000
    static let releaseProjection: CGFloat = 0.3
    static let releaseTimeConstant: Double = 0.28
    static let staleReleaseInterval: Double = 0.08
    static let wheelTimeConstant: Double = 0.08
    static let maximumWheelFrame: Double = 0.05
    static let restDistance: CGFloat = 0.5
    static let focusDuration: Double = 0.42

    /// Cubic Bezier (0.22, 1, 0.36, 1): brisk start and a gentle, monotonic landing.
    static func focusProgress(_ progress: Double) -> Double {
        guard progress > 0 else { return 0 }
        guard progress < 1 else { return 1 }
        var lower = 0.0, upper = 1.0
        for _ in 0..<18 {
            let t = (lower + upper) / 2
            let inverse = 1 - t
            let x = 3 * inverse * inverse * t * 0.22 + 3 * inverse * t * t * 0.36 + t * t * t
            if x < progress { lower = t } else { upper = t }
        }
        let t = (lower + upper) / 2
        return 1 - pow(1 - t, 3)
    }

    /// Analytic unit-mass spring: stiffness 300, damping 34, initially at rest.
    static func reflowProgress(_ elapsed: Double) -> Double {
        guard elapsed > 0 else { return 0 }
        guard elapsed < 0.52 else { return 1 }
        let frequency = sqrt(11.0)
        return min(1, max(0, 1 - exp(-17 * elapsed)
            * (cos(frequency * elapsed) + 17 / frequency * sin(frequency * elapsed))))
    }
}
