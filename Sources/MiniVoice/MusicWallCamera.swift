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
               height: viewport.height / 2 - frame.midY * scale)
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
    let onPointer: (CGPoint?) -> Void
    let onScroll: (CGSize, CGPoint) -> Bool
    let onMagnify: (CGFloat, CGPoint) -> Bool
    let onDown: (CGPoint, Int) -> Bool
    let onDrag: (CGSize) -> Void
    let onUp: (CGPoint, Int, Bool, CGSize) -> Void
    func makeNSView(context: Context) -> ScrollInputView {
        let view = ScrollInputView(); configure(view); return view
    }
    func updateNSView(_ view: ScrollInputView, context: Context) { configure(view) }
    private func configure(_ view: ScrollInputView) {
        view.onPointer = onPointer; view.onScroll = onScroll; view.onMagnify = onMagnify; view.onDown = onDown; view.onDrag = onDrag; view.onUp = onUp
    }
    static func dismantleNSView(_ view: ScrollInputView, coordinator: ()) { view.stop() }

    final class ScrollInputView: NSView {
        var onPointer: ((CGPoint?) -> Void)?
        var onScroll: ((CGSize, CGPoint) -> Bool)?
        var onMagnify: ((CGFloat, CGPoint) -> Bool)?
        var onDown: ((CGPoint, Int) -> Bool)?
        var onDrag: ((CGSize) -> Void)?
        var onUp: ((CGPoint, Int, Bool, CGSize) -> Void)?
        private var monitor: Any?
        private var downPoint: CGPoint?
        private var hasDragged = false
        private var previousPoint = CGPoint.zero
        private var previousTime: TimeInterval = 0
        private var velocity = CGSize.zero
        private var scrollCaptured = false
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow(); stop()
            guard let window else { return }; window.acceptsMouseMovedEvents = true
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .scrollWheel, .magnify, .leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                let point = self.convert(event.locationInWindow, from: nil)
                switch event.type {
                case .mouseMoved:
                    self.onPointer?(self.bounds.contains(point) ? point : nil)
                    return event
                case .scrollWheel:
                    guard !MusicWallInputExclusion.contains(event) else { return event }
                    guard self.bounds.contains(point) || self.scrollCaptured else { return event }
                    let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 16
                    let consumed = self.onScroll?(CGSize(width: event.scrollingDeltaX * multiplier,
                        height: event.scrollingDeltaY * multiplier), point) ?? false
                    if event.phase == .began { self.scrollCaptured = consumed }
                    if event.momentumPhase == .ended || event.phase == .cancelled { self.scrollCaptured = false }
                    return consumed || self.scrollCaptured ? nil : event
                case .magnify:
                    guard !MusicWallInputExclusion.contains(event) else { return event }
                    guard self.bounds.contains(point) else { return event }
                    return self.onMagnify?(event.magnification, point) == true ? nil : event
                case .leftMouseDown:
                    guard !MusicWallInputExclusion.contains(event), self.bounds.contains(point), self.onDown?(point, event.clickCount) == true else { return event }
                    self.downPoint = point; self.hasDragged = false
                    self.previousPoint = point; self.previousTime = event.timestamp; self.velocity = .zero
                    return nil
                case .leftMouseDragged:
                    guard let start = self.downPoint else { return event }
                    let delta = CGSize(width: point.x - start.x, height: point.y - start.y)
                    if hypot(delta.width, delta.height) > 6 { self.hasDragged = true }
                    let elapsed = event.timestamp - self.previousTime
                    if elapsed > 0.001 {
                        let vx = (point.x - self.previousPoint.x) / elapsed
                        let vy = (point.y - self.previousPoint.y) / elapsed
                        self.velocity = CGSize(width: max(-4000, min(4000, vx)), height: max(-4000, min(4000, vy)))
                    }
                    self.previousPoint = point; self.previousTime = event.timestamp
                    if self.hasDragged { self.onDrag?(delta) }
                    return nil
                case .leftMouseUp:
                    guard self.downPoint != nil else { return event }
                    self.downPoint = nil
                    self.onUp?(point, event.clickCount, self.hasDragged, event.timestamp - self.previousTime < 0.1 ? self.velocity : .zero)
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

/// Marks real control bounds so the wall's local event monitor cannot swallow them.
struct MusicWallInputExclusion: NSViewRepresentable {
    private static let regions = NSHashTable<NSView>.weakObjects()
    func makeNSView(context: Context) -> Region {
        let view = Region(); Self.regions.add(view); return view
    }
    func updateNSView(_ nsView: Region, context: Context) {}
    static func contains(_ event: NSEvent) -> Bool {
        regions.allObjects.contains { view in
            view.window === event.window && !view.isHiddenOrHasHiddenAncestor
                && view.bounds.contains(view.convert(event.locationInWindow, from: nil))
        }
    }
    final class Region: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
