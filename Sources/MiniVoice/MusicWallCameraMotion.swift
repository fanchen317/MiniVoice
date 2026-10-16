import SwiftUI

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

@inline(__always)
private func cosineEase(_ x: CGFloat) -> CGFloat {
    (1 - cos(CGFloat.pi * x)) / 2
}

// MusicWallCameraMotion.swift: trajectory-driven camera, vsync-sampled by the
// view's TimelineView. Settled-revision observations still flow through
// Published so dock, focus, and other observers don't need a clock.

private struct OffsetTrajectory {
    let startTime: CFTimeInterval
    let startValue: CGSize
    let endValue: CGSize
    let duration: CFTimeInterval
    let shift: CGSize

    func value(at time: CFTimeInterval) -> CGSize {
        let raw = min(1, max(0, (time - startTime) / max(0.001, duration)))
        let eased = cosineEase(raw)
        let base = CGSize(
            width: startValue.width + (endValue.width - startValue.width) * eased,
            height: startValue.height + (endValue.height - startValue.height) * eased)
        return CGSize(width: base.width + shift.width, height: base.height + shift.height)
    }

    var isComplete: Bool { CACurrentMediaTime() >= startTime + duration }
    var endWithShift: CGSize { CGSize(width: endValue.width + shift.width, height: endValue.height + shift.height) }
}

private struct CoastTrajectory {
    let startTime: CFTimeInterval
    let startValue: CGSize
    let velocity: CGSize
    let resistance: Double
    let completeAfter: CFTimeInterval
    let shift: CGSize

    func value(at time: CFTimeInterval) -> CGSize {
        let elapsed = max(0, time - startTime)
        let decay = exp(-resistance * elapsed)
        let distance = (1 - decay) / CGFloat(resistance)
        return CGSize(
            width: startValue.width + velocity.width * distance + shift.width,
            height: startValue.height + velocity.height * distance + shift.height)
    }

    var isComplete: Bool { CACurrentMediaTime() >= completeAfter }
}

private struct ZoomTrajectory {
    let startTime: CFTimeInterval
    let startScale: CGFloat
    let endScale: CGFloat
    let duration: CFTimeInterval
    let anchor: CGPoint
    let worldPoint: CGPoint
    let shift: CGSize

    func value(at time: CFTimeInterval) -> (scale: CGFloat, offset: CGSize) {
        let raw = min(1, max(0, (time - startTime) / max(0.001, duration)))
        let eased = cosineEase(raw)
        let s = startScale + (endScale - startScale) * eased
        let o = CGSize(width: anchor.x - worldPoint.x * s + shift.width,
                       height: anchor.y - worldPoint.y * s + shift.height)
        return (s, o)
    }

    var isComplete: Bool { CACurrentMediaTime() >= startTime + duration }
}

private struct ReflowTrajectory {
    let startTime: CFTimeInterval
    let duration: CFTimeInterval

    func value(at time: CFTimeInterval) -> CGFloat {
        let raw = min(1, max(0, (time - startTime) / max(0.001, duration)))
        return cosineEase(raw)
    }

    var isComplete: Bool { CACurrentMediaTime() >= startTime + duration }
}

