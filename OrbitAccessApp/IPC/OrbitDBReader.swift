import Foundation
import Security
import AppKit
import UniformTypeIdentifiers
import GRDB

enum OrbitDBError: LocalizedError {
    case bookmarkMissing
    case bookmarkStale
    case databaseUnavailable
    case openPanelCancelled

    var errorDescription: String? {
        switch self {
        case .bookmarkMissing: return "Orbit database bookmark not found."
        case .bookmarkStale: return "Orbit database bookmark is stale."
        case .databaseUnavailable: return "Orbit database is unavailable."
        case .openPanelCancelled: return "Database selection was cancelled."
        }
    }
}

final class OrbitDBReader: @unchecked Sendable {
    private let keychainService = "com.orbit.access"
    private let keychainAccount = "orbit-db-bookmark"
    private var accessURL: URL?
    private(set) var pool: DatabasePool?

    var isReady: Bool { pool != nil }

    @MainActor
    func bootstrap() async throws {
        if let url = resolveBookmarkURL() {
            try openDatabase(at: url)
            return
        }
        let defaultURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".orbit/orbit.db")
        if FileManager.default.fileExists(atPath: defaultURL.path) {
            let url = try await promptForDatabase(defaultURL: defaultURL)
            try storeBookmark(for: url)
            try openDatabase(at: url)
            return
        }
        let url = try await promptForDatabase(defaultURL: defaultURL)
        try storeBookmark(for: url)
        try openDatabase(at: url)
    }

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        guard let pool else { throw OrbitDBError.databaseUnavailable }
        return try pool.read(block)
    }

    func fetchRecentCaptures(afterId: Int64, limit: Int = 10) throws -> [ContextEvent] {
        try read { db in
            try ContextEvent
                .filter(Column("id") > afterId)
                .order(Column("id").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func fetchRecentCapturesTail(limit: Int = 10) throws -> [ContextEvent] {
        try read { db in
            try ContextEvent.order(Column("id").desc).limit(limit).fetchAll(db)
        }
    }

    func lexicalSearch(_ query: String, limit: Int = 20) throws -> [SearchHit] {
        try read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    a.id AS atom_id,
                    a.event_id AS event_id,
                    e.app_bundle_id AS app_bundle_id,
                    e.app_name AS app_name,
                    e.window_title AS window_title,
                    e.timestamp AS timestamp,
                    a.role AS role,
                    a.label AS label,
                    snippet(atoms_fts, 2, '<b>', '</b>', '…', 32) AS snippet_html,
                    bm25(atoms_fts) AS score
                FROM atoms_fts
                JOIN text_atoms a ON a.id = atoms_fts.rowid
                JOIN context_events e ON e.id = a.event_id
                WHERE atoms_fts MATCH ?
                ORDER BY score
                LIMIT ?
                """, arguments: [query, limit])
            return rows.map { row in
                SearchHit(
                    atomId: row["atom_id"],
                    eventId: row["event_id"],
                    atomUri: "orbit://atom/\(row["atom_id"] as Int)",
                    eventUri: "orbit://event/\(row["event_id"] as Int)",
                    appBundleId: row["app_bundle_id"] ?? "",
                    appName: row["app_name"] ?? "",
                    windowTitle: row["window_title"],
                    timestamp: row["timestamp"],
                    role: row["role"],
                    label: row["label"],
                    snippetHtml: row["snippet_html"] ?? "",
                    score: row["score"] ?? 0
                )
            }
        }
    }

    func fetchAtomsByApp(_ appName: String, limit: Int = 20) throws -> [SearchHit] {
        try read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    a.id AS atom_id,
                    a.event_id AS event_id,
                    e.app_bundle_id AS app_bundle_id,
                    e.app_name AS app_name,
                    e.window_title AS window_title,
                    e.timestamp AS timestamp,
                    a.role AS role,
                    a.label AS label,
                    a.text AS snippet_html,
                    0.0 AS score
                FROM text_atoms a
                JOIN context_events e ON e.id = a.event_id
                WHERE e.app_name LIKE ?
                ORDER BY e.timestamp DESC
                LIMIT ?
                """, arguments: ["%\(appName)%", limit])
            return rows.map { Self.searchHit(from: $0) }
        }
    }

    func fetchAtomsByHour(_ hour: String?, limit: Int = 20) throws -> [SearchHit] {
        try read { db in
            let rows: [Row]
            if let hour, !hour.isEmpty {
                let normalized = hour.count == 1 ? "0\(hour)" : String(hour.prefix(2))
                rows = try Row.fetchAll(db, sql: """
                    SELECT
                        a.id AS atom_id,
                        a.event_id AS event_id,
                        e.app_bundle_id AS app_bundle_id,
                        e.app_name AS app_name,
                        e.window_title AS window_title,
                        e.timestamp AS timestamp,
                        a.role AS role,
                        a.label AS label,
                        a.text AS snippet_html,
                        0.0 AS score
                    FROM text_atoms a
                    JOIN context_events e ON e.id = a.event_id
                    WHERE date(e.timestamp) = date('now')
                      AND strftime('%H', e.timestamp) = ?
                    ORDER BY e.timestamp DESC
                    LIMIT ?
                    """, arguments: [normalized, limit])
            } else {
                rows = try Row.fetchAll(db, sql: """
                    SELECT
                        a.id AS atom_id,
                        a.event_id AS event_id,
                        e.app_bundle_id AS app_bundle_id,
                        e.app_name AS app_name,
                        e.window_title AS window_title,
                        e.timestamp AS timestamp,
                        a.role AS role,
                        a.label AS label,
                        a.text AS snippet_html,
                        0.0 AS score
                    FROM text_atoms a
                    JOIN context_events e ON e.id = a.event_id
                    WHERE date(e.timestamp) = date('now')
                    ORDER BY e.timestamp DESC
                    LIMIT ?
                    """, arguments: [limit])
            }
            return rows.map { Self.searchHit(from: $0) }
        }
    }

    func atomsCapturedToday() throws -> Int {
        try read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*)
                FROM text_atoms a
                JOIN context_events e ON e.id = a.event_id
                WHERE date(e.timestamp) = date('now')
                """) ?? 0
        }
    }

    func computeScoreInputs() throws -> ScoreInputs {
        try read { db in
            let taskRow = try Row.fetchOne(db, sql: """
                SELECT
                    SUM(CASE WHEN status IN ('approved','dispatched') THEN 1 ELSE 0 END) AS done,
                    SUM(CASE WHEN status = 'detected' THEN 1 ELSE 0 END) AS pending
                FROM task_log
                WHERE date(timestamp) = date('now')
                """)
            let done = Double(taskRow?["done"] ?? 0)
            let pending = Double(taskRow?["pending"] ?? 0)
            let taskCompletion = done / max(1, done + pending)

            let focusRows = try Row.fetchAll(db, sql: """
                SELECT app_bundle_id, COUNT(*) AS c
                FROM context_events
                WHERE date(timestamp) = date('now')
                GROUP BY app_bundle_id
                """)
            let counts: [Double] = focusRows.map { Double($0["c"] as Int64) }
            let total = counts.reduce(0, +)
            let topShare = total > 0 ? (counts.max() ?? 0) / total : 0
            let focusDepth = min(1, topShare / 0.7)

            let atoms = Double(try Int.fetchOne(db, sql: """
                SELECT COUNT(*)
                FROM text_atoms a
                JOIN context_events e ON e.id = a.event_id
                WHERE date(e.timestamp) = date('now')
                """) ?? 0)
            let contextRichness = min(1, atoms / 500)

            let hours = Double(try Int.fetchOne(db, sql: """
                SELECT COUNT(DISTINCT strftime('%H', timestamp))
                FROM context_events
                WHERE date(timestamp) = date('now')
                  AND strftime('%H', timestamp) BETWEEN '09' AND '17'
                """) ?? 0)
            let captureConsistency = min(1, hours / 8)

            return ScoreInputs(
                taskCompletion: taskCompletion,
                focusDepth: focusDepth,
                contextRichness: contextRichness,
                captureConsistency: captureConsistency
            )
        }
    }

    func walURL() -> URL? {
        accessURL?.deletingLastPathComponent().appendingPathComponent("orbit.db-wal")
    }

    private static func searchHit(from row: Row) -> SearchHit {
        SearchHit(
            atomId: row["atom_id"],
            eventId: row["event_id"],
            atomUri: "orbit://atom/\(row["atom_id"] as Int)",
            eventUri: "orbit://event/\(row["event_id"] as Int)",
            appBundleId: row["app_bundle_id"] ?? "",
            appName: row["app_name"] ?? "",
            windowTitle: row["window_title"],
            timestamp: row["timestamp"],
            role: row["role"],
            label: row["label"],
            snippetHtml: row["snippet_html"] ?? "",
            score: row["score"] ?? 0
        )
    }

    private func resolveBookmarkURL() -> URL? {
        guard let data = KeychainHelper.load(service: keychainService, account: keychainAccount) else {
            return nil
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        if isStale, let refreshed = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            KeychainHelper.save(refreshed, service: keychainService, account: keychainAccount)
        }
        _ = url.startAccessingSecurityScopedResource()
        accessURL = url
        return url
    }

    @MainActor
    private func promptForDatabase(defaultURL: URL) async throws -> URL {
        let panel = NSOpenPanel()
        panel.title = "Select Orbit Database"
        panel.message = "Choose orbit.db from your ~/.orbit directory."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "orbit.db"
        panel.directoryURL = defaultURL.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else {
            throw OrbitDBError.openPanelCancelled
        }
        return url
    }

    private func storeBookmark(for url: URL) throws {
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        KeychainHelper.save(data, service: keychainService, account: keychainAccount)
        _ = url.startAccessingSecurityScopedResource()
        accessURL = url
    }

    private func openDatabase(at url: URL) throws {
        var config = Configuration()
        config.readonly = true
        pool = try DatabasePool(path: url.path, configuration: config)
    }
}

private enum KeychainHelper {
    static func save(_ data: Data, service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }
}
