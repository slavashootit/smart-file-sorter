# ADR 0002: SQLite Storage for Session History and Undo Logs

## Status
Accepted

## Context
Previously, `SmartFileSorter` stored all file sorting history, profiles, and undo operations in raw JSON files (`history.json` and `last_session.json`). This approach suffered from several limitations:
1. **Lack of Transaction Safety**: If the app crashed or was force-closed mid-write, the entire history could be corrupted or lost.
2. **Performance Scaling**: Parsing and writing large JSON structures is slow ($O(N)$ memory and time complexity), leading to main-thread rendering freezes (beachballs) as history grew.
3. **Data Redundancy**: Storing both `history.json` and `last_session.json` led to duplicate writes and out-of-sync states.

## Decision
We migrated the history and session tracking to a SQLite database (`history.db`):
1. **Schema Design**:
   - `batches`: Holds session metadata (UUID, timestamp, profile_name, is_cancelled).
   - `operations`: Holds individual file movements (original path, new path, file size, trash status), with a foreign key referencing `batches(id) ON DELETE CASCADE`.
   - `created_dirs`: Tracks directories created during sorting to allow complete cleanup during undo, with a foreign key referencing `batches(id) ON DELETE CASCADE`.
2. **ACID Compliance**: All insert and undo actions are wrapped in SQL database transactions (`BEGIN TRANSACTION` ... `COMMIT`).
3. **Cascading Rolling Limit**: To avoid unbounded database growth, `HistoryManager` enforces a rolling limit of 50 sessions. Oldest batches are deleted cascadingly when the limit is exceeded.
4. **Startup Migration**: Legacy data is automatically read from legacy JSON paths, written to SQLite, and the original JSON files are renamed to `.bak` to preserve data safety.

## Consequences
- **Robustness**: History writing is fully atomic and transactional. Crash recovery is handled by SQLite natively.
- **Performance**: Reading and writing histories is near-instantaneous, utilizing indexes on `batch_id`.
- **Space Management**: The 50-session cap keeps the database compact.
- **Ease of Use**: Users retain all history seamlessly through the automatic legacy JSON startup migration.
