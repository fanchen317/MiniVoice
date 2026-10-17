import SwiftUI
import AppKit
import QuartzCore

/// Only viewport projection observes this high-frequency state. The parent wall
/// observes MusicWallCameraMotion, which publishes at cull boundaries.
@MainActor
final class MusicWallTranslation: ObservableObject {
    @Published var offset = CGSize.zero
    @Published var drag = CGSize.zero
}

@MainActor
final class MusicWallReflowMotion: ObservableObject {
    @Published var progress: CGFloat = 1
}

/// Project posters into the viewport before SwiftUI lays them out. Translating
/// an already-laid-out wall lets SwiftUI cull its contents at stale world bounds.
struct MusicWallViewportContent<Content: View>: View {
    @ObservedObject var translation: MusicWallTranslation
    @ObservedObject var reflow: MusicWallReflowMotion
    @ViewBuilder var content: (CGSize, CGFloat) -> Content
    var body: some View {
        content(CGSize(width: translation.offset.width + translation.drag.width,
                       height: translation.offset.height + translation.drag.height), reflow.progress)
    }
}

// Camera physics and reflow share one display-synchronized, monotonic clock.
@MainActor
final class MusicWallCameraMotion: ObservableObject {
    let translation = MusicWallTranslation()
    let reflow = MusicWallReflowMotion()
    private let clock = DisplayRefreshClock()
    private let now: () -> TimeInterval
    private let automaticallyTicks: Bool
    private var previousFrame: TimeInterval = 0
    private var reflowStart: TimeInterval?
    private var movement: Movement?
    private var travelShift = CGSize.zero
    private var pendingPan = CGSize.zero
    private var pendingWheel = CGSize.zero

    private enum Movement {
        case coast(start: CGSize, velocity: CGSize, began: TimeInterval)
        case travel(start: CGSize, target: CGSize, began: TimeInterval, duration: Double)
        case zoom(start: CGFloat, target: CGFloat, world: CGPoint, anchor: CGPoint, began: TimeInterval)
    }

    init(automaticallyTicks: Bool = true, now: @escaping () -> TimeInterval = { CACurrentMediaTime() }) {
        self.automaticallyTicks = automaticallyTicks
        self.now = now
        clock.onFrame = { [weak self] time in self?.advanceFrame(at: time) }
    }

    /// Track the containing display when the window moves between monitors.
    func attach(to view: NSView) { clock.view = view }

    private(set) var offset: CGSize {
        get { translation.offset }
        set {
            guard newValue != offset else { return }
            notifyCullBoundary(from: offset, to: newValue, extra: dragOffset)
            translation.offset = newValue
        }
    }
    var dragOffset: CGSize {
        get { translation.drag }
        set {
            guard newValue != dragOffset else { return }
            notifyCullBoundary(from: dragOffset, to: newValue, extra: offset)
            translation.drag = newValue
        }
    }
    private func notifyCullBoundary(from old: CGSize, to new: CGSize, extra: CGSize) {
        let pitch = 192 * scale
        if floor((old.width + extra.width) / pitch) != floor((new.width + extra.width) / pitch)
            || floor((old.height + extra.height) / pitch) != floor((new.height + extra.height) / pitch) {
            objectWillChange.send()
        }
    }
    @Published private(set) var scale: CGFloat = 1
    private(set) var reflowProgress: CGFloat {
        get { reflow.progress }
        set { if reflow.progress != newValue { reflow.progress = newValue } }
    }
    @Published private(set) var settledRevision = 0

