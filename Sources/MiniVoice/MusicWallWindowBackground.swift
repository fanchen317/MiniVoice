import AppKit
import SwiftUI

/// AppKit exposes newly resized window pixels before SwiftUI has drawn the
/// next frame. Match the wall at that layer instead of exposing the desktop.
struct MusicWallWindowBackground: NSViewRepresentable {
    let isActive: Bool
    func makeNSView(context: Context) -> BackgroundView {
        let view = BackgroundView()
        view.isActive = isActive
        return view
    }
    func updateNSView(_ view: BackgroundView, context: Context) {
        view.isActive = isActive
        view.apply()
    }
    static func dismantleNSView(_ view: BackgroundView, coordinator: ()) { view.restore() }

    final class BackgroundView: NSView {
        var isActive = false
        private weak var configuredWindow: NSWindow?
        private var previousColor: NSColor?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Run after the main window's initial transparent configuration.
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }
        func apply() {
            if configuredWindow !== window { restore() }
            guard isActive, let window else { restore(); return }
            if configuredWindow == nil {
                configuredWindow = window
                previousColor = window.backgroundColor
            }
            window.backgroundColor = NSColor(srgbRed: 0.09, green: 0.08, blue: 0.08, alpha: 1)
        }
        func restore() {
            if let previousColor { configuredWindow?.backgroundColor = previousColor }
            previousColor = nil
            configuredWindow = nil
        }
    }
}
