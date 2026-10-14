import SwiftUI

// MusicWallCameraMotion.swift: animate the real camera so culling follows every intermediate frame.
@MainActor
final class MusicWallCameraMotion: ObservableObject {
    @Published private(set) var offset = CGSize.zero
    @Published private(set) var scale: CGFloat = 1
    @Published private(set) var reflowProgress: CGFloat = 1
    private var reflowTask: Task<Void, Never>?
    private var travelTask: Task<Void, Never>?
    func stop() { travelTask?.cancel(); travelTask = nil }
    func jump(to value: CGSize) { stop(); offset = value }

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
        let target = min(1.2, max(0.5, requested))
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
                self.offset = CGSize(width: anchor.x - worldPoint.x * next, height: anchor.y - worldPoint.y * next)
                if progress >= 1 { self.travelTask = nil; return }
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            }
        }
    }

    func travel(to target: CGSize, duration: Double? = nil) {
        stop()
        let start = offset
        let distance = hypot(target.width - start.width, target.height - start.height)
        guard distance > 0.5 else { offset = target; return }
        let seconds = duration ?? min(1.15, max(0.45, Double(distance) / 2400))
        travelTask = Task { [weak self] in
            let began = Date.timeIntervalSinceReferenceDate
            while !Task.isCancelled {
                guard let self else { return }
                let progress = min(1, (Date.timeIntervalSinceReferenceDate - began) / max(0.01, seconds))
                let eased = (1 - cos(progress * .pi)) / 2
                self.offset = CGSize(width: start.width + (target.width - start.width) * eased,
                                     height: start.height + (target.height - start.height) * eased)
                if progress >= 1 { self.offset = target; self.travelTask = nil; return }
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            }
        }
    }
}
