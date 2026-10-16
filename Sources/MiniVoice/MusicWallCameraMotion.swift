import SwiftUI

/// Only the translation modifiers observe this high-frequency state. The wall's
/// content tree observes MusicWallCameraMotion, which publishes at cull boundaries.
@MainActor
final class MusicWallTranslation: ObservableObject {
    @Published var offset = CGSize.zero
    @Published var drag = CGSize.zero
}

@MainActor
final class MusicWallReflowMotion: ObservableObject {
    @Published var progress: CGFloat = 1
}

struct MusicWallReflowContent<Content: View>: View {
    @ObservedObject var motion: MusicWallReflowMotion
    @ViewBuilder var content: (CGFloat) -> Content
    var body: some View { content(motion.progress) }
}

struct MusicWallTranslationModifier: ViewModifier {
    @ObservedObject var translation: MusicWallTranslation
    var enabled = true
    var relativeTo = CGSize.zero
    func body(content: Content) -> some View {
        content.offset(x: enabled ? translation.offset.width + translation.drag.width - relativeTo.width : 0,
                       y: enabled ? translation.offset.height + translation.drag.height - relativeTo.height : 0)
    }
}

// MusicWallCameraMotion.swift: animate the real camera so culling follows every intermediate frame.
@MainActor
final class MusicWallCameraMotion: ObservableObject {
    let translation = MusicWallTranslation()
    private(set) var offset: CGSize {
        get { translation.offset }
        set {
            notifyCullBoundary(from: offset, to: newValue, extra: dragOffset)
            translation.offset = newValue
        }
    }
    var dragOffset: CGSize {
        get { translation.drag }
        set {
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
    let reflow = MusicWallReflowMotion()
    private(set) var reflowProgress: CGFloat {
        get { reflow.progress }
        set { reflow.progress = newValue }
    }
    // A final content pass is required even when travel ends inside the same
    // culling bucket as its previous frame.
    @Published private(set) var settledRevision = 0
    private var reflowTask: Task<Void, Never>?
    private var travelTask: Task<Void, Never>?
    private var travelShift = CGSize.zero
    private var panTask: Task<Void, Never>?
    private var pendingPan = CGSize.zero
    private var wheelTask: Task<Void, Never>?
    private var pendingWheel = CGSize.zero
    /// Freeze both parts of a focus transition without snapping to its destination.
    func freezeForInteraction() {
        reflowTask?.cancel(); reflowTask = nil
        stop()
    }
    func stop() {
        wheelTask?.cancel(); wheelTask = nil; pendingWheel = .zero
        travelTask?.cancel(); travelTask = nil
        travelShift = .zero
        panTask?.cancel(); panTask = nil
        flushPan()
    }

    private func flushPan() {
        guard pendingPan != .zero else { return }
        let delta = pendingPan
        pendingPan = .zero
        offset = CGSize(width: offset.width + delta.width, height: offset.height + delta.height)
    }
    func jump(to value: CGSize) { stop(); offset = value }

    /// Rebase an in-flight move when the viewport changes, preserving its progress
    /// instead of cancelling and starting another ease-in on every resize event.
    func shiftViewport(by delta: CGSize) {
        guard delta != .zero else { return }
        travelShift.width += delta.width
        travelShift.height += delta.height
        offset = CGSize(width: offset.width + delta.width, height: offset.height + delta.height)
    }

    func pan(by delta: CGSize) {
        guard delta != .zero else { return }
        wheelTask?.cancel(); wheelTask = nil; pendingWheel = .zero
        travelTask?.cancel(); travelTask = nil
        pendingPan.width += delta.width
        pendingPan.height += delta.height
        // Coalesce high-frequency wheel events without losing native momentum deltas.
        guard panTask == nil else { return }
        panTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(8)) } catch { return }
            guard let self else { return }
            self.panTask = nil
            self.flushPan()
        }
    }

    /// Discrete mouse notches follow a short exponential curve. Native trackpad
    /// momentum uses pan(by:) directly, without an additional smoothing tail.
    func wheel(by delta: CGSize) {
        guard delta != .zero else { return }
        travelTask?.cancel(); travelTask = nil
        pendingWheel.width += delta.width
        pendingWheel.height += delta.height
        guard wheelTask == nil else { return }
        wheelTask = Task { [weak self] in
            var previous = ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(8)) } catch { return }
                guard let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let factor = 1 - exp(-min(0.05, now - previous) / 0.08)
                previous = now
                let done = hypot(self.pendingWheel.width, self.pendingWheel.height) < 0.5
                let step = CGSize(width: self.pendingWheel.width * (done ? 1 : factor),
                                  height: self.pendingWheel.height * (done ? 1 : factor))
                self.pendingWheel.width -= step.width
                self.pendingWheel.height -= step.height
                self.offset = CGSize(width: self.offset.width + step.width, height: self.offset.height + step.height)
                if done { self.wheelTask = nil; return }
            }
        }
    }

    /// Exponential drag release, integrated by elapsed time rather than frame count.
    func coast(velocity: CGSize) {
        stop()
        guard hypot(velocity.width, velocity.height) > 40 else { return }
        let start = offset
        travelTask = Task { [weak self] in
            let began = Date.timeIntervalSinceReferenceDate
            let resistance = 5.5
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = Date.timeIntervalSinceReferenceDate - began
                let decay = exp(-resistance * elapsed)
                let distance = (1 - decay) / resistance
                self.offset = CGSize(width: start.width + velocity.width * distance + self.travelShift.width,
                                     height: start.height + velocity.height * distance + self.travelShift.height)
                if decay < 0.008 { self.travelTask = nil; return }
                do { try await Task.sleep(for: .milliseconds(8)) } catch { return }
            }
        }
    }

    func beginReflow(animated: Bool) {
        reflowTask?.cancel()
        guard animated else { reflowProgress = 1; return }
        reflowProgress = 0
        reflowTask = Task { [weak self] in
            let began = Date.timeIntervalSinceReferenceDate
            while !Task.isCancelled {
                guard let self else { return }
                let progress = min(1, (Date.timeIntervalSinceReferenceDate - began) / 0.48)
                self.reflowProgress = (1 - cos(progress * .pi)) / 2
                if progress >= 1 { self.reflowProgress = 1; self.reflowTask = nil; return }
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            }
        }
    }

    /// Preserve the world point under the pointer throughout a zoom, including every animation frame.
    func zoom(to requested: CGFloat, anchor: CGPoint, animated: Bool) {
        let target = min(1.2, max(0.8, requested))
        guard abs(target - scale) > 0.0001 else { return }
        stop()
        let startScale = scale
        let worldPoint = CGPoint(x: (anchor.x - offset.width) / scale, y: (anchor.y - offset.height) / scale)
        if !animated {
            scale = target
            offset = CGSize(width: anchor.x - worldPoint.x * target, height: anchor.y - worldPoint.y * target)
            return
        }
        travelTask = Task { [weak self] in
            let began = Date.timeIntervalSinceReferenceDate
            while !Task.isCancelled {
                guard let self else { return }
                let progress = min(1, (Date.timeIntervalSinceReferenceDate - began) / 0.28)
                let eased = (1 - cos(progress * .pi)) / 2
                let next = startScale + (target - startScale) * eased
                self.scale = next
                self.offset = CGSize(width: anchor.x - worldPoint.x * next + self.travelShift.width,
                                     height: anchor.y - worldPoint.y * next + self.travelShift.height)
                if progress >= 1 { self.travelTask = nil; return }
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            }
        }
    }

    func travel(to target: CGSize, duration: Double? = nil) {
        stop()
        let start = offset
        let distance = hypot(target.width - start.width, target.height - start.height)
        guard distance > 0.5 else { offset = target; settledRevision += 1; return }
        let seconds = duration ?? min(1.15, max(0.45, Double(distance) / 2400))
        travelTask = Task { [weak self] in
            let began = Date.timeIntervalSinceReferenceDate
            while !Task.isCancelled {
                guard let self else { return }
                let progress = min(1, (Date.timeIntervalSinceReferenceDate - began) / max(0.01, seconds))
                let eased = (1 - cos(progress * .pi)) / 2
                self.offset = CGSize(width: start.width + (target.width - start.width) * eased + self.travelShift.width,
                                     height: start.height + (target.height - start.height) * eased + self.travelShift.height)
                if progress >= 1 {
                    self.offset = CGSize(width: target.width + self.travelShift.width,
                                         height: target.height + self.travelShift.height)
                    self.travelTask = nil
                    self.settledRevision += 1
                    return
                }
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            }
        }
    }
}
