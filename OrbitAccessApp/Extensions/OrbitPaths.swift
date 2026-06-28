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

    static func ensureOrbitDirectoryExists() throws {
        try FileManager.default.createDirectory(at: orbitDirectory, withIntermediateDirectories: true)
    }

    static func privacyPolicyURL() -> URL? {
        if let root = ProcessInfo.processInfo.environment["ORBIT_ROOT"] {
            let url = URL(fileURLWithPath: root).appendingPathComponent("docs/gdpr/PRIVACY_POLICY.md")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let candidates = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("orbit/docs/gdpr/PRIVACY_POLICY.md"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("docs/gdpr/PRIVACY_POLICY.md"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
