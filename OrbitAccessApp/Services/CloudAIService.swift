import AppKit
import Foundation
import Security

enum CloudAIError: LocalizedError {
    case registrationFailed(String)
    case persistenceFailed(String)
    case invalidRelayURL

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let message): return message
        case .persistenceFailed(let message): return message
        case .invalidRelayURL: return "Invalid relay URL."
        }
    }
}

struct CloudAIConfig: Codable, Sendable {
    let deviceToken: String
    let relayBaseURL: String

    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
        case relayBaseURL = "relay_base_url"
    }
}

struct CloudRegisterResponse: Decodable {
    let deviceToken: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
        case expiresAt = "expires_at"
    }
}

/// Registers devices with the Orbit Cloud AI relay and writes ``~/.orbit/cloud.json`` for the daemon.
final class CloudAIService: @unchecked Sendable {
    static let shared = CloudAIService()

    private let keychainService = "com.orbit.access.cloud"
    private let installIDKey = "orbit.install_id"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Override via ``ORBIT_RELAY_URL`` env; defaults to local relay for development.
    static var defaultRelayURL: URL {
        if let raw = ProcessInfo.processInfo.environment["ORBIT_RELAY_URL"],
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "http://127.0.0.1:8080")!
    }

    var installID: UUID {
        if let stored = UserDefaults.standard.string(forKey: installIDKey),
           let uuid = UUID(uuidString: stored) {
            return uuid
        }
        let fresh = UUID()
        UserDefaults.standard.set(fresh.uuidString, forKey: installIDKey)
        return fresh
    }

    func isEnabled() -> Bool {
        guard let config = try? loadPersistedConfig() else { return false }
        return !config.deviceToken.isEmpty
    }

    func hasBYOK() -> Bool {
        let url = OrbitPaths.envFileURL
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return text.contains("OPENROUTER_API_KEY=") &&
            text.split(separator: "\n").contains { line in
                line.hasPrefix("OPENROUTER_API_KEY=") &&
                    !line.dropFirst("OPENROUTER_API_KEY=".count).trimmingCharacters(in: .whitespaces).isEmpty
            }
    }

    func saveBYOKKey(_ key: String) throws {
        try OrbitPaths.ensureOrbitDirectoryExists()
        var lines: [String] = []
        var replaced = false
        if FileManager.default.fileExists(atPath: OrbitPaths.envFileURL.path),
           let text = try? String(contentsOf: OrbitPaths.envFileURL, encoding: .utf8) {
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = String(line).trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("OPENROUTER_API_KEY=") {
                    lines.append("OPENROUTER_API_KEY=\(key)")
                    replaced = true
                } else {
                    lines.append(String(line))
                }
            }
        }
        if !replaced {
            lines.append("OPENROUTER_API_KEY=\(key)")
        }
        let body = lines.joined(separator: "\n")
        let output = body.hasSuffix("\n") ? body : body + "\n"
        try output.write(to: OrbitPaths.envFileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: OrbitPaths.envFileURL.path
        )
    }

    func hasLocalLLMConfigured() -> Bool {
        LLMPreferencesService.shared.isLocalConfigured()
    }

    func hasLocalLLM() -> Bool {
        hasLocalLLMConfigured()
    }

    func shouldShowEnablePrompt(isDaemonOnline: Bool) -> Bool {
        isDaemonOnline && !isEnabled() && !hasBYOK() && !hasLocalLLMConfigured()
    }

    func register() async throws -> CloudAIConfig {
        let relayURL = Self.defaultRelayURL
        var request = URLRequest(url: relayURL.appendingPathComponent("/v1/devices/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sessionToken = UserAuthService.shared.sessionToken {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: String] = [
            "install_id": installID.uuidString,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1",
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudAIError.registrationFailed("Invalid response from relay.")
        }
        guard http.statusCode == 201 else {
            let raw = Self.errorMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw CloudAIError.registrationFailed(ChatErrorFormatter.relayRegistrationMessage(raw))
        }

        let decoded = try JSONDecoder().decode(CloudRegisterResponse.self, from: data)
        let config = CloudAIConfig(deviceToken: decoded.deviceToken, relayBaseURL: relayURL.absoluteString)
        try persist(config)
        return config
    }

    func disable() throws {
        try? FileManager.default.removeItem(at: OrbitPaths.cloudConfigURL)
        deleteKeychainToken()
    }

    func persist(_ config: CloudAIConfig) throws {
        try OrbitPaths.ensureOrbitDirectoryExists()
        let data = try JSONEncoder().encode(config)
        try data.write(to: OrbitPaths.cloudConfigURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: OrbitPaths.cloudConfigURL.path
        )
        try saveKeychainToken(config.deviceToken)
    }

    func loadPersistedConfig() throws -> CloudAIConfig? {
        let url = OrbitPaths.cloudConfigURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CloudAIConfig.self, from: data)
    }

    func openOrbitDirectory() {
        NSWorkspace.shared.open(OrbitPaths.orbitDirectory)
    }

    private func saveKeychainToken(_ token: String) throws {
        let account = installID.uuidString
        let data = Data(token.utf8)
        deleteKeychainToken()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CloudAIError.persistenceFailed("Could not save your Cloud AI token to the Keychain. Check Keychain access for Orbit Access.")
        }
    }

    private func deleteKeychainToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: installID.uuidString,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        if let detail = json["detail"] as? [String: Any], let error = detail["error"] as? String {
            return error
        }
        if let error = json["error"] as? String {
            return error
        }
        return nil
    }
}
