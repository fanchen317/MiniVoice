import AppKit
import SwiftUI

// MusicWallCamera.swift: stable world coordinates, repeated edges and viewport-only mounting.
struct MusicWallInstance: Identifiable {
    let tile: MusicWallTile
    let copyX: Int
    let copyY: Int
    let frame: CGRect
    var id: String { "\(tile.id):\(copyX):\(copyY)" }
}

enum MusicWallCamera {
    static func centeredOffset(frame: CGRect, viewport: CGSize, leadingInset: CGFloat = 0, scale: CGFloat = 1) -> CGSize {
        CGSize(width: (viewport.width + leadingInset) / 2 - frame.midX * scale,
               height: max(0, viewport.height - 100) / 2 - frame.midY * scale + 24)
    }

    /// Repeat complete wall units at the edges; dragging never exposes a blank canvas.
    static func visibleInstances(tiles: [MusicWallTile], world: CGSize, viewport: CGSize,
                                 offset: CGSize, focusedID: String?) -> [MusicWallInstance] {
        guard world.width > 0, world.height > 0, viewport.width > 0, viewport.height > 0 else { return [] }
        let visible = CGRect(x: -offset.width, y: -offset.height,
                             width: viewport.width, height: viewport.height).insetBy(dx: -500, dy: -500)
        var result: [MusicWallInstance] = []
        for y in Int(floor(visible.minY / world.height))...Int(floor(visible.maxY / world.height)) {
            for x in Int(floor(visible.minX / world.width))...Int(floor(visible.maxX / world.width)) {
                for tile in tiles {
                    let frame = tile.frame.offsetBy(dx: CGFloat(x) * world.width, dy: CGFloat(y) * world.height)
                    let instance = MusicWallInstance(tile: tile, copyX: x, copyY: y, frame: frame)
                    if frame.intersects(visible) || instance.id == focusedID { result.append(instance) }
                }
            }
        }
        return result
    }
}

/// Native trackpad deltas preserve horizontal/vertical movement and macOS momentum.
struct MusicWallScrollInput: NSViewRepresentable {
    let onScroll: (CGSize, CGPoint) -> Bool
    let onMagnify: (CGFloat, CGPoint) -> Bool
    let onDown: (CGPoint, Int) -> Bool
    let onDrag: (CGSize) -> Void
    let onUp: (CGPoint, Int, Bool) -> Void
    func makeNSView(context: Context) -> ScrollInputView {
        let view = ScrollInputView(); configure(view); return view
    }
    func updateNSView(_ view: ScrollInputView, context: Context) { configure(view) }
    private func configure(_ view: ScrollInputView) {
        view.onScroll = onScroll; view.onMagnify = onMagnify; view.onDown = onDown; view.onDrag = onDrag; view.onUp = onUp
    }
    static func dismantleNSView(_ view: ScrollInputView, coordinator: ()) { view.stop() }

    final class ScrollInputView: NSView {
        var onScroll: ((CGSize, CGPoint) -> Bool)?
        var onMagnify: ((CGFloat, CGPoint) -> Bool)?
        var onDown: ((CGPoint, Int) -> Bool)?
        var onDrag: ((CGSize) -> Void)?
        var onUp: ((CGPoint, Int, Bool) -> Void)?
        private var monitor: Any?
        private var downPoint: CGPoint?
        private var hasDragged = false
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow(); stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify, .leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                let point = self.convert(event.locationInWindow, from: nil)
                switch event.type {
                case .scrollWheel:
                    guard self.bounds.contains(point) else { return event }
                    let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 16
                    let consumed = self.onScroll?(CGSize(width: event.scrollingDeltaX * multiplier,
                        height: event.scrollingDeltaY * multiplier), point) ?? false
                    return consumed ? nil : event
                case .magnify:
                    guard self.bounds.contains(point) else { return event }
                    return self.onMagnify?(event.magnification, point) == true ? nil : event
                case .leftMouseDown:
                    guard self.bounds.contains(point), self.onDown?(point, event.clickCount) == true else { return event }
                    self.downPoint = point; self.hasDragged = false
                    return nil
                case .leftMouseDragged:
                    guard let start = self.downPoint else { return event }
                    let delta = CGSize(width: point.x - start.x, height: point.y - start.y)
                    if hypot(delta.width, delta.height) > 6 { self.hasDragged = true }
                    if self.hasDragged { self.onDrag?(delta) }
                    return nil
                case .leftMouseUp:
                    guard self.downPoint != nil else { return event }
                    self.downPoint = nil
                    self.onUp?(point, event.clickCount, self.hasDragged)
                    self.hasDragged = false
                    return nil
                default: return event
                }
            }
        }
        func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil; downPoint = nil }
    }
}

struct MusicWallGlass: ViewModifier {
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        } else {
            content.background(.ultraThinMaterial, in: shape)
                .overlay { shape.strokeBorder(.white.opacity(0.24), lineWidth: 0.7).allowsHitTesting(false) }
                .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
        }
    }
}
