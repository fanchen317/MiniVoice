import AppKit

/// Native visual effects need their own mask; SwiftUI clipping alone can leave
/// the AppKit backdrop visible outside the panel's rounded contour.
final class RoundedVisualEffectView: NSVisualEffectView {
    var effectCornerRadius: CGFloat = 0 {
        didSet { if effectCornerRadius != oldValue { updateEffectMask() } }
    }
    private var maskedSize: CGSize = .zero

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateEffectMaskIfNeeded()
    }

    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        updateEffectMaskIfNeeded()
    }

    override func layout() {
        super.layout()
        updateEffectMaskIfNeeded()
    }

    private func updateEffectMaskIfNeeded() {
        // SwiftUI can resize the native view without an AppKit layout pass.
        if bounds.size != maskedSize { updateEffectMask() }
    }

    private func updateEffectMask() {
        maskedSize = bounds.size
        wantsLayer = true
        layer?.cornerRadius = effectCornerRadius
        layer?.masksToBounds = effectCornerRadius > 0
        guard effectCornerRadius > 0, bounds.width > 0, bounds.height > 0 else {
            maskImage = nil
            return
        }
        let size = bounds.size
        let radius = min(effectCornerRadius, min(size.width, size.height) / 2)
        maskImage = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
    }
}
