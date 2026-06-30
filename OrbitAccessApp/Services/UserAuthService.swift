import Foundation

enum UserAuthError: LocalizedError {
    case registrationFailed(String)
    case invalidRelayURL

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let message): return message
        case .invalidRelayURL: return "Invalid relay URL."
        }
    }
}

struct AuthSignupResponse: Decodable {
    let userId: String
    let sessionToken: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sessionToken = "session_token"
    }
}

/// Optional cloud account registration via orbit-relay.
final class UserAuthService: @unchecked Sendable {
    static let shared = UserAuthService()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var relayURL: URL {
        CloudAIService.defaultRelayURL
    }

    func signUp(email: String, password: String, displayName: String) async throws -> String {
        var request = URLRequest(url: relayURL.appendingPathComponent("/v1/auth/signup"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "email": email,
            "password": password,
            "display_name": displayName,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UserAuthError.registrationFailed("Invalid response from relay.")
        }
        guard http.statusCode == 201 else {
            let message = Self.errorMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw UserAuthError.registrationFailed(message)
        }

        let decoded = try JSONDecoder().decode(AuthSignupResponse.self, from: data)
        UserDefaults.standard.set(decoded.sessionToken, forKey: "orbit.auth.session_token")
        return decoded.userId
    }

    func login(email: String, password: String) async throws -> String {
        var request = URLRequest(url: relayURL.appendingPathComponent("/v1/auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UserAuthError.registrationFailed("Invalid response from relay.")
        }
        guard http.statusCode == 200 else {
            let message = Self.errorMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw UserAuthError.registrationFailed(message)
        }

        let decoded = try JSONDecoder().decode(AuthSignupResponse.self, from: data)
        UserDefaults.standard.set(decoded.sessionToken, forKey: "orbit.auth.session_token")
        return decoded.userId
    }

    var sessionToken: String? {
        UserDefaults.standard.string(forKey: "orbit.auth.session_token")
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        if let detail = obj["detail"] as? [String: Any], let error = detail["error"] as? String {
            return error
        }
        if let error = obj["error"] as? String {
            return error
        }
        return nil
    }
}
