import Foundation

/// App-owned observations only. These timings do not measure WebKit's child processes.
struct WebHostDiagnostics {
    enum Reason: String { case created, recovery }
    enum Stage: String, CaseIterable, Hashable { case provisional, committed, finished, ready }
    enum Resource: String, Hashable { case document, script, style, icon, artwork, other }
    enum Scope: Hashable {
        case resource(Resource)
        case navigation(Stage)
        var label: String {
            switch self {
            case .resource(let resource): return "resource." + resource.rawValue
            case .navigation(let stage): return "navigation." + stage.rawValue
            }
        }
    }
    private struct FailureKey: Hashable { let scope: Scope; let domains: String }
    private let clock: () -> TimeInterval
    private var began: TimeInterval = 0
    private var lastMilliseconds = 0
    private var stages = Set<Stage>()
    private var failures: [FailureKey: Int] = [:]
    private var overflow = 0
    private(set) var generation: UInt64 = 0
    static let maximumFailureKinds = 8
    static let maximumFailureCount = 65536

    init(clock: (() -> TimeInterval)? = nil) {
        if let clock { self.clock = clock }
        else {
            let continuous = ContinuousClock(), origin = continuous.now
            self.clock = {
                let elapsed = origin.duration(to: continuous.now).components
                return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
            }
        }
    }

    mutating func begin(_ reason: Reason) -> String {
        generation &+= 1
        began = clock(); lastMilliseconds = 0
        stages.removeAll(keepingCapacity: true); failures.removeAll(keepingCapacity: true); overflow = 0
        return "web generation=\(generation) stage=\(reason.rawValue) elapsedMs=0"
    }

    mutating func stage(_ stage: Stage, generation expected: UInt64) -> String? {
        guard expected == generation, generation > 0, stages.insert(stage).inserted else { return nil }
        return "web generation=\(generation) stage=\(stage.rawValue) elapsedMs=\(milliseconds())"
    }

    static func resource(for url: URL?) -> Resource {
        guard let url else { return .other }
        if url.path.hasPrefix("/artwork/") { return .artwork }
        switch url.pathExtension.lowercased() {
        case "html": return .document
        case "js", "mjs": return .script
        case "css": return .style
        case "png", "jpg", "jpeg", "svg", "ico": return .icon
        default: return url.path == "/" ? .document : .other
        }
    }

    /// Keep actual ENOENT/EACCES errors. Only explicit absence, cancellation and
    /// obsolete generation replies are omitted; no description or URL is serialized.
    mutating func failure(_ scope: Scope, error: Error, generation expected: UInt64, expectedMissingArtwork: Bool = false) -> String? {
        guard expected == generation, generation > 0, !(error is CancellationError) else { return nil }
        let native = error as NSError
        if expectedMissingArtwork, scope == .resource(.artwork), native.domain == "MiniVoice.iOS.Host", native.code == 2 { return nil }
        let chain = Self.errorChain(error)
        guard !chain.contains(where: { ($0.domain == NSURLErrorDomain && $0.code == NSURLErrorCancelled) || ($0.domain == NSCocoaErrorDomain && $0.code == NSUserCancelledError) }) else { return nil }
        let domains = chain.map { "\(Self.safeDomain($0.domain)):\($0.code)" }.joined(separator: ">")
        let key = FailureKey(scope: scope, domains: domains)
        if failures[key] == nil && failures.count >= Self.maximumFailureKinds {
            let previous = overflow
            overflow = min(Self.maximumFailureCount, overflow + 1)
            guard overflow != previous, Self.reportCount(overflow) else { return nil }
            return "web generation=\(generation) failure=other-kinds count=\(overflow) elapsedMs=\(milliseconds())"
        }
        let previous = failures[key] ?? 0
        let count = min(Self.maximumFailureCount, previous + 1)
        failures[key] = count
        guard count != previous, Self.reportCount(count) else { return nil }
        return "web generation=\(generation) failure=\(scope.label) error=\(domains) count=\(count) elapsedMs=\(milliseconds())"
    }

    private static func reportCount(_ count: Int) -> Bool { count > 0 && count & (count - 1) == 0 }
    private mutating func milliseconds() -> Int {
        let elapsed = (clock() - began) * 1000
        if elapsed.isFinite { lastMilliseconds = max(lastMilliseconds, Int(max(0, min(Double(Int.max / 2), elapsed)).rounded(.down))) }
        return lastMilliseconds
    }
    private static func errorChain(_ error: Error) -> [NSError] {
        var chain: [NSError] = [], current: NSError? = error as NSError
        while let value = current, chain.count < 3 {
            chain.append(value)
            current = value.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return chain
    }
    private static func safeDomain(_ domain: String) -> String {
        switch domain {
        case NSCocoaErrorDomain, NSURLErrorDomain, NSPOSIXErrorDomain, NSOSStatusErrorDomain,
             "WKErrorDomain", "WebKitErrorDomain", "AVFoundationErrorDomain", "MiniVoice.iOS.Host",
             "MiniVoice.iOS.Collection", "MiniVoice.Maintenance": return domain
        default: return "OtherErrorDomain"
        }
    }
}
