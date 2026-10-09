import Foundation

enum AppIdentity {
    static let bundleIdentifier = "com.xcosmos.MiniVoice"
    static let legacyBundleIdentifiers = ["local.fanchen.MiniVoice", "com.local.minivoice"]
}

enum PreferencesMigration {
    static let markerKey = "MiniVoice.bundleIdentifierMigration.v1"

    static func runIfNeeded() {
        // SwiftPM tests and helper executables must never migrate real settings.
        guard Bundle.main.bundleIdentifier == AppIdentity.bundleIdentifier else { return }
        migrate(defaults: .standard, targetDomain: AppIdentity.bundleIdentifier,
                legacyDomains: AppIdentity.legacyBundleIdentifiers)
    }

    /// Copy application-domain settings once, including native window/dialog
    /// preferences. Existing destination values win; source domains stay intact.
    @discardableResult
    static func migrate(defaults: UserDefaults, targetDomain: String, legacyDomains: [String]) -> Int {
        var destination = defaults.persistentDomain(forName: targetDomain) ?? [:]
        guard destination[markerKey] == nil else { return 0 }
        var count = 0
        var sources: [String] = []
        for domain in legacyDomains where domain != targetDomain {
            guard let source = defaults.persistentDomain(forName: domain), !source.isEmpty else { continue }
            sources.append(domain)
            for (key, value) in source where key != markerKey && destination[key] == nil {
                destination[key] = value
                count += 1
            }
        }
        destination[markerKey] = ["sources": sources, "importedKeys": count]
        defaults.setPersistentDomain(destination, forName: targetDomain)
        return count
    }
}
