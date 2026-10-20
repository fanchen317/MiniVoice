import AppKit
import Combine
import SwiftUI

/// Keep the mounted posters stationary in an overscanned document. Between cull
/// boundaries, only the native clip layer moves: no poster body or text layout
/// subscribes to camera translation. Native coordinates also keep context menus
/// and accessibility hit testing aligned with what is on screen.
struct MusicWallCompositedViewport<Content: View>: NSViewRepresentable {
    let motion: MusicWallCameraMotion
    let viewport: CGSize
    @ViewBuilder var content: (CGSize, CGFloat, CGSize) -> Content
    static var overscan: CGFloat { 384 }

    func makeNSView(context: Context) -> Surface {
        let surface = Surface(frame: CGRect(origin: .zero, size: viewport))
        surface.bind(motion.translation)
        motion.attach(to: surface)
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {
        let padding = Self.overscan
        let documentSize = CGSize(width: viewport.width + padding * 2, height: viewport.height + padding * 2)
        let anchor = CGSize(width: motion.offset.width + motion.dragOffset.width,
                            height: motion.offset.height + motion.dragOffset.height)
        let projected = CGSize(width: anchor.width + padding, height: anchor.height + padding)
        surface.install(ReflowContent(reflow: motion.reflow, offset: projected, size: documentSize, content: content),
                        anchor: anchor, size: documentSize)
    }

    static func dismantleNSView(_ surface: Surface, coordinator: ()) { surface.observation = nil }

    struct ReflowContent: View {
        @ObservedObject var reflow: MusicWallReflowMotion
        let offset: CGSize
        let size: CGSize
        let content: (CGSize, CGFloat, CGSize) -> Content
        var body: some View { content(offset, reflow.progress, size) }
    }

    final class Surface: NSView {
        let clip = NSClipView()
        private(set) var host: NSHostingView<ReflowContent>?
        private var anchor = CGSize.zero
        private var liveOffset = CGSize.zero
        var observation: AnyCancellable?
        override var isFlipped: Bool { true }

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            clip.wantsLayer = true
            clip.drawsBackground = false
            clip.frame = bounds
            clip.autoresizingMask = [.width, .height]
            addSubview(clip)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func bind(_ translation: MusicWallTranslation) {
            observation = translation.$offset.combineLatest(translation.$drag).sink { [weak self] offset, drag in
                guard let self else { return }
                self.liveOffset = CGSize(width: offset.width + drag.width, height: offset.height + drag.height)
                self.project()
            }
        }

        func install(_ root: ReflowContent, anchor: CGSize, size: CGSize) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.anchor = anchor
            if let host { host.rootView = root }
            else {
                let host = NSHostingView(rootView: root)
                host.wantsLayer = true
                self.host = host
                clip.documentView = host
            }
            host?.frame = CGRect(origin: .zero, size: size)
            // Commit the rebase and its clip origin together. Deferring the new
            // root's layout would briefly show the old root at the new origin.
            host?.layoutSubtreeIfNeeded()
            project()
            CATransaction.commit()
        }

        private func project() {
            let padding = MusicWallCompositedViewport.overscan
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            clip.scroll(to: CGPoint(x: padding - (liveOffset.width - anchor.width),
                                    y: padding - (liveOffset.height - anchor.height)))
            CATransaction.commit()
        }
    }
}
