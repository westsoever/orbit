import Foundation

enum OrbitPaths {
    static var orbitDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".orbit", isDirectory: true)
    }

    static var databaseURL: URL {
        orbitDirectory.appendingPathComponent("orbit.db", isDirectory: false)
    }

    static var accessAppLockURL: URL {
        orbitDirectory.appendingPathComponent("access-app.lock", isDirectory: false)
    }

    /// Installed app bundle: Contents/Resources/orbit-core (ORBIT_ROOT for production installs).
    static var bundledOrbitCoreURL: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/orbit-core", isDirectory: true)
    }

    static func defaultOrbitRoot() -> String? {
        if let root = ProcessInfo.processInfo.environment["ORBIT_ROOT"], !root.isEmpty {
            return root
        }
        let core = bundledOrbitCoreURL
        if FileManager.default.fileExists(atPath: core.path) {
            return core.path
        }
        return nil
    }

    static var cloudConfigURL: URL {
        orbitDirectory.appendingPathComponent("cloud.json", isDirectory: false)
    }

    static var envFileURL: URL {
        orbitDirectory.appendingPathComponent(".env", isDirectory: false)
    }

    static func ensureOrbitDirectoryExists() throws {
        try FileManager.default.createDirectory(at: orbitDirectory, withIntermediateDirectories: true)
    }

    static func privacyPolicyURL() -> URL? {
        if let root = defaultOrbitRoot() {
            let url = URL(fileURLWithPath: root).appendingPathComponent("docs/gdpr/PRIVACY_POLICY.md")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let bundled = bundledOrbitCoreURL.appendingPathComponent("docs/gdpr/PRIVACY_POLICY.md")
        if FileManager.default.fileExists(atPath: bundled.path) { return bundled }
        let devCandidates = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("docs/gdpr/PRIVACY_POLICY.md"),
        ]
        return devCandidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
