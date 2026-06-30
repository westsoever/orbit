import Foundation
import GRDB

enum OrbitDBError: LocalizedError {
    case databaseUnavailable
    case setupFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseUnavailable: return "Orbit database is unavailable."
        case .setupFailed(let detail): return "Could not set up Orbit database: \(detail)"
        }
    }
}

final class OrbitDBReader: @unchecked Sendable {
    private var accessURL: URL?
    private(set) var pool: DatabasePool?

    var isReady: Bool { pool != nil }

    private var activeUserId: String? {
        UserSessionService.shared.currentSession?.userId
    }

    private func userEventFilter(column: String = "e.user_id") -> (sql: String, arguments: [DatabaseValueConvertible]) {
        guard let uid = activeUserId else { return ("", []) }
        return (" AND \(column) = ?", [uid])
    }

    @MainActor
    func bootstrap() async throws {
        let url = OrbitPaths.databaseURL
        do {
            try OrbitPaths.ensureOrbitDirectoryExists()
            try OrbitSchemaInitializer.createDatabaseIfNeeded(at: url)
            accessURL = url
            try openDatabase(at: url)
        } catch let error as OrbitDBError {
            throw error
        } catch {
            throw OrbitDBError.setupFailed(error.localizedDescription)
        }
    }

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        guard let pool else { throw OrbitDBError.databaseUnavailable }
        return try pool.read(block)
    }

    func fetchRecentNotes(afterId: Int64, limit: Int = 10) throws -> [SearchHit] {
        let filter = userEventFilter()
        return try read { db in
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
                WHERE a.id > ? AND length(trim(a.text)) > 10\(filter.sql)
                ORDER BY a.id DESC
                LIMIT ?
                """, arguments: [afterId] + filter.arguments + [limit])
            return rows.map { Self.searchHit(from: $0) }
        }
    }

    func fetchRecentNotesTail(limit: Int = 10) throws -> [SearchHit] {
        let filter = userEventFilter()
        return try read { db in
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
                WHERE length(trim(a.text)) > 10\(filter.sql)
                ORDER BY a.id DESC
                LIMIT ?
                """, arguments: filter.arguments + [limit])
            return rows.map { Self.searchHit(from: $0) }
        }
    }

    func lexicalSearch(_ query: String, limit: Int = 20) throws -> [SearchHit] {
        let filter = userEventFilter()
        return try read { db in
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
                WHERE atoms_fts MATCH ?\(filter.sql)
                ORDER BY score
                LIMIT ?
                """, arguments: [query] + filter.arguments + [limit])
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
        let filter = userEventFilter()
        return try read { db in
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
                WHERE e.app_name LIKE ?\(filter.sql)
                ORDER BY e.timestamp DESC
                LIMIT ?
                """, arguments: ["%\(appName)%"] + filter.arguments + [limit])
            return rows.map { Self.searchHit(from: $0) }
        }
    }

    func fetchAtomsByHour(_ hour: String?, limit: Int = 20) throws -> [SearchHit] {
        let filter = userEventFilter()
        return try read { db in
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
                      AND strftime('%H', e.timestamp) = ?\(filter.sql)
                    ORDER BY e.timestamp DESC
                    LIMIT ?
                    """, arguments: [normalized] + filter.arguments + [limit])
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
                    WHERE date(e.timestamp) = date('now')\(filter.sql)
                    ORDER BY e.timestamp DESC
                    LIMIT ?
                    """, arguments: filter.arguments + [limit])
            }
            return rows.map { Self.searchHit(from: $0) }
        }
    }

    func atomsCapturedToday() throws -> Int {
        let filter = userEventFilter()
        return try read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*)
                FROM text_atoms a
                JOIN context_events e ON e.id = a.event_id
                WHERE date(e.timestamp) = date('now')\(filter.sql)
                """, arguments: filter.arguments) ?? 0
        }
    }

    func computeScoreInputs() throws -> ScoreInputs {
        let filter = userEventFilter(column: "user_id")
        let taskFilter = userEventFilter(column: "user_id")
        return try read { db in
            let taskRow = try Row.fetchOne(db, sql: """
                SELECT
                    SUM(CASE WHEN status IN ('approved','dispatched') THEN 1 ELSE 0 END) AS done,
                    SUM(CASE WHEN status = 'detected' THEN 1 ELSE 0 END) AS pending
                FROM task_log
                WHERE date(timestamp) = date('now')\(taskFilter.sql)
                """, arguments: taskFilter.arguments)
            let done = Double(taskRow?["done"] ?? 0)
            let pending = Double(taskRow?["pending"] ?? 0)
            let taskCompletion = done / max(1, done + pending)

            let focusRows = try Row.fetchAll(db, sql: """
                SELECT app_bundle_id, COUNT(*) AS c
                FROM context_events
                WHERE date(timestamp) = date('now')\(filter.sql)
                GROUP BY app_bundle_id
                """, arguments: filter.arguments)
            let counts: [Double] = focusRows.map { Double($0["c"] as Int64) }
            let total = counts.reduce(0, +)
            let topShare = total > 0 ? (counts.max() ?? 0) / total : 0
            let focusDepth = min(1, topShare / 0.7)

            let atoms = Double(try Int.fetchOne(db, sql: """
                SELECT COUNT(*)
                FROM text_atoms a
                JOIN context_events e ON e.id = a.event_id
                WHERE date(e.timestamp) = date('now')\(filter.sql)
                """, arguments: filter.arguments) ?? 0)
            let contextRichness = min(1, atoms / 500)

            let hours = Double(try Int.fetchOne(db, sql: """
                SELECT COUNT(DISTINCT strftime('%H', timestamp))
                FROM context_events
                WHERE date(timestamp) = date('now')
                  AND strftime('%H', timestamp) BETWEEN '09' AND '17'\(filter.sql)
                """, arguments: filter.arguments) ?? 0)
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

    /// Pending tasks for today — SQL from orbit/check/log.py get_pending_today
    func fetchPendingTasksToday(reportDate: String? = nil) throws -> [TaskLogEntry] {
        let date = reportDate ?? Self.localTodayISO()
        let filter = userEventFilter(column: "user_id")
        do {
            return try fetchPendingTasksTodayRows(
                includeDescription: true,
                reportDate: date,
                userFilter: filter
            )
        } catch {
            return try fetchPendingTasksTodayRows(
                includeDescription: false,
                reportDate: date,
                userFilter: filter
            )
        }
    }

    private func fetchPendingTasksTodayRows(
        includeDescription: Bool,
        reportDate: String,
        userFilter: (sql: String, arguments: [DatabaseValueConvertible])
    ) throws -> [TaskLogEntry] {
        try read { db in
            let sql: String
            if includeDescription {
                sql = """
                    SELECT id, title, description, original_prompt, agent_type
                    FROM task_log
                    WHERE status = 'detected' AND date(timestamp) = ?\(userFilter.sql)
                    """
            } else {
                sql = """
                    SELECT id, title, original_prompt, agent_type
                    FROM task_log
                    WHERE status = 'detected' AND date(timestamp) = ?\(userFilter.sql)
                    """
            }
            let rows = try Row.fetchAll(db, sql: sql, arguments: [reportDate] + userFilter.arguments)
            return rows.map { row in
                TaskLogEntry(
                    id: row["id"],
                    title: row["title"],
                    description: includeDescription ? row["description"] : nil,
                    originalPrompt: row["original_prompt"],
                    agentType: row["agent_type"],
                    status: "detected"
                )
            }
        }
    }

    private static func localTodayISO() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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

    private func openDatabase(at url: URL) throws {
        var config = Configuration()
        config.readonly = true
        pool = try DatabasePool(path: url.path, configuration: config)
    }
}
