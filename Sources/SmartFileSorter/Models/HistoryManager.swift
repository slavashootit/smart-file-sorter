import Foundation
import SQLite3

internal let SQLITE_STATIC = unsafeBitCast(OpaquePointer(bitPattern: 0), to: sqlite3_destructor_type.self)

public struct BatchOperation: Codable, Equatable {
    public let originalPath: String
    public let newPath: String
    public let isTrashed: Bool
    public let fileSize: Int64
    
    public init(originalPath: String, newPath: String, isTrashed: Bool = false, fileSize: Int64 = 0) {
        self.originalPath = originalPath
        self.newPath = newPath
        self.isTrashed = isTrashed
        self.fileSize = fileSize
    }
}

public struct BatchRecord: Codable, Identifiable, Equatable {
    public var id: UUID
    public var timestamp: Date
    public var operations: [BatchOperation]
    public var createdDirs: [String]
    public var profileName: String?
    public var isCancelled: Bool
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), operations: [BatchOperation] = [], createdDirs: [String] = [], profileName: String? = nil, isCancelled: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.operations = operations
        self.createdDirs = createdDirs
        self.profileName = profileName
        self.isCancelled = isCancelled
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case operations
        case createdDirs
        case profileName
        case isCancelled
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        
        if let date = try? container.decode(Date.self, forKey: .timestamp) {
            self.timestamp = date
        } else {
            let timeInterval = try container.decode(TimeInterval.self, forKey: .timestamp)
            self.timestamp = Date(timeIntervalSince1970: timeInterval)
        }
        
        self.operations = try container.decode([BatchOperation].self, forKey: .operations)
        self.createdDirs = try container.decode([String].self, forKey: .createdDirs)
        self.profileName = try container.decodeIfPresent(String.self, forKey: .profileName)
        self.isCancelled = try container.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
    }
}

/// SQLite Database Wrapper
private final class SQLiteHistoryDatabase {
    private var db: OpaquePointer?
    
