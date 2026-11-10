import Foundation

@main struct WebHostDiagnosticsTests {
    static func main() {
        timelineAndRecovery()
        errorPrivacyAndCancellation()
        boundedFailureReports()
        resourceCategories()
        print("PASS: web host monotonic stages/recovery, obsolete replies, private error metadata, ENOENT/EACCES retention and bounded failure counts")
    }

    static func timelineAndRecovery() {
        var now = 10.0
        var diagnostics = WebHostDiagnostics(clock: { now })
        precondition(diagnostics.stage(.ready, generation: 0) == nil)
        precondition(diagnostics.begin(.created) == "web generation=1 stage=created elapsedMs=0")
        let first = diagnostics.generation
        now = 10.125
        precondition(diagnostics.stage(.provisional, generation: first)?.contains("elapsedMs=125") == true)
        precondition(diagnostics.stage(.provisional, generation: first) == nil)
        now = 10.375
        precondition(diagnostics.stage(.committed, generation: first)?.contains("elapsedMs=375") == true)
        now = 10.625
        precondition(diagnostics.stage(.finished, generation: first)?.contains("elapsedMs=625") == true)
        // Even a faulty injected clock cannot produce negative or decreasing elapsed values.
        now = 10.5
        precondition(diagnostics.stage(.ready, generation: first)?.contains("elapsedMs=625") == true)
        now = 30
        precondition(diagnostics.begin(.recovery) == "web generation=2 stage=recovery elapsedMs=0")
        precondition(diagnostics.stage(.finished, generation: first) == nil)
        precondition(diagnostics.failure(.resource(.script), error: NSError(domain: NSPOSIXErrorDomain, code: 2), generation: first) == nil)
        now = 30.125
        precondition(diagnostics.stage(.provisional, generation: diagnostics.generation)?.contains("elapsedMs=125") == true)
        precondition(diagnostics.stage(.ready, generation: diagnostics.generation)?.contains("elapsedMs=125") == true)
        var live = WebHostDiagnostics()
        _ = live.begin(.created)
        precondition(live.stage(.provisional, generation: live.generation)?.contains("elapsedMs=") == true)
    }

    static func errorPrivacyAndCancellation() {
        var diagnostics = WebHostDiagnostics(clock: { 5 })
        _ = diagnostics.begin(.created)
        let current = diagnostics.generation
        let missing = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [
            NSLocalizedDescriptionKey: "Can't open /var/mobile/private-song/secret.mp3",
            NSFilePathErrorKey: "/var/mobile/private-song/secret.mp3",
            NSURLErrorFailingURLErrorKey: URL(string: "minivoice://app/artwork/song-token.png?v=private-version")!,
            NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: 2)
        ])
        let detail = diagnostics.failure(.resource(.artwork), error: missing, generation: current, expectedMissingArtwork: true)!
        precondition(detail.contains("resource.artwork") && detail.contains("NSCocoaErrorDomain:260>NSPOSIXErrorDomain:2"))
        for secret in ["private-song", "secret.mp3", "song-token", "private-version", "minivoice://", "/var", "Can't open"] { precondition(!detail.contains(secret)) }
        let denied = NSError(domain: NSPOSIXErrorDomain, code: 13, userInfo: [NSLocalizedDescriptionKey: "Permission denied /private/secret"])
        precondition(diagnostics.failure(.resource(.script), error: denied, generation: current)?.contains("NSPOSIXErrorDomain:13") == true)
        let expectedMissing = NSError(domain: "MiniVoice.iOS.Host", code: 2)
        precondition(diagnostics.failure(.resource(.artwork), error: expectedMissing, generation: current, expectedMissingArtwork: true) == nil)
        precondition(diagnostics.failure(.navigation(.provisional), error: expectedMissing, generation: current, expectedMissingArtwork: true) != nil)
        precondition(diagnostics.failure(.resource(.style), error: CancellationError(), generation: current) == nil)
        precondition(diagnostics.failure(.resource(.style), error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled), generation: current) == nil)
        let wrappedCancel = NSError(domain: "WKErrorDomain", code: 1, userInfo: [NSUnderlyingErrorKey: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)])
        precondition(diagnostics.failure(.navigation(.committed), error: wrappedCancel, generation: current) == nil)
        let privateDomain = NSError(domain: "file:///private/user-token?secret=value", code: 42)
        let anonymous = diagnostics.failure(.resource(.other), error: privateDomain, generation: current)!
        precondition(anonymous.contains("OtherErrorDomain:42") && !anonymous.contains("secret") && !anonymous.contains("token"))
    }

    static func boundedFailureReports() {
        var diagnostics = WebHostDiagnostics(clock: { 2 })
        _ = diagnostics.begin(.created)
        let error = NSError(domain: NSPOSIXErrorDomain, code: 13)
        var messages: [String] = []
        for _ in 0..<100_000 {
            if let detail = diagnostics.failure(.resource(.artwork), error: error, generation: diagnostics.generation) { messages.append(detail) }
        }
        precondition(messages.count < 20)
        precondition(messages.first?.contains("count=1 ") == true)
        precondition(messages.last?.contains("count=65536 ") == true)
        precondition(diagnostics.failure(.resource(.artwork), error: error, generation: diagnostics.generation) == nil)
        // More distinct file errors cannot allocate an unbounded key table or reveal their domains.
        var overflowMessages: [String] = []
        for code in 0..<1000 {
            if let detail = diagnostics.failure(.resource(.other), error: NSError(domain: NSPOSIXErrorDomain, code: code), generation: diagnostics.generation) { overflowMessages.append(detail) }
        }
        precondition(overflowMessages.count < 20)
        precondition(overflowMessages.contains(where: { $0.contains("failure=other-kinds") }))
        _ = diagnostics.begin(.recovery)
        precondition(diagnostics.failure(.resource(.artwork), error: error, generation: diagnostics.generation)?.contains("count=1 ") == true)
    }

    static func resourceCategories() {
        for (path, expected) in [("/index.html", WebHostDiagnostics.Resource.document), ("/assets/hash.js", .script), ("/assets/hash.css", .style), ("/app-icon.png", .icon), ("/artwork/private-token.png?v=secret", .artwork), ("/unknown.data", .other)] {
            precondition(WebHostDiagnostics.resource(for: URL(string: "minivoice://app" + path)) == expected)
        }
        precondition(WebHostDiagnostics.resource(for: nil) == .other)
    }
}
