import Foundation

// MusicWallSequence.swift: horizontal wall copies advance through the queue instead of duplicating a stripe.
enum MusicWallSequence {
    static func index(base: Int, horizontalCopy: Int, stride: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let offset = horizontalCopy % count
        let value = (base % count + offset * (stride % count)) % count
        return value >= 0 ? value : value + count
    }
}