    private func wake() {
        if previousFrame == 0 { previousFrame = now() }
        if automaticallyTicks { clock.start() }
    }
    private func sleepIfIdle() {
        if movement == nil, reflowStart == nil, pendingPan == .zero, pendingWheel == .zero {
            clock.stop(); previousFrame = 0
        }
    }
    func freezeForInteraction() {
        reflowStart = nil
        stop()
    }
    func stop() {
        movement = nil; pendingWheel = .zero; travelShift = .zero
        flushPan()
        sleepIfIdle()
    }
    private func flushPan() {
        guard pendingPan != .zero else { return }
        let delta = pendingPan; pendingPan = .zero
        offset = CGSize(width: offset.width + delta.width, height: offset.height + delta.height)
    }
    func jump(to value: CGSize, refreshContent: Bool = false) {
        stop(); offset = value
        if refreshContent { settledRevision += 1 }
    }
    func shiftViewport(by delta: CGSize) {
        guard delta != .zero else { return }
        travelShift.width += delta.width; travelShift.height += delta.height
        offset = CGSize(width: offset.width + delta.width, height: offset.height + delta.height)
    }
    func pan(by delta: CGSize) {
        guard delta != .zero else { return }
        movement = nil; pendingWheel = .zero; travelShift = .zero
        pendingPan.width += delta.width; pendingPan.height += delta.height
        wake()
    }
    func wheel(by delta: CGSize) {
        guard delta != .zero else { return }
        movement = nil; travelShift = .zero
        pendingWheel.width += delta.width; pendingWheel.height += delta.height
        wake()
    }
    func coast(velocity: CGSize) {
        stop()
        let speed = hypot(velocity.width, velocity.height)
        guard speed > MusicWallMotionTuning.minimumReleaseSpeed else { return }
        let limit = min(1, MusicWallMotionTuning.maximumReleaseSpeed / speed)
        movement = .coast(start: offset,
                          velocity: CGSize(width: velocity.width * limit, height: velocity.height * limit), began: now())
        wake()
    }
    func beginReflow(animated: Bool) {
        reflowStart = animated ? now() : nil
        reflowProgress = animated ? 0 : 1
        if animated { wake() } else { sleepIfIdle() }
    }
    func zoom(to requested: CGFloat, anchor: CGPoint, animated: Bool) {
        let target = min(1.2, max(0.8, requested))
        guard abs(target - scale) > 0.0001 else { return }
        stop()
        let world = CGPoint(x: (anchor.x - offset.width) / scale, y: (anchor.y - offset.height) / scale)
        if !animated {
            scale = target
            offset = CGSize(width: anchor.x - world.x * target, height: anchor.y - world.y * target)
        } else {
            movement = .zoom(start: scale, target: target, world: world, anchor: anchor, began: now())
            wake()
        }
    }
    func travel(to target: CGSize, duration: Double? = nil) {
        stop()
        let distance = hypot(target.width - offset.width, target.height - offset.height)
        guard distance > 0.5 else { offset = target; settledRevision += 1; return }
        movement = .travel(start: offset, target: target, began: now(),
                           duration: max(0.01, duration ?? MusicWallMotionTuning.focusDuration))
        wake()
    }

    /// Exposed internally for deterministic 60/120 Hz physics regression tests.
    func advanceFrame(at time: TimeInterval) {
        let elapsed = max(0, time - previousFrame)
        previousFrame = time
        flushPan()
        if pendingWheel != .zero {
            var factor = 1 - exp(-min(elapsed, MusicWallMotionTuning.maximumWheelFrame) / MusicWallMotionTuning.wheelTimeConstant)
            if hypot(pendingWheel.width, pendingWheel.height) * (1 - factor) < MusicWallMotionTuning.restDistance { factor = 1 }
            let step = CGSize(width: pendingWheel.width * factor, height: pendingWheel.height * factor)
            pendingWheel.width -= step.width; pendingWheel.height -= step.height
            offset = CGSize(width: offset.width + step.width, height: offset.height + step.height)
        }
        if let movement {
            switch movement {
            case let .coast(start, velocity, began):
                let decay = exp(-max(0, time - began) / MusicWallMotionTuning.releaseTimeConstant)
                let done = hypot(velocity.width, velocity.height) * MusicWallMotionTuning.releaseProjection * decay
                    < MusicWallMotionTuning.restDistance
                let distance = MusicWallMotionTuning.releaseProjection * (done ? 1 : 1 - decay)
                offset = CGSize(width: start.width + velocity.width * distance + travelShift.width,
                                height: start.height + velocity.height * distance + travelShift.height)
                if done { self.movement = nil }
            case let .travel(start, target, began, duration):
                let progress = min(1, max(0, (time - began) / duration))
                let eased = MusicWallMotionTuning.focusProgress(progress)
                offset = CGSize(width: start.width + (target.width - start.width) * eased + travelShift.width,
                                height: start.height + (target.height - start.height) * eased + travelShift.height)
                if progress >= 1 { self.movement = nil; settledRevision += 1 }
            case let .zoom(start, target, world, anchor, began):
                let progress = min(1, max(0, (time - began) / 0.28))
                scale = start + (target - start) * (1 - cos(progress * .pi)) / 2
                offset = CGSize(width: anchor.x - world.x * scale + travelShift.width,
                                height: anchor.y - world.y * scale + travelShift.height)
                if progress >= 1 { self.movement = nil }
            }
        }
        if let began = reflowStart {
            reflowProgress = MusicWallMotionTuning.reflowProgress(time - began)
            if reflowProgress >= 1 { reflowStart = nil }
        }
        sleepIfIdle()
    }
}
