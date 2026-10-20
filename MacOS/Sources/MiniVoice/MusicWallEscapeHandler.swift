import AppKit
import SwiftUI

/// Escape must reach the expanded wall even when a playback control has focus.
struct MusicWallEscapeHandler: NSViewRepresentable {
    let isActive: Bool
    let action: () -> Void

    func makeNSView(context: Context) -> EscapeView {
        let view = EscapeView()
        view.isActive = isActive
        view.action = action
        return view
    }

    func updateNSView(_ view: EscapeView, context: Context) {
        view.isActive = isActive
        view.action = action
    }

    final class EscapeView: NSView {
        var isActive = false
        var action: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isActive, event.keyCode == 53,
                      event.window === self.window, self.window?.attachedSheet == nil else { return event }
                self.action?()
                return nil
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        isolated deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
