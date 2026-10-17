import AppKit
import QuartzCore

/// One clock per moving surface. It sleeps completely when there is no motion.
/// The weak target breaks CADisplayLink's target-retention cycle.
@MainActor
final class DisplayRefreshClock {
    private let target = Target()
    private var link: AnyObject?
    private var fallback: Timer?
    var onFrame: ((TimeInterval) -> Void)?
    weak var view: NSView?

    init() { target.owner = self }

    func start() {
        guard link == nil, fallback == nil else { return }
        if #available(macOS 14.0, *), let screen = NSScreen.main {
            let displayLink = view?.displayLink(target: target, selector: #selector(Target.frame(_:)))
                ?? screen.displayLink(target: target, selector: #selector(Target.frame(_:)))
            displayLink.add(to: .main, forMode: .common)
            link = displayLink
        } else {
            // Compatibility for macOS 13, before AppKit exposed display links.
            let timer = Timer(timeInterval: 1 / Double(NSScreen.main?.maximumFramesPerSecond ?? 60),
                              target: target, selector: #selector(Target.fallbackFrame(_:)), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            fallback = timer
        }
    }

    func stop() {
        if #available(macOS 14.0, *) { (link as? CADisplayLink)?.invalidate() }
        link = nil
        fallback?.invalidate(); fallback = nil
    }

    @MainActor
    private final class Target: NSObject {
        weak var owner: DisplayRefreshClock?
        @objc func fallbackFrame(_ timer: Timer) {
            guard let owner else { timer.invalidate(); return }
            owner.onFrame?(CACurrentMediaTime())
        }
        @available(macOS 14.0, *)
        @objc func frame(_ link: CADisplayLink) {
            guard let owner else { link.invalidate(); return }
            owner.onFrame?(CACurrentMediaTime())
        }
    }
}
