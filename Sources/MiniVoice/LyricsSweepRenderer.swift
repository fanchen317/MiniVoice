import SwiftUI

enum LyricsSweep {
    static func progress(time: Double, start: Double, end: Double) -> Double {
        guard time.isFinite, start.isFinite, end.isFinite else { return 0 }
        guard end > start else { return time >= start ? 1 : 0 }
        return min(1, max(0, (time - start) / (end - start)))
    }

    /// Interpolate only the visible lyric between the player's 5 Hz samples.
    /// Paused playback and preview sliders always use the supplied exact time.
    static func displayTime(_ time: Double, sampledAt: Date?, now: Date, playing: Bool) -> Double {
        guard playing, let sampledAt else { return time }
        return time + min(0.24, max(0, now.timeIntervalSince(sampledAt)))
    }
}

@available(macOS 15.0, *)
struct LyricSweepAttribute: TextAttribute {
    let index: Int
    let start: Double
    let end: Double
}

/// Clip the bright text at the current glyph, preserving native line wrapping,
/// kerning and font scaling. A word that wraps continues on the following line.
@available(macOS 15.0, *)
struct LyricsSweepRenderer: TextRenderer {
    let time: Double
    let pendingOpacity: Double
    let reduceMotion: Bool

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var widths: [Int: CGFloat] = [:]
        for line in layout {
            for run in line {
                for slice in run {
                    if let timing = slice[LyricSweepAttribute.self] {
                        widths[timing.index, default: 0] += slice.typographicBounds.rect.width
                    }
                }
            }
        }
        var offsets: [Int: CGFloat] = [:]
        for line in layout {
            for run in line {
                for slice in run {
                    guard let timing = slice[LyricSweepAttribute.self] else {
                        context.draw(slice)
                        continue
                    }
                    let bounds = slice.typographicBounds.rect
                    let progress = reduceMotion ? 1 : LyricsSweep.progress(time: time, start: timing.start, end: timing.end)
                    let offset = offsets[timing.index, default: 0]
                    offsets[timing.index] = offset + bounds.width
                    let filled = min(bounds.width, max(0, widths[timing.index, default: 0] * progress - offset))
                    if filled < bounds.width {
                        var pending = context
                        pending.opacity *= pendingOpacity
                        pending.draw(slice, options: .disablesSubpixelQuantization)
                    }
                    if filled > 0 {
                        var bright = context
                        if filled < bounds.width {
                            bright.clip(to: Path(CGRect(x: bounds.minX, y: bounds.minY - 2,
                                                       width: filled, height: bounds.height + 4)))
                        }
                        bright.draw(slice, options: .disablesSubpixelQuantization)
                    }
                }
            }
        }
    }
}
