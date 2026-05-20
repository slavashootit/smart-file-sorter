import Foundation
import SQLite3

public class OCRDatabase {
    public static let shared = OCRDatabase()
    private var db: OpaquePointer?
    
    private init() {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let appDirURL = appSupportURL.appendingPathComponent("com.slavashootit.smart-file-sorter")
        if !fileManager.fileExists(atPath: appDirURL.path) {
            try? fileManager.createDirectory(at: appDirURL, withIntermediateDirectories: true)
        }
        let dbURL = appDirURL.appendingPathComponent("ocr_cache.sqlite")
        
        if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
            createTable()
        } else {
            print("[OCR DB] Failed to open database")
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func createTable() {
        let query = """
        CREATE TABLE IF NOT EXISTS ocr_cache (
            id TEXT PRIMARY KEY,
            path TEXT UNIQUE,
            text TEXT,
            timestamp REAL
        );
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("[OCR DB] Failed to create table")
            }
        }
        sqlite3_finalize(statement)
    }
    
    public func getCachedText(for fileURL: URL) -> String? {
        let key = fileURL.path
        let query = "SELECT text FROM ocr_cache WHERE path = ?;"
        var statement: OpaquePointer?
        var text: String? = nil
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    text = String(cString: cString)
                }
            }
        }
        sqlite3_finalize(statement)
        return text
    }
    
    public func cacheText(_ text: String, for fileURL: URL) {
        let key = fileURL.path
        let query = "INSERT OR REPLACE INTO ocr_cache (path, text, timestamp) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (text as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("[OCR DB] Failed to cache text")
            }
        }
        sqlite3_finalize(statement)
    }
}
