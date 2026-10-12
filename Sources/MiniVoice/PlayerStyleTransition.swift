import AppKit
import SwiftUI

enum StyleFragmentMotion {
    static let duration: TimeInterval = 0.94

    static func cells(size: CGSize) -> [CGRect] {
        guard size.width > 0, size.height > 0 else { return [] }
        let columns = max(6, min(16, Int(ceil(size.width / 72))))
        let rows = max(6, min(14, Int(ceil(size.height / 72))))
        return (0..<rows).flatMap { row in
            (0..<columns).map { column in
                CGRect(x: CGFloat(column) * size.width / CGFloat(columns),
                       y: CGFloat(row) * size.height / CGFloat(rows),
                       width: size.width / CGFloat(columns), height: size.height / CGFloat(rows))
            }
        }
    }

    static func progress(elapsed: TimeInterval, center: CGPoint, origin: CGPoint, size: CGSize) -> Double {
        let diagonal = max(1, hypot(size.width, size.height))
        let distance = hypot(center.x - origin.x, center.y - origin.y)
        let delay = min(1, distance / diagonal) * 0.32
        return min(1, max(0, (elapsed - delay) / 0.62))
    }
}

@MainActor
final class PlayerStyleTransition: ObservableObject {
    struct Fragment {
        let rect: CGRect
        let image: CGImage
    }
    struct Snapshot {
        let id = UUID()
        let size: CGSize
        let origin: CGPoint
        let started: Date
        let fragments: [Fragment]
    }

    @Published private(set) var snapshot: Snapshot?
    weak var rootView: NSView?
    weak var iconView: NSView?
    private var completion: Task<Void, Never>?

    func capture() -> Bool {
        guard snapshot == nil, let marker = rootView, let content = marker.window?.contentView else { return false }
        let rect = marker.convert(marker.bounds, to: content).intersection(content.bounds)
        guard rect.width > 0, rect.height > 0,
              let bitmap = content.bitmapImageRepForCachingDisplay(in: rect) else { return false }
        content.cacheDisplay(in: rect, to: bitmap)
        guard let original = bitmap.cgImage else { return false }
        // One bounded texture per click; never capture live playback every frame.
        let factor = min(1, 1600 / CGFloat(original.width))
        let image: CGImage
        if factor < 1,
           let context = CGContext(data: nil, width: Int(CGFloat(original.width) * factor),
               height: Int(CGFloat(original.height) * factor), bitsPerComponent: 8, bytesPerRow: 0,
               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            context.interpolationQuality = .medium
            context.draw(original, in: CGRect(x: 0, y: 0, width: context.width, height: context.height))
            image = context.makeImage() ?? original
        } else { image = original }
        let size = rect.size
        let iconRect = iconView.map { $0.convert($0.bounds, to: content) }
        let origin = iconRect.map {
            CGPoint(x: $0.midX - rect.minX,
                    y: content.isFlipped ? $0.midY - rect.minY : rect.maxY - $0.midY)
        } ?? CGPoint(x: 36, y: 60)
        let sx = CGFloat(image.width) / size.width, sy = CGFloat(image.height) / size.height
        let fragments = StyleFragmentMotion.cells(size: size).compactMap { cell -> Fragment? in
            let crop = CGRect(x: cell.minX * sx, y: cell.minY * sy,
                              width: cell.width * sx, height: cell.height * sy).integral
            guard let piece = image.cropping(to: crop) else { return nil }
            return Fragment(rect: cell, image: piece)
        }
        guard !fragments.isEmpty else { return false }
        snapshot = Snapshot(size: size, origin: origin, started: Date(), fragments: fragments)
        completion?.cancel()
        completion = Task { [weak self] in
            try? await Task.sleep(for: .seconds(StyleFragmentMotion.duration + 0.06))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
        return true
    }

    func finish() {
        completion?.cancel()
        completion = nil
        snapshot = nil
    }
}

struct StyleTransitionProbe: NSViewRepresentable {
    let transition: PlayerStyleTransition
    var icon = false
    func makeNSView(context: Context) -> NSView {
        let view = StyleTransitionMarker()
        if icon { transition.iconView = view } else { transition.rootView = view }
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {
        if icon { transition.iconView = view } else { transition.rootView = view }
    }
}

private final class StyleTransitionMarker: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct StyleFragmentSweep: View {
    let snapshot: PlayerStyleTransition.Snapshot
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
            Canvas { context, _ in
                let elapsed = timeline.date.timeIntervalSince(snapshot.started)
                for (index, fragment) in snapshot.fragments.enumerated() {
                    let center = CGPoint(x: fragment.rect.midX, y: fragment.rect.midY)
                    let progress = StyleFragmentMotion.progress(elapsed: elapsed, center: center,
                        origin: snapshot.origin, size: snapshot.size)
                    guard progress < 1 else { continue }
                    let eased = progress * progress * (3 - 2 * progress)
                    let angle = atan2(center.y - snapshot.origin.y, center.x - snapshot.origin.x)
                    let curl = sin(progress * .pi) * Double((index % 7) - 3) * 6
                    let distance = eased * 140
                    var piece = context
                    piece.opacity = 1 - eased
                    piece.translateBy(x: center.x + cos(angle) * distance - sin(angle) * curl,
                                      y: center.y + sin(angle) * distance + cos(angle) * curl)
                    piece.rotate(by: .degrees(Double((index % 9) - 4) * eased * 8))
                    let scale = 1 - eased * 0.65
                    piece.scaleBy(x: scale, y: scale)
                    piece.draw(Image(decorative: fragment.image, scale: 1),
                        in: CGRect(x: -fragment.rect.width / 2, y: -fragment.rect.height / 2,
                                   width: fragment.rect.width, height: fragment.rect.height))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PlayerStyleSwitchButton: View {
    let targetTitle: String
    let transition: PlayerStyleTransition
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable().scaledToFit().frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.regularMaterial, in: Circle())
                        .opacity(hovering ? 1 : 0)
                }
                .scaleEffect(hovering && !reduceMotion ? 1.07 : 1)
                .rotationEffect(.degrees(hovering && !reduceMotion ? -4 : 0))
                .shadow(color: .green.opacity(hovering ? 0.25 : 0), radius: 8, y: 3)
        }
        .buttonStyle(StyleSwitchPressStyle())
        .background(StyleTransitionProbe(transition: transition, icon: true))
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78), value: hovering)
        .disabled(transition.snapshot != nil)
        .help("切换到\(targetTitle)")
        .accessibilityLabel("切换到\(targetTitle)")
    }
}

private struct StyleSwitchPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.90 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.74),
                       value: configuration.isPressed)
    }
}