    init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            let errmsg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            throw NSError(domain: "SQLiteHistoryDatabase", code: 1, userInfo: [NSLocalizedDescriptionKey: errmsg])
        }
        
        // Enable foreign keys
        try execute(sql: "PRAGMA foreign_keys = ON;")
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    func execute(sql: String) throws {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw getLastError()
        }
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            throw getLastError()
        }
    }
    
    func beginTransaction() throws {
        try execute(sql: "BEGIN TRANSACTION;")
    }
    
    func commitTransaction() throws {
        try execute(sql: "COMMIT;")
    }
    
    func rollbackTransaction() {
        try? execute(sql: "ROLLBACK;")
    }
    
    func getLastError() -> Error {
        let errmsg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
        return NSError(domain: "SQLiteHistoryDatabase", code: 1, userInfo: [NSLocalizedDescriptionKey: errmsg])
    }
    
    func createTables() throws {
        let createBatches = """
        CREATE TABLE IF NOT EXISTS batches (
            id TEXT PRIMARY KEY,
            timestamp REAL,
            profile_name TEXT,
            is_cancelled INTEGER DEFAULT 0
        );
        """
        let createOperations = """
        CREATE TABLE IF NOT EXISTS operations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            batch_id TEXT,
            original_path TEXT,
            new_path TEXT,
            is_trashed INTEGER,
            file_size INTEGER,
            FOREIGN KEY(batch_id) REFERENCES batches(id) ON DELETE CASCADE
        );
        """
        let createCreatedDirs = """
        CREATE TABLE IF NOT EXISTS created_dirs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            batch_id TEXT,
            path TEXT,
            FOREIGN KEY(batch_id) REFERENCES batches(id) ON DELETE CASCADE
        );
        """
        try execute(sql: createBatches)
        try execute(sql: createOperations)
        try execute(sql: createCreatedDirs)
        
        try? execute(sql: "CREATE INDEX IF NOT EXISTS idx_operations_batch ON operations(batch_id);")
        try? execute(sql: "CREATE INDEX IF NOT EXISTS idx_created_dirs_batch ON created_dirs(batch_id);")
    }
    
    func insertBatch(_ batch: BatchRecord) throws {
        let insertBatchSQL = "INSERT INTO batches (id, timestamp, profile_name, is_cancelled) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertBatchSQL, -1, &stmt, nil) != SQLITE_OK {
            throw getLastError()
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, batch.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, batch.timestamp.timeIntervalSince1970)
        if let profile = batch.profileName {
            sqlite3_bind_text(stmt, 3, profile, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        sqlite3_bind_int(stmt, 4, batch.isCancelled ? 1 : 0)
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw getLastError()
        }
        
        // Insert operations
        let insertOpSQL = "INSERT INTO operations (batch_id, original_path, new_path, is_trashed, file_size) VALUES (?, ?, ?, ?, ?);"
        var opStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertOpSQL, -1, &opStmt, nil) != SQLITE_OK {
            throw getLastError()
        }
        defer { sqlite3_finalize(opStmt) }
        
        for op in batch.operations {
            sqlite3_reset(opStmt)
            sqlite3_bind_text(opStmt, 1, batch.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(opStmt, 2, op.originalPath, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(opStmt, 3, op.newPath, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(opStmt, 4, op.isTrashed ? 1 : 0)
            sqlite3_bind_int64(opStmt, 5, op.fileSize)
            
            if sqlite3_step(opStmt) != SQLITE_DONE {
                throw getLastError()
            }
        }
        
        // Insert created dirs
        let insertDirSQL = "INSERT INTO created_dirs (batch_id, path) VALUES (?, ?);"
        var dirStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertDirSQL, -1, &dirStmt, nil) != SQLITE_OK {
            throw getLastError()
        }
        defer { sqlite3_finalize(dirStmt) }
        
        for dir in batch.createdDirs {
            sqlite3_reset(dirStmt)
            sqlite3_bind_text(dirStmt, 1, batch.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(dirStmt, 2, dir, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(dirStmt) != SQLITE_DONE {
                throw getLastError()
            }
        }
    }
    
    func deleteOldestBatchesKeeping(limit: Int) throws {
        let countSQL = "SELECT COUNT(*) FROM batches;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, countSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw getLastError()
        }
        defer { sqlite3_finalize(stmt) }
        
        var count = 0
        if sqlite3_step(stmt) == SQLITE_ROW {
            count = Int(sqlite3_column_int(stmt, 0))
        }
        
        if count > limit {
            let deleteCount = count - limit
            let deleteSQL = """
            DELETE FROM batches WHERE id IN (
                SELECT id FROM batches ORDER BY timestamp ASC LIMIT ?
            );
            """
            var delStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSQL, -1, &delStmt, nil) == SQLITE_OK {
                sqlite3_bind_int(delStmt, 1, Int32(deleteCount))
                sqlite3_step(delStmt)
                sqlite3_finalize(delStmt)
            }
        }
    }
    
    func deleteBatch(id: UUID) throws {
        let deleteSQL = "DELETE FROM batches WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) != SQLITE_OK {
            throw getLastError()
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw getLastError()
        }
    }
    
    func clearAll() throws {
        try execute(sql: "DELETE FROM batches;")
    }
    
    func fetchBatches() throws -> [BatchRecord] {
        var batches: [BatchRecord] = []
        
        let queryBatchesSQL = "SELECT id, timestamp, profile_name, is_cancelled FROM batches ORDER BY timestamp ASC;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, queryBatchesSQL, -1, &stmt, nil) != SQLITE_OK {
            throw getLastError()
        }
        defer { sqlite3_finalize(stmt) }
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idString = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                  let id = UUID(uuidString: idString) else {
                continue
            }
            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let profileName = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let isCancelled = sqlite3_column_int(stmt, 3) != 0
            
            batches.append(BatchRecord(id: id, timestamp: timestamp, operations: [], createdDirs: [], profileName: profileName, isCancelled: isCancelled))
        }
        
        for i in 0..<batches.count {
            let batchId = batches[i].id.uuidString
            
            let queryOpsSQL = "SELECT original_path, new_path, is_trashed, file_size FROM operations WHERE batch_id = ?;"
            var opStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, queryOpsSQL, -1, &opStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(opStmt, 1, batchId, -1, SQLITE_TRANSIENT)
                while sqlite3_step(opStmt) == SQLITE_ROW {
                    let original = sqlite3_column_text(opStmt, 0).map { String(cString: $0) } ?? ""
                    let newPath = sqlite3_column_text(opStmt, 1).map { String(cString: $0) } ?? ""
                    let isTrashed = sqlite3_column_int(opStmt, 2) != 0
                    let fileSize = sqlite3_column_int64(opStmt, 3)
                    
                    batches[i].operations.append(BatchOperation(originalPath: original, newPath: newPath, isTrashed: isTrashed, fileSize: fileSize))
                }
                sqlite3_finalize(opStmt)
            }
            
            let queryDirsSQL = "SELECT path FROM created_dirs WHERE batch_id = ?;"
            var dirStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, queryDirsSQL, -1, &dirStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(dirStmt, 1, batchId, -1, SQLITE_TRANSIENT)
                while sqlite3_step(dirStmt) == SQLITE_ROW {
                    let path = sqlite3_column_text(dirStmt, 0).map { String(cString: $0) } ?? ""
                    batches[i].createdDirs.append(path)
                }
                sqlite3_finalize(dirStmt)
            }
        }
        
        return batches
    }
}

