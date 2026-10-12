import Foundation

enum BrowseCardGridMetrics {
    static let minimumCardWidth: CGFloat = 136
    static let spacing: CGFloat = 16

    static func columnCount(availableWidth: CGFloat) -> Int {
        max(1, Int((max(0, availableWidth) + spacing) / (minimumCardWidth + spacing)))
    }

    static func cardWidth(availableWidth: CGFloat) -> CGFloat {
        let count = columnCount(availableWidth: availableWidth)
        return max(1, (availableWidth - CGFloat(count - 1) * spacing) / CGFloat(count))
    }
}
