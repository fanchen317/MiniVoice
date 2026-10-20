import Foundation

/// A connected output switch is intentional; losing the active headphone route is not.
enum HeadphoneDisconnectPolicy {
    struct Route: Equatable {
        let id: UInt32
        let isHeadphones: Bool
    }

    static func shouldPause(previous: Route?, current: Route, availableIDs: Set<UInt32>) -> Bool {
        guard let previous, previous.isHeadphones else { return false }
        if previous.id == current.id { return !current.isHeadphones }
        return !availableIDs.contains(previous.id)
    }
}
