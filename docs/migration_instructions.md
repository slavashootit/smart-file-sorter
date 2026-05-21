# SmartFileSorter v1.4 Data Migration Guide

This document outlines the transition of configuration data, sorting history, and temporary sessions from the legacy JSON file structure in `v1.3` to the unified SQLite database and configuration system introduced in `v1.4` (Swift version).

---

## 1. Overview of Changes

| Data Type | Legacy Format (v1.3) | New Format (v1.4) | Storage Directory |
| :--- | :--- | :--- | :--- |
| **Sorting History** | `history.json` | `history.db` (SQLite) | `~/Library/Application Support/SmartFileSorter/` |
| **Last Session** | `last_session.json` | `history.db` (SQLite, `batches` table) | `~/Library/Application Support/SmartFileSorter/` |
| **Exclusions** | Hardcoded | `exclusions.json` | `~/Library/Application Support/SmartFileSorter/` |
| **Categories** | Hardcoded | `categories.json` | `~/Library/Application Support/SmartFileSorter/` |
| **Hash Cache** | None (in-memory) | `hash_cache.db` (SQLite) | `~/Library/Application Support/SmartFileSorter/` |

---

## 2. Legacy Storage Paths

During the first startup of version `v1.4`, the application checks the following file system paths for old data:

* **Legacy App History**:
  `~/Library/Application Support/SmartSorter/history.json`
* **Legacy Session (Workspace)**:
  `~/.gemini/antigravity/scratch/file_sorter/last_session.json`
* **Legacy Session (App Support)**:
  `~/Library/Application Support/SmartFileSorter/last_session.json`

---

## 3. Automatic Migration Workflow

The migration is handled entirely in the background by the `HistoryManager` class during app initialization:

1. **Detection**: The manager scans the legacy paths for any existing `history.json` or `last_session.json` files.
2. **Transaction Import**:
   - The contents of `history.json` are decoded from JSON and batch-inserted into the `batches`, `operations`, and `created_dirs` tables in SQLite using a database transaction.
   - The contents of `last_session.json` are parsed, converted to the new `BatchRecord` model, and added to the SQLite history database (unless already imported).
3. **Backup Archival**:
   - To prevent duplicate migrations and secure the database state, successfully imported JSON files are renamed with a `.bak` extension (e.g., `history.json.bak` and `last_session.json.bak`).
   - If an error occurs during parsing or database insertion, the original files are **not** altered, ensuring no data loss.

---

## 4. Manual Rollback / Data Recovery

If you ever need to inspect or revert to the legacy JSON backups:

1. Close the `SmartFileSorter` app.
2. Locate the `.bak` files in the directories mentioned above.
3. Remove the `.bak` extension to restore the original JSON files.
4. You can inspect the files using a text editor or use the Python CLI fallback to read them.

---

## 5. SQLite Schema References

For debugging, the SQLite database `history.db` has the following schema:

```sql
CREATE TABLE IF NOT EXISTS batches (
    id TEXT PRIMARY KEY,
    timestamp REAL,
    profile_name TEXT,
    is_cancelled INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id TEXT,
    original_path TEXT,
    new_path TEXT,
    is_trashed INTEGER,
    file_size INTEGER,
    FOREIGN KEY(batch_id) REFERENCES batches(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS created_dirs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id TEXT,
    path TEXT,
    FOREIGN KEY(batch_id) REFERENCES batches(id) ON DELETE CASCADE
);
```
