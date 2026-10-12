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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragging = false
    @State private var hovering = false
    @State private var grabOffset: CGFloat = 0
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
                    .scaleEffect(x: reduceMotion ? 1 : dragging ? 1.25 : hovering ? 1.12 : 1,
                                 y: reduceMotion ? 1 : dragging ? 1.10 : hovering ? 1.05 : 1)
                    .offset(x: travel * fraction)
            }
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { gesture in
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
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.76), value: dragging)
        .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.82), value: hovering)
        .focusable()
        .onMoveCommand { direction in
            guard direction == .left || direction == .right else { return }
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
        if #available(macOS 26.0, *) {
            thumbShape.fill(.clear)
                .glassEffect(.clear.interactive(), in: thumbShape)
        } else {
            thumbShape.fill(.ultraThinMaterial)
                .overlay { thumbShape.stroke(.white.opacity(0.6), lineWidth: 0.75) }
                .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
        }
    }
}
