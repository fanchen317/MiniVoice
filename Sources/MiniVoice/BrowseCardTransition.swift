import SwiftUI

@MainActor
final class BrowseCardTransition: ObservableObject {
    enum Phase { case closed, opening, open, closing }
    @Published private(set) var phase: Phase = .closed
    @Published private(set) var progress: CGFloat = 0
    @Published private(set) var origin: CGRect = .zero
    private var task: Task<Void, Never>?
    var isAnimating: Bool { phase == .opening || phase == .closing }
    private let duration: TimeInterval

    init(duration: TimeInterval = 0.24) { self.duration = duration }

    func open(origin: CGRect, reduceMotion: Bool, prepare: () -> Void) {
        guard phase == .closed else { return }
        self.origin = origin
        progress = 0
        phase = .opening
        prepare()
        task = Task { [weak self] in
            // Mount the detail at the card before moving it to the panel.
            try? await Task.sleep(for: .milliseconds(16))
            guard let self, !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: duration)) { progress = 1 }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : duration))
            guard !Task.isCancelled else { return }
            phase = .open
        }
    }

    func close(origin: CGRect?, reduceMotion: Bool, completion: @escaping () -> Void) {
        guard phase == .open else { return }
        if let origin, !origin.isEmpty { self.origin = origin }
        phase = .closing
        withAnimation(reduceMotion ? nil : .easeInOut(duration: duration)) { progress = 0 }
        let delay = reduceMotion ? 0 : duration
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            // Keep the detail data and scroll view intact until it reaches home.
            completion()
            phase = .closed
        }
    }

    func reset() {
        task?.cancel()
        task = nil
        phase = .closed
        progress = 0
    }
}
