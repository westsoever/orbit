import Foundation

enum OrbitPaths {
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
