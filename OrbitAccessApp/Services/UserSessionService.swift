import Foundation
import GRDB

struct OrbitUser: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "users"

    let id: String
    let email: String
    let displayName: String
    let createdAt: String
    var cloudUserId: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case createdAt = "created_at"
        case cloudUserId = "cloud_user_id"
    }
}

struct OrbitUserSession: Codable, Sendable {
    let userId: String
    let email: String
    let signedInAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case signedInAt = "signed_in_at"
    }
}

enum UserSessionError: LocalizedError {
    case invalidEmail
    case invalidDisplayName
    case userAlreadyExists
    case userNotFound
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "Enter a valid email address."
        case .invalidDisplayName: return "Enter your name."
        case .userAlreadyExists: return "An account with this email already exists on this Mac."
        case .userNotFound: return "No account found for this email on this Mac. Create an account instead."
        case .persistenceFailed(let detail): return detail
        }
    }
}

@MainActor
@Observable
final class UserSessionService {
    static let shared = UserSessionService()

    private(set) var currentSession: OrbitUserSession?
    private(set) var currentUser: OrbitUser?

    var isSignedIn: Bool { currentSession != nil }

    private init() {
        reloadFromDisk()
    }

    func reloadFromDisk() {
        currentSession = Self.loadSessionFile()
        currentUser = nil
        if let session = currentSession {
            currentUser = try? fetchUser(id: session.userId)
        }
    }

    func signUp(email: String, displayName: String, password: String?) async throws -> OrbitUser {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@"), trimmedEmail.count >= 3 else {
            throw UserSessionError.invalidEmail
        }
        guard trimmedName.count >= 1 else {
            throw UserSessionError.invalidDisplayName
        }

        try OrbitPaths.ensureOrbitDirectoryExists()
        let dbURL = OrbitPaths.databaseURL
        try OrbitSchemaInitializer.createDatabaseIfNeeded(at: dbURL)

        var cloudUserId: String?
        if let password, !password.isEmpty {
            cloudUserId = try await UserAuthService.shared.signUp(
                email: trimmedEmail,
                password: password,
                displayName: trimmedName
            )
        }

        let userId = UUID().uuidString.lowercased()
        let now = ISO8601DateFormatter().string(from: Date())
        let user = OrbitUser(
            id: userId,
            email: trimmedEmail,
            displayName: trimmedName,
            createdAt: now,
            cloudUserId: cloudUserId
        )

        do {
            var config = Configuration()
            config.prepareDatabase { db in
                try db.execute(sql: "PRAGMA foreign_keys=ON;")
            }
            let queue = try DatabaseQueue(path: dbURL.path, configuration: config)
            try await queue.write { db in
                let existing = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM users WHERE email = ?",
                    arguments: [trimmedEmail]
                ) ?? 0
                if existing > 0 {
                    throw UserSessionError.userAlreadyExists
                }
                try user.insert(db)
                try db.execute(
                    sql: """
                    INSERT INTO user_sessions (user_id, last_active_at)
                    VALUES (?, ?)
                    ON CONFLICT(user_id) DO UPDATE SET last_active_at = excluded.last_active_at
                    """,
                    arguments: [userId, now]
                )
            }
        } catch let error as UserSessionError {
            throw error
        } catch {
            throw UserSessionError.persistenceFailed(error.localizedDescription)
        }

        try persistSession(userId: userId, email: trimmedEmail)
        currentSession = Self.loadSessionFile()
        currentUser = user
        return user
    }

    func signIn(email: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmedEmail.contains("@"), trimmedEmail.count >= 3 else {
            throw UserSessionError.invalidEmail
        }

        try OrbitPaths.ensureOrbitDirectoryExists()
        let dbURL = OrbitPaths.databaseURL
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            throw UserSessionError.userNotFound
        }

        var config = Configuration()
        config.readonly = true
        let queue = try DatabaseQueue(path: dbURL.path, configuration: config)
        let user: OrbitUser? = try await queue.read { db in
            try OrbitUser.fetchOne(db, sql: "SELECT * FROM users WHERE email = ?", arguments: [trimmedEmail])
        }

        guard let user else {
            throw UserSessionError.userNotFound
        }

        try persistSession(userId: user.id, email: user.email)
        currentSession = Self.loadSessionFile()
        currentUser = user
    }

    func signOut() throws {
        try? FileManager.default.removeItem(at: OrbitPaths.sessionURL)
        currentSession = nil
        currentUser = nil
    }

    private func fetchUser(id: String) throws -> OrbitUser? {
        var config = Configuration()
        config.readonly = true
        let queue = try DatabaseQueue(path: OrbitPaths.databaseURL.path, configuration: config)
        return try queue.read { db in
            try OrbitUser.fetchOne(db, key: id)
        }
    }

    private func persistSession(userId: String, email: String) throws {
        try OrbitPaths.ensureOrbitDirectoryExists()
        let session = OrbitUserSession(
            userId: userId,
            email: email,
            signedInAt: ISO8601DateFormatter().string(from: Date())
        )
        let data = try JSONEncoder().encode(session)
        try data.write(to: OrbitPaths.sessionURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: OrbitPaths.sessionURL.path)
    }

    private static func loadSessionFile() -> OrbitUserSession? {
        guard let data = try? Data(contentsOf: OrbitPaths.sessionURL) else { return nil }
        return try? JSONDecoder().decode(OrbitUserSession.self, from: data)
    }
}
