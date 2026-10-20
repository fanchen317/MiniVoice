import SwiftUI

/// Mapping is shared by pointer and keyboard input; the thumb never escapes its rail.
enum PlaybackSliderMetrics {
    static func fraction(value: Double, range: ClosedRange<Double>) -> Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
    }

    static func value(position: CGFloat, width: CGFloat, thumbSize: CGFloat,
                      range: ClosedRange<Double>) -> Double {
        let travel = max(0, width - thumbSize)
        guard travel > 0 else { return range.lowerBound }
        let fraction = min(1, max(0, Double((position - thumbSize / 2) / travel)))
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    }
}

struct PlaybackGlassSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var tint: Color
    var label: String
    var rectangularThumb = false
    var onEditingChanged: (Bool) -> Void = { _ in }
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragging = false
    @State private var hovering = false
    @State private var grabOffset: CGFloat = 0
    private var interacting: Bool { enabled && (dragging || hovering) }
    private var thumbSize: CGFloat { rectangularThumb ? 28 : 20 }
    private var thumbHeight: CGFloat { rectangularThumb ? 18 : 20 }
    private var thumbShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: thumbHeight / 2, style: .continuous)
    }

    var body: some View {
        GeometryReader { geometry in
            let fraction = PlaybackSliderMetrics.fraction(value: value, range: range)
            let travel = max(0, geometry.size.width - thumbSize)
            let center = thumbSize / 2 + travel * fraction
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.10)).frame(height: 6)
                Capsule().fill(tint).frame(width: center, height: 6)
                thumb.frame(width: thumbSize, height: thumbHeight)
                    .scaleEffect(x: reduceMotion ? 1 : dragging ? 1.18 : hovering ? 1.06 : 1,
                                 y: reduceMotion ? 1 : dragging ? 1.18 : hovering ? 1.06 : 1)
                    .offset(x: travel * fraction)
            }
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    guard enabled else { return }
                    if !dragging {
                        grabOffset = abs(gesture.startLocation.x - center) <= thumbSize / 2
                            ? gesture.startLocation.x - center : 0
                        dragging = true
                        onEditingChanged(true)
                    }
                    value = PlaybackSliderMetrics.value(position: gesture.location.x - grabOffset,
                        width: geometry.size.width, thumbSize: thumbSize, range: range)
                }
                .onEnded { _ in
                    dragging = false
                    grabOffset = 0
                    onEditingChanged(false)
                })
        }
        .frame(minWidth: thumbSize, idealHeight: 24, maxHeight: 24)
        .onHover { hovering = enabled && $0 }
        .animation(reduceMotion ? nil : (dragging ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.78)), value: dragging)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: hovering)
        .focusable()
        .onMoveCommand { direction in
            guard enabled, direction == .left || direction == .right else { return }
            editValue(value + (direction == .right ? 1 : -1) * (range.upperBound - range.lowerBound) / 100)
        }
        .accessibilityRepresentation {
            Slider(value: Binding(get: { value }, set: { editValue($0) }), in: range)
                .accessibilityLabel(label)
        }
        .onDisappear {
            if dragging { onEditingChanged(false); dragging = false }
        }
    }

    private func editValue(_ next: Double) {
        onEditingChanged(true)
        value = min(range.upperBound, max(range.lowerBound, next))
        onEditingChanged(false)
    }

    @ViewBuilder private var thumb: some View {
        ZStack {
            if #available(macOS 26.0, *) {
                // Animate the solid cap over one stable glass surface so the
                // material does not get recreated while dragging.
                thumbShape.fill(.clear)
                    .glassEffect(.clear, in: thumbShape)
                    .opacity(dragging ? 0.45 : 1)
            } else {
                thumbShape.fill(.ultraThinMaterial)
                    .opacity(dragging ? 0.45 : 1)
            }
            thumbShape.fill(.white.opacity(interacting ? 0 : 0.94))
            thumbShape.strokeBorder(.white.opacity(dragging ? 0.38 : interacting ? 0.65 : 0.85), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(dragging ? 0.10 : interacting ? 0.22 : 0.14),
                radius: interacting ? 3 : 2, y: 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: interacting)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: dragging)
    }
}
