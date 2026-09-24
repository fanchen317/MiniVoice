import AppKit
import SwiftUI

/// Observe clicks without consuming them, so buttons and song double-clicks
/// still work on the same click that ends search editing.
struct SearchFocusBoundary: NSViewRepresentable {
    func makeNSView(context: Context) -> SearchFocusBoundaryView { SearchFocusBoundaryView() }
    func updateNSView(_ nsView: SearchFocusBoundaryView, context: Context) {}
    static func dismantleNSView(_ nsView: SearchFocusBoundaryView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

final class SearchFocusBoundaryView: NSView {
    private nonisolated(unsafe) var monitor: Any?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.endSearchEditingIfOutside(event)
            return event
        }
    }

    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    private func endSearchEditingIfOutside(_ event: NSEvent) {
        guard let window, event.window === window, window.attachedSheet == nil,
              let editor = window.firstResponder as? NSTextView, editor.isFieldEditor else { return }
        let searchRect = convert(bounds, to: nil)
        // Only resign the editor belonging to this search region, not other fields.
        guard searchRect.intersects(editor.convert(editor.bounds, to: nil)),
              !searchRect.contains(event.locationInWindow) else { return }
        window.makeFirstResponder(window.initialFirstResponder)
    }
}

/// Give the player a neutral initial responder instead of letting AppKit pick
/// the first editable field (search). Installed only in the main player window.
struct PlayerInitialFocus: NSViewRepresentable {
    func makeNSView(context: Context) -> PlayerFocusView { PlayerFocusView() }
    func updateNSView(_ nsView: PlayerFocusView, context: Context) {}
}

final class PlayerFocusView: NSView {
    private weak var configuredWindow: NSWindow?
    override var acceptsFirstResponder: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, configuredWindow !== window else { return }
        configuredWindow = window
        window.initialFirstResponder = self
        window.makeFirstResponder(self)
        // SwiftUI may install the search field later in this same layout pass.
        // Reassert once, never on subsequent activation or view updates.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.window === window else { return }
            window.initialFirstResponder = self
            window.makeFirstResponder(self)
        }
    }
}
