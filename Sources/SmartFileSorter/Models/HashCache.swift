import Foundation
import SQLite3

internal let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

public final class CacheEntry: NSObject {
    public let size: Int64
    public let mtime: Double
    public let pass1: String
    public let pass2: String?
    
    public init(size: Int64, mtime: Double, pass1: String, pass2: String?) {
        self.size = size
        self.mtime = mtime
        self.pass1 = pass1
        self.pass2 = pass2
    }
}

public actor HashCache {
    public static let shared = HashCache()
    
    private var db: OpaquePointer?
    private let memoryCache = NSCache<NSString, CacheEntry>()
    
    public init(databaseURL: URL? = nil) {
        let fileManager = FileManager.default
        let dbURL: URL
        if let customURL = databaseURL {
            dbURL = customURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let directoryURL = appSupport.appendingPathComponent("SmartFileSorter")
            if !fileManager.fileExists(atPath: directoryURL.path) {
                try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            dbURL = directoryURL.appendingPathComponent("hash_cache.db")
        }
        
        if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
            // Enable WAL mode
            sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
            
            let sql = """
            CREATE TABLE IF NOT EXISTS hash_cache (
                file_path TEXT PRIMARY KEY,
                file_size INTEGER NOT NULL,
                modification_time REAL NOT NULL,
                pass1_hash TEXT NOT NULL,
                pass2_hash TEXT,
                last_accessed REAL NOT NULL
            );
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("[HashCache] Failed to create table")
                }
            }
            sqlite3_finalize(stmt)
        } else {
            print("[HashCache] Failed to open database")
        }
        
        // Automatically evict stale entries on startup
        Task {
            await evictStale()
        }
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    // Check attributes of file and verify cache entry
    public func getHashes(for url: URL, size: Int64, mtime: Double) async -> (pass1: String?, pass2: String?)? {
        // 1. Try NSCache first
        let key = url.path as NSString
        if let entry = memoryCache.object(forKey: key) {
            if entry.size == size && abs(entry.mtime - mtime) < 0.001 {
                // Cache hit, async update last_accessed in DB
                let pass1 = entry.pass1
                let pass2 = entry.pass2
                let pathStr = url.path
                Task {
                    updateLastAccessed(path: pathStr)
                }
                return (pass1, pass2)
            } else {
                memoryCache.removeObject(forKey: key)
            }
        }
        
        // 2. Query SQLite
        let sql = "SELECT pass1_hash, pass2_hash FROM hash_cache WHERE file_path = ? AND file_size = ? AND abs(modification_time - ?) < 0.001;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, (url.path as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 2, size)
        sqlite3_bind_double(stmt, 3, mtime)
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            guard let p1CStr = sqlite3_column_text(stmt, 0) else { return nil }
            let pass1 = String(cString: p1CStr)
            
            var pass2: String? = nil
            if let p2CStr = sqlite3_column_text(stmt, 1) {
                pass2 = String(cString: p2CStr)
            }
            
            // Update memory cache
            let newEntry = CacheEntry(size: size, mtime: mtime, pass1: pass1, pass2: pass2)
            memoryCache.setObject(newEntry, forKey: key)
            
            // Async update last_accessed in DB
            let pathStr = url.path
            Task {
                updateLastAccessed(path: pathStr)
            }
            
            return (pass1, pass2)
        }
        
        return nil
    }
    
    private func updateLastAccessed(path: String) {
        let sql = "UPDATE hash_cache SET last_accessed = ? WHERE file_path = ?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
            sqlite3_bind_text(stmt, 2, (path as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
    }
    
    public func store(url: URL, size: Int64, mtime: Double, pass1: String, pass2: String?) async {
        // Update NSCache
        let key = url.path as NSString
        let entry = CacheEntry(size: size, mtime: mtime, pass1: pass1, pass2: pass2)
        memoryCache.setObject(entry, forKey: key)
        
        // Update SQLite
        let sql = """
        INSERT INTO hash_cache (file_path, file_size, modification_time, pass1_hash, pass2_hash, last_accessed)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(file_path) DO UPDATE SET
            file_size = excluded.file_size,
            modification_time = excluded.modification_time,
            pass1_hash = excluded.pass1_hash,
            pass2_hash = excluded.pass2_hash,
            last_accessed = excluded.last_accessed;
        """
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, (url.path as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 2, size)
        sqlite3_bind_double(stmt, 3, mtime)
        sqlite3_bind_text(stmt, 4, (pass1 as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let p2 = pass2 {
            sqlite3_bind_text(stmt, 5, (p2 as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_double(stmt, 6, Date().timeIntervalSince1970)
        
        sqlite3_step(stmt)
    }
    
    public func evictStale() async {
        let now = Date().timeIntervalSince1970
        let cutoff = now - 2592000 // 30 days
        
        // 1. Evict by age
        let sqlDeleteOld = "DELETE FROM hash_cache WHERE last_accessed < ?;"
        var stmtOld: OpaquePointer?
        if sqlite3_prepare_v2(db, sqlDeleteOld, -1, &stmtOld, nil) == SQLITE_OK {
            sqlite3_bind_double(stmtOld, 1, cutoff)
            sqlite3_step(stmtOld)
        }
        sqlite3_finalize(stmtOld)
        
        // 2. Evict by limit (keep top 500,000)
        let sqlDeleteOverLimit = """
        DELETE FROM hash_cache
        WHERE file_path NOT IN (
            SELECT file_path FROM hash_cache
            ORDER BY last_accessed DESC
            LIMIT 500000
        );
        """
        var stmtLimit: OpaquePointer?
        if sqlite3_prepare_v2(db, sqlDeleteOverLimit, -1, &stmtLimit, nil) == SQLITE_OK {
            sqlite3_step(stmtLimit)
        }
        sqlite3_finalize(stmtLimit)
    }
    
    public func clear() async {
        memoryCache.removeAllObjects()
        
        let sql = "DELETE FROM hash_cache;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }
}