@MainActor
final class MusicWallCameraMotion: ObservableObject {
    let translation = MusicWallTranslation()
    private(set) var offset: CGSize {
        get { offsetAt(time: CACurrentMediaTime()) }
        set {
            let current = offsetAt(time: CACurrentMediaTime())
            notifyCullBoundary(from: current, to: newValue, extra: dragOffset)
            translation.offset = newValue
        }
    }
    var dragOffset: CGSize {
        get { translation.drag }
        set {
            notifyCullBoundary(from: dragOffset, to: newValue, extra: offsetAt(time: CACurrentMediaTime()))
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
    let reflow = MusicWallReflowMotion()
    private(set) var reflowProgress: CGFloat {
        get { reflowProgressAt(time: CACurrentMediaTime()) }
        set {
            settledReflow = newValue
            reflow.progress = newValue
        }
    }
    @Published private(set) var settledRevision = 0

    // Trajectory state — drives `offsetAt(time:)` etc. during an animation.
    private var offsetTrajectory: OffsetTrajectory?
    private var coastTrajectory: CoastTrajectory?
    private var zoomTrajectory: ZoomTrajectory?
    private var reflowTrajectory: ReflowTrajectory?
    private var commitTasks: [Task<Void, Never>] = []

    // Settled values between trajectories.
    private var settledOffset: CGSize = .zero
    private var settledScale: CGFloat = 1
    private var settledReflow: CGFloat = 1
    private var travelShift = CGSize.zero

    // Pan / wheel coalescing onto an 8 ms timer (trackpad momentum).
    private var panTask: Task<Void, Never>?
    private var pendingPan = CGSize.zero
    private var wheelTask: Task<Void, Never>?
    private var pendingWheel = CGSize.zero

    // Back-compat: the legacy `offset` setter wrote `translation.offset`, so
    // every code path that does `motion.offset = X` must reach the same point.
    // The setter above funnels through `notifyCullBoundary` and then updates
    // settledOffset as well, so callers reading offset back see the new value.

    // MARK: - Sampling accessors used by the view's TimelineView.

    func offsetAt(time: CFTimeInterval) -> CGSize {
        if let c = coastTrajectory { return c.value(at: time) }
        if let t = offsetTrajectory { return t.value(at: time) }
        return settledOffset
    }

    func scaleAt(time: CFTimeInterval) -> CGFloat {
        if let z = zoomTrajectory { return z.value(at: time).scale }
        return settledScale
    }

    func reflowProgressAt(time: CFTimeInterval) -> CGFloat {
        if let r = reflowTrajectory { return r.value(at: time) }
        return settledReflow
    }

    func liveCamera(at time: CFTimeInterval) -> (offset: CGSize, scale: CGFloat, reflow: CGFloat) {
        let o = offsetAt(time: time)
        let s = scaleAt(time: time)
        let p = reflowProgressAt(time: time)
        return (o, s, p)
    }

    /// True while a trajectory is in flight. Used as the TimelineView paused
    /// signal so a settled wall costs zero CPU.
    var isAnimating: Bool {
        offsetTrajectory != nil || coastTrajectory != nil || zoomTrajectory != nil || reflowTrajectory != nil
    }

    /// Freeze both parts of a focus transition without snapping to its destination.
    func freezeForInteraction() {
        reflowTrajectory = nil
        wheelTask?.cancel(); wheelTask = nil; pendingWheel = .zero
        stop()
    }
    func stop() {
        // Reap any in-flight trajectory by committing its current value to
        // settledOffset / settledScale / settledReflow.
        let now = CACurrentMediaTime()
        if let c = coastTrajectory {
            settledOffset = c.value(at: now)
        } else if let t = offsetTrajectory {
            settledOffset = t.value(at: now)
        }
        if let z = zoomTrajectory {
            let pair = z.value(at: now)
            settledScale = pair.scale
            settledOffset = pair.offset
        }
        if reflowTrajectory != nil {
            settledReflow = reflowProgressAt(time: now)
        }
        coastTrajectory = nil
        offsetTrajectory = nil
        zoomTrajectory = nil
        reflowTrajectory = nil
        commitTasks.forEach { $0.cancel() }
        commitTasks.removeAll()
        panTask?.cancel(); panTask = nil
        flushPan()
        translation.offset = settledOffset
        scale = settledScale
        reflow.progress = settledReflow
    }

    private func flushPan() {
        guard pendingPan != .zero else { return }
        let delta = pendingPan
        pendingPan = .zero
        // Coalesce the 8 ms flush with the latest settledOffset rather than a
        // wallUpdates-firing translation.offset write.
        settledOffset = CGSize(width: settledOffset.width + delta.width,
                               height: settledOffset.height + delta.height)
        translation.offset = settledOffset
    }
    func jump(to value: CGSize, refreshContent: Bool = false) {
        stop()
        settledOffset = value
        translation.offset = value
        if refreshContent { settledRevision += 1 }
    }

    /// Rebase an in-flight move when the viewport changes, preserving its progress
    /// instead of cancelling and starting another ease-in on every resize event.
    func shiftViewport(by delta: CGSize) {
        guard delta != .zero else { return }
        if let t = offsetTrajectory {
            offsetTrajectory = OffsetTrajectory(
                startTime: t.startTime,
                startValue: t.startValue,
                endValue: t.endValue,
                duration: t.duration,
                shift: CGSize(width: t.shift.width + delta.width, height: t.shift.height + delta.height))
        }
        if let c = coastTrajectory {
            coastTrajectory = CoastTrajectory(
                startTime: c.startTime,
                startValue: c.startValue,
                velocity: c.velocity,
                resistance: c.resistance,
                completeAfter: c.completeAfter,
                shift: CGSize(width: c.shift.width + delta.width, height: c.shift.height + delta.height))
        }
        if let z = zoomTrajectory {
            zoomTrajectory = ZoomTrajectory(
                startTime: z.startTime,
                startScale: z.startScale,
                endScale: z.endScale,
                duration: z.duration,
                anchor: z.anchor,
                worldPoint: z.worldPoint,
                shift: CGSize(width: z.shift.width + delta.width, height: z.shift.height + delta.height))
        }
        travelShift.width += delta.width
        travelShift.height += delta.height
        settledOffset = CGSize(width: settledOffset.width + delta.width, height: settledOffset.height + delta.height)
        translation.offset = settledOffset
    }

    func pan(by delta: CGSize) {
        guard delta != .zero else { return }
        commitTasks.forEach { $0.cancel() }
        commitTasks.removeAll()
        coastTrajectory = nil
        offsetTrajectory = nil
        zoomTrajectory = nil
        pendingPan.width += delta.width
        pendingPan.height += delta.height
        guard panTask == nil else { return }
        panTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(8))
            guard let self else { return }
            self.panTask = nil
            self.flushPan()
        }
    }

