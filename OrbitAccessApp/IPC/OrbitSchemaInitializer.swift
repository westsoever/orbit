import Foundation
import GRDB

/// Creates ``~/.orbit/orbit.db`` with the capture schema (FTS + relational tables, no vec0).
enum OrbitSchemaInitializer {
    private static let plainSchemaSQL = """
    CREATE TABLE IF NOT EXISTS context_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT NOT NULL,
      app_bundle_id TEXT,
      app_name TEXT,
      window_title TEXT,
      focused_element_role TEXT,
      focused_element_label TEXT,
      visible_text TEXT,
      raw_json TEXT,
      capture_method TEXT DEFAULT 'ax',
      capture_tier INTEGER DEFAULT 1,
      page_url TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_events_bundle_ts
      ON context_events(app_bundle_id, timestamp);

    CREATE TABLE IF NOT EXISTS text_atoms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER NOT NULL REFERENCES context_events(id) ON DELETE CASCADE,
      role TEXT NOT NULL,
      label TEXT,
      text TEXT NOT NULL,
      element_path TEXT NOT NULL,
      element_hash TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_atoms_event ON text_atoms(event_id);

    CREATE VIRTUAL TABLE IF NOT EXISTS atoms_fts USING fts5(
      text,
      label UNINDEXED,
      role UNINDEXED,
      content='text_atoms',
      content_rowid='id',
      tokenize='unicode61 remove_diacritics 2'
    );
    CREATE TRIGGER IF NOT EXISTS text_atoms_ai AFTER INSERT ON text_atoms BEGIN
      INSERT INTO atoms_fts(rowid, text, label, role) VALUES (new.id, new.text, new.label, new.role);
    END;
    CREATE TRIGGER IF NOT EXISTS text_atoms_ad AFTER DELETE ON text_atoms BEGIN
      INSERT INTO atoms_fts(atoms_fts, rowid, text, label, role) VALUES('delete', old.id, old.text, old.label, old.role);
    END;
    CREATE TRIGGER IF NOT EXISTS text_atoms_au AFTER UPDATE ON text_atoms BEGIN
      INSERT INTO atoms_fts(atoms_fts, rowid, text, label, role) VALUES('delete', old.id, old.text, old.label, old.role);
      INSERT INTO atoms_fts(rowid, text, label, role) VALUES (new.id, new.text, new.label, new.role);
    END;

    CREATE TABLE IF NOT EXISTS task_log (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp        TEXT NOT NULL,
      title            TEXT,
      original_prompt  TEXT,
      approved_prompt  TEXT,
      agent_type       TEXT,
      status           TEXT DEFAULT 'detected',
      exit_code        INTEGER
    );

    CREATE TABLE IF NOT EXISTS fs_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT NOT NULL,
      path TEXT NOT NULL,
      event_type TEXT NOT NULL,
      mtime REAL,
      linked_event_id INTEGER REFERENCES context_events(id) ON DELETE SET NULL,
      capture_tier INTEGER DEFAULT 3
    );
    CREATE INDEX IF NOT EXISTS idx_fs_events_ts ON fs_events(timestamp);
    CREATE INDEX IF NOT EXISTS idx_fs_events_linked ON fs_events(linked_event_id);

    CREATE TABLE IF NOT EXISTS capture_audit (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT NOT NULL,
      capture_method TEXT NOT NULL,
      capture_tier INTEGER NOT NULL,
      atom_count INTEGER NOT NULL,
      app_bundle_id TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_capture_audit_ts ON capture_audit(timestamp);
    """

    static func createDatabaseIfNeeded(at url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode=WAL;")
            try db.execute(sql: "PRAGMA synchronous=NORMAL;")
            try db.execute(sql: "PRAGMA foreign_keys=ON;")
        }

        let queue = try DatabaseQueue(path: url.path, configuration: config)
        try queue.write { db in
            for statement in plainSchemaSQL.split(separator: ";") {
                let sql = statement.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sql.isEmpty else { continue }
                try db.execute(sql: sql)
            }
        }
    }
}