/// Менеджер історії для збереження партій сортування та підтримки Undo (SQLite)
public class HistoryManager: ObservableObject {
    
    public static let shared = HistoryManager()
    
    public func setDatabasePath(_ path: String) {
        dbLock.lock()
        db = nil
        do {
            let fileManager = FileManager.default
            let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            }
            db = try SQLiteHistoryDatabase(path: path)
            try db?.createTables()
            print("[HISTORY] Реініціалізовано базу даних SQLite за новим шляхом: \(path)")
        } catch {
            print("[HISTORY] Помилка реініціалізації SQLite за шляхом \(path): \(error.localizedDescription)")
        }
        dbLock.unlock()
        loadHistoryFromDB()
    }
    
    @Published private var batches: [BatchRecord] = []
    
    private var db: SQLiteHistoryDatabase?
    private let dbLock = NSLock()
    
    public var historyDirectoryURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SmartFileSorter")
    }
    
    public var databaseFileURL: URL {
        return historyDirectoryURL.appendingPathComponent("history.db")
    }
    
    public init() {
        setupDatabase()
        migrateLegacyDataIfNeeded()
        loadHistoryFromDB()
    }
    
    private func setupDatabase() {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: historyDirectoryURL.path) {
            try? fileManager.createDirectory(at: historyDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        do {
            db = try SQLiteHistoryDatabase(path: databaseFileURL.path)
            try db?.createTables()
            print("[HISTORY] Базу даних SQLite успішно ініціалізовано")
        } catch {
            print("[HISTORY] Критична помилка ініціалізації SQLite: \(error.localizedDescription)")
        }
    }
    
    private func loadHistoryFromDB() {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        do {
            let dbBatches = try db?.fetchBatches() ?? []
            DispatchQueue.main.async {
                self.batches = dbBatches
            }
            print("[HISTORY] Завантажено \(dbBatches.count) сесій з SQLite")
        } catch {
            print("[HISTORY] Помилка завантаження з SQLite: \(error.localizedDescription)")
        }
    }
    
    private func migrateLegacyDataIfNeeded() {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 1. Шлях до legacy history.json
        let legacyHistoryDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SmartSorter")
        let legacyHistoryURL = legacyHistoryDir.appendingPathComponent("history.json")
        
        // 2. Шляхи до legacy last_session.json
        let workspaceSessionURL = home.appendingPathComponent(".gemini/antigravity/scratch/file_sorter/last_session.json")
        let appSupportSessionURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SmartFileSorter")
            .appendingPathComponent("last_session.json")
        
        // Міграція history.json
        if fileManager.fileExists(atPath: legacyHistoryURL.path) {
            print("[HISTORY] Виявлено legacy history.json. Початок міграції...")
            do {
                let data = try Data(contentsOf: legacyHistoryURL)
                let legacyBatches = try JSONDecoder().decode([BatchRecord].self, from: data)
                
                try db?.beginTransaction()
                for batch in legacyBatches {
                    try db?.insertBatch(batch)
                }
                try db?.commitTransaction()
                print("[HISTORY] Міграція history.json завершена успішно. Імпортовано \(legacyBatches.count) сесій.")
                
                // Перейменовуємо старий файл на .bak тільки у разі успіху
                let backupURL = legacyHistoryURL.appendingPathExtension("bak")
                try? fileManager.removeItem(at: backupURL)
                try fileManager.moveItem(at: legacyHistoryURL, to: backupURL)
                print("[HISTORY] Старий history.json перейменовано на history.json.bak")
            } catch {
                db?.rollbackTransaction()
                print("[HISTORY] Помилка міграції history.json: \(error.localizedDescription)")
                // НЕ перейменовуємо на .bak якщо виникла помилка, щоб не втратити дані
            }
        }
        
        // Міграція last_session.json
        for sessionURL in [workspaceSessionURL, appSupportSessionURL] {
            if fileManager.fileExists(atPath: sessionURL.path) {
                print("[HISTORY] Виявлено legacy last_session.json за шляхом \(sessionURL.path). Початок міграції...")
                do {
                    let data = try Data(contentsOf: sessionURL)
                    let session = try JSONDecoder().decode(SessionHistory.self, from: data)
                    
                    let existing = try db?.fetchBatches() ?? []
                    let sessionOps = session.moves.map { move -> BatchOperation in
                        let size = (try? fileManager.attributesOfItem(atPath: move.new)[.size] as? Int64) ?? 0
                        let isTrash = move.new.contains("/.Trash/") || move.new.contains("/Trash/")
                        return BatchOperation(originalPath: move.original, newPath: move.new, isTrashed: isTrash, fileSize: size)
                    }
                    
                    let alreadyImported = existing.contains { batch in
                        batch.operations.count == sessionOps.count &&
                        batch.operations.first?.originalPath == sessionOps.first?.originalPath
                    }
                    
                    if !alreadyImported && !sessionOps.isEmpty {
                        let activeProfile = UserDefaults.standard.string(forKey: "active_profile") ?? "Home"
                        let batch = BatchRecord(
                            id: UUID(),
                            timestamp: Date(),
                            operations: sessionOps,
                            createdDirs: session.created_dirs,
                            profileName: activeProfile
                        )
                        try db?.beginTransaction()
                        try db?.insertBatch(batch)
                        try db?.commitTransaction()
                        print("[HISTORY] Імпортовано session з last_session.json")
                    }
                    
                    // Перейменовуємо на .bak тільки у разі успіху
                    let backupURL = sessionURL.appendingPathExtension("bak")
                    try? fileManager.removeItem(at: backupURL)
                    try fileManager.moveItem(at: sessionURL, to: backupURL)
                    print("[HISTORY] Старий last_session.json перейменовано на last_session.json.bak")
                } catch {
                    db?.rollbackTransaction()
                    print("[HISTORY] Помилка міграції last_session.json: \(error.localizedDescription)")
                    // НЕ перейменовуємо на .bak якщо виникла помилка, щоб не втратити дані
                }
            }
        }
    }
    
    /// Додати нову партію сортування в історію
    public func addBatch(_ batch: BatchRecord) {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        do {
            try db?.beginTransaction()
            try db?.insertBatch(batch)
            try db?.deleteOldestBatchesKeeping(limit: 50)
            try db?.commitTransaction()
            print("[HISTORY] Партію сортування додано в SQLite")
        } catch {
            db?.rollbackTransaction()
            print("[HISTORY] Помилка збереження партії в SQLite: \(error.localizedDescription)")
        }
        
        dbLock.unlock()
        loadHistoryFromDB()
        dbLock.lock()
    }
    
    /// Отримати список партій
    public func getBatches() -> [BatchRecord] {
        dbLock.lock()
        defer { dbLock.unlock() }
        return batches
    }
    
    /// Очищення всієї історії
    public func clearAllHistory() {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        do {
            try db?.clearAll()
            print("[HISTORY] Усю історію очищено з SQLite")
        } catch {
            print("[HISTORY] Помилка очищення історії в SQLite: \(error.localizedDescription)")
        }
        
        dbLock.unlock()
        loadHistoryFromDB()
        dbLock.lock()
    }
    
    /// Перевірка чи є записи в історії
    public func checkHistoryExists() -> Bool {
        dbLock.lock()
        defer { dbLock.unlock() }
        if let db = db, let count = try? db.fetchBatches().count {
            return count > 0
        }
        return !batches.isEmpty
    }
    
    /// Безпечне перенесення об'єкта до Смітника (Trash)
    public func trashItem(at url: URL) -> URL? {
        let fileManager = FileManager.default
        do {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
            if let resultPath = resultingURL?.path {
                print("[HISTORY] Успішно перенесено у Смітник: \(url.lastPathComponent) -> \(resultPath)")
                return resultingURL as URL?
            }
            return nil
        } catch {
            print("[HISTORY] Помилка видалення в Смітник для \(url.path): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Скасування останньої партії сортування (Undo)
    public func undoLastBatch() -> [String] {
        dbLock.lock()
        
        let currentBatches = (try? db?.fetchBatches()) ?? batches
        guard let lastBatch = currentBatches.last else {
            dbLock.unlock()
            return ["Немає збереженої історії попереднього сортування."]
        }
        
        dbLock.unlock()
        
        var logs: [String] = []
        logs.append("--- Скасування останнього сортування ---")
        
        let fileManager = FileManager.default
        var successCount = 0
        var failCount = 0
        
        // Відновлюємо файли з кінця черги
        for op in lastBatch.operations.reversed() {
            let currentURL = URL(fileURLWithPath: op.newPath)
            let originalURL = URL(fileURLWithPath: op.originalPath)
            
            if fileManager.fileExists(atPath: currentURL.path) {
                do {
                    let parentDir = originalURL.deletingLastPathComponent()
                    if !fileManager.fileExists(atPath: parentDir.path) {
                        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
                    }
                    try fileManager.moveItem(at: currentURL, to: originalURL)
                    logs.append("[ВІДНОВЛЕНО] '\(originalURL.lastPathComponent)' повернуто")
                    successCount += 1
                } catch {
                    logs.append("[ПОМИЛКА] Не вдалося відновити '\(currentURL.lastPathComponent)': \(error.localizedDescription)")
                    failCount += 1
                }
            } else {
                logs.append("[ПОМИЛКА] Об'єкт не знайдено в місці призначення: '\(currentURL.path)'")
                failCount += 1
            }
        }
        
        // Видаляємо створені порожні директорії
        for dirPath in lastBatch.createdDirs.reversed() {
            let dirURL = URL(fileURLWithPath: dirPath)
            if fileManager.fileExists(atPath: dirURL.path) {
                if let contents = try? fileManager.contentsOfDirectory(atPath: dirURL.path), contents.isEmpty {
                    do {
                        try fileManager.removeItem(at: dirURL)
                        logs.append("[ВИДАЛЕНО] Очищено створену порожню папку '\(dirURL.lastPathComponent)'")
                    } catch {
                        // Ігноруємо помилки очищення папок
                    }
                }
            }
        }
        
        dbLock.lock()
        do {
            try db?.deleteBatch(id: lastBatch.id)
            print("[HISTORY] Видалено сесію \(lastBatch.id) з SQLite")
        } catch {
            print("[HISTORY] Помилка видалення сесії з SQLite: \(error.localizedDescription)")
        }
        dbLock.unlock()
        
        loadHistoryFromDB()
        
        logs.append("\n--- Скасування завершено ---")
        logs.append("Успішно відновлено: \(successCount)")
        if failCount > 0 {
            logs.append("Помилок відновлення: \(failCount)")
        }
        
        return logs
    }
}