    /// Discrete mouse notches follow a short exponential curve. Native trackpad
    /// momentum uses pan(by:) directly, without an additional smoothing tail.
    func wheel(by delta: CGSize) {
        guard delta != .zero else { return }
        commitTasks.forEach { $0.cancel() }
        commitTasks.removeAll()
        coastTrajectory = nil
        offsetTrajectory = nil
        zoomTrajectory = nil
        pendingWheel.width += delta.width
        pendingWheel.height += delta.height
        guard wheelTask == nil else { return }
        let now = CACurrentMediaTime()
        wheelTask = Task { [weak self] in
            var previous = now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(8))
                guard let self else { return }
                let now = CACurrentMediaTime()
                let dt = min(0.05, now - previous)
                previous = now
                let factor = 1 - exp(-dt / 0.08)
                let done = hypot(self.pendingWheel.width, self.pendingWheel.height) < 0.5
                let step = CGSize(
                    width: self.pendingWheel.width * (done ? 1 : factor),
                    height: self.pendingWheel.height * (done ? 1 : factor))
                self.pendingWheel.width -= step.width
                self.pendingWheel.height -= step.height
                self.settledOffset = CGSize(width: self.settledOffset.width + step.width,
                                            height: self.settledOffset.height + step.height)
                self.translation.offset = self.settledOffset
                if done { self.wheelTask = nil; return }
            }
        }
    }

    /// Exponential drag release, integrated by elapsed time rather than frame count.
    func coast(velocity: CGSize) {
        stop()
        guard hypot(velocity.width, velocity.height) > 40 else { return }
        let start = settledOffset
        let resistance = 5.5
        // Solve for when decay reaches 0.008 — ~5.4 half-lives of 1/5.5.
        let duration = log(1 / 0.008) / resistance
        let now = CACurrentMediaTime()
        coastTrajectory = CoastTrajectory(
            startTime: now,
            startValue: start,
            velocity: velocity,
            resistance: resistance,
            completeAfter: now + duration,
            shift: travelShift)
        scheduleCommit(after: duration) { [weak self] in
            guard let self else { return }
            self.settledOffset = CGSize(width: start.width + self.travelShift.width,
                                        height: start.height + self.travelShift.height)
            self.translation.offset = self.settledOffset
            self.coastTrajectory = nil
            self.settledRevision += 1
        }
    }

    func beginReflow(animated: Bool) {
        reflowTrajectory = nil
        guard animated else {
            settledReflow = 1
            reflow.progress = 1
            return
        }
        settledReflow = 0
        reflow.progress = 0
        let now = CACurrentMediaTime()
        reflowTrajectory = ReflowTrajectory(startTime: now, duration: 0.48)
        scheduleCommit(after: 0.48) { [weak self] in
            guard let self else { return }
            self.settledReflow = 1
            self.reflow.progress = 1
            self.reflowTrajectory = nil
        }
    }

    /// Preserve the world point under the pointer throughout a zoom, including every animation frame.
    func zoom(to requested: CGFloat, anchor: CGPoint, animated: Bool) {
        let target = min(1.2, max(0.8, requested))
        guard abs(target - scaleAt(time: CACurrentMediaTime())) > 0.0001 else { return }
        cancelTrajectoryCommits()
        coastTrajectory = nil
        offsetTrajectory = nil
        let startScale = settledScale
        let startOffset = settledOffset
        let worldPoint = CGPoint(x: (anchor.x - startOffset.width) / startScale,
                                  y: (anchor.y - startOffset.height) / startScale)
        if !animated {
            settledScale = target
            scale = target
            let next = CGSize(width: anchor.x - worldPoint.x * target, height: anchor.y - worldPoint.y * target)
            let current = settledOffset
            notifyCullBoundary(from: current, to: next, extra: dragOffset)
            settledOffset = next
            translation.offset = next
            return
        }
        let now = CACurrentMediaTime()
        zoomTrajectory = ZoomTrajectory(
            startTime: now,
            startScale: startScale,
            endScale: target,
            duration: 0.28,
            anchor: anchor,
            worldPoint: worldPoint,
            shift: travelShift)
        scale = startScale
        scheduleCommit(after: 0.28) { [weak self] in
            guard let self else { return }
            let finalScale: CGFloat
            let finalOffset: CGSize
            if let z = self.zoomTrajectory {
                let pair = z.value(at: z.startTime + z.duration)
                finalScale = pair.scale
                finalOffset = pair.offset
            } else {
                finalScale = target
                finalOffset = CGSize(width: anchor.x - worldPoint.x * target + self.travelShift.width,
                                     height: anchor.y - worldPoint.y * target + self.travelShift.height)
            }
            self.settledScale = finalScale
            self.settledOffset = finalOffset
            self.translation.offset = finalOffset
            self.scale = finalScale
            self.zoomTrajectory = nil
            self.settledRevision += 1
        }
    }

    func travel(to target: CGSize, duration: Double? = nil) {
        stop()
        let start = settledOffset
        let distance = hypot(target.width - start.width, target.height - start.height)
        guard distance > 0.5 else {
            settledOffset = target
            translation.offset = target
            settledRevision += 1
            return
        }
        let seconds = duration ?? min(1.15, max(0.45, Double(distance) / 2400))
        let now = CACurrentMediaTime()
        offsetTrajectory = OffsetTrajectory(
            startTime: now,
            startValue: start,
            endValue: target,
            duration: seconds,
            shift: travelShift)
        scheduleCommit(after: seconds) { [weak self] in
            guard let self else { return }
            let end = CGSize(width: target.width + self.travelShift.width,
                             height: target.height + self.travelShift.height)
            self.settledOffset = end
            self.translation.offset = end
            self.offsetTrajectory = nil
            self.settledRevision += 1
        }
    }

    private func scheduleCommit(after seconds: TimeInterval, work: @escaping @MainActor () -> Void) {
        let nanos = UInt64(max(0.001, seconds) * 1_000_000_000)
        let task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: nanos)
            if Task.isCancelled { return }
            work()
        }
        commitTasks.append(task)
    }

    private func cancelTrajectoryCommits() {
        commitTasks.forEach { $0.cancel() }
        commitTasks.removeAll()
    }
}

// MARK: - Timeline-driven rendering

/// Wraps the wall in a TimelineView synced to vsync. While the camera is
/// settled, the TimelineView pauses so settled walls cost zero CPU.
struct MusicWallTimelineContent<Content: View>: View {
    let camera: MusicWallCameraMotion
    @ViewBuilder var content: (CGSize, CGFloat) -> Content

    var body: some View {
        TimelineView(.animation(paused: !camera.isAnimating)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let o = camera.offsetAt(time: t)
            let drag = camera.dragOffset
            let live = CGSize(width: o.width + drag.width, height: o.height + drag.height)
            content(live, camera.reflowProgressAt(time: t))
        }
    }
}
