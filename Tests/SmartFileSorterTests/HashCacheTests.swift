import XCTest
import SQLite3
@testable import SmartFileSorter

final class HashCacheTests: XCTestCase {
    
    private var tempDirectoryURL: URL!
    private var cacheDBURL: URL!
    private var cache: HashCache!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory
        tempDirectoryURL = tempDir.appendingPathComponent("SmartFileSorterHashCacheTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        cacheDBURL = tempDirectoryURL.appendingPathComponent("test_hash_cache.db")
        cache = HashCache(databaseURL: cacheDBURL)
    }
    
    override func tearDownWithError() throws {
        cache = nil
        if FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        try super.tearDownWithError()
    }
    
    func testBasicCacheStoreAndRetrieve() async throws {
        let fileURL = tempDirectoryURL.appendingPathComponent("file1.txt")
        let content = "Hello HashCache!".data(using: .utf8)!
        try content.write(to: fileURL)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size = attributes[.size] as! Int64
        let mtime = (attributes[.modificationDate] as! Date).timeIntervalSince1970
        
        // Initially empty
        let initial = await cache.getHashes(for: fileURL, size: size, mtime: mtime)
        XCTAssertNil(initial)
        
        // Store hashes
        let pass1 = "p1-hash"
        let pass2 = "p2-hash"
        await cache.store(url: fileURL, size: size, mtime: mtime, pass1: pass1, pass2: pass2)
        
        // Retrieve and match
        let retrieved = await cache.getHashes(for: fileURL, size: size, mtime: mtime)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.pass1, pass1)
        XCTAssertEqual(retrieved?.pass2, pass2)
    }
    
    func testCacheInvalidationOnSizeChange() async throws {
        let fileURL = tempDirectoryURL.appendingPathComponent("file_size_change.txt")
        let content = "Initial content".data(using: .utf8)!
        try content.write(to: fileURL)
        
        var attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size1 = attributes[.size] as! Int64
        let mtime = (attributes[.modificationDate] as! Date).timeIntervalSince1970
        
        // Store
        await cache.store(url: fileURL, size: size1, mtime: mtime, pass1: "h1", pass2: "h2")
        
        // Modify size by writing more content
        let content2 = "Initial content extra bytes".data(using: .utf8)!
        try content2.write(to: fileURL)
        
        attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size2 = attributes[.size] as! Int64
        let mtime2 = (attributes[.modificationDate] as! Date).timeIntervalSince1970
        XCTAssertNotEqual(size1, size2)
        
        // Retrieve should be nil because size doesn't match
        let retrieved = await cache.getHashes(for: fileURL, size: size2, mtime: mtime2)
        XCTAssertNil(retrieved)
    }
    
    func testCacheInvalidationOnModificationTimeChange() async throws {
        let fileURL = tempDirectoryURL.appendingPathComponent("file_mtime_change.txt")
        let content = "Content".data(using: .utf8)!
        try content.write(to: fileURL)
        
        var attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size = attributes[.size] as! Int64
        let mtime1 = (attributes[.modificationDate] as! Date).timeIntervalSince1970
        
        // Store
        await cache.store(url: fileURL, size: size, mtime: mtime1, pass1: "h1", pass2: "h2")
        
        // Modify modification time (touch)
        let newDate = Date().addingTimeInterval(10)
        try FileManager.default.setAttributes([.modificationDate: newDate], ofItemAtPath: fileURL.path)
        
        attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let mtime2 = (attributes[.modificationDate] as! Date).timeIntervalSince1970
        XCTAssertNotEqual(mtime1, mtime2)
        
        // Retrieve should be nil because mtime doesn't match
        let retrieved = await cache.getHashes(for: fileURL, size: size, mtime: mtime2)
        XCTAssertNil(retrieved)
    }
    
    func testEvictionLogic() async throws {
        let fileURL = tempDirectoryURL.appendingPathComponent("file_eviction.txt")
        try "evict".write(to: fileURL, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size = attributes[.size] as! Int64
        let mtime = (attributes[.modificationDate] as! Date).timeIntervalSince1970
        
        // Store normally
        await cache.store(url: fileURL, size: size, mtime: mtime, pass1: "p1", pass2: "p2")
        
        // Dump NSCache by releasing the instance
        cache = nil
        
        // Now, manually open the DB and update last_accessed to be 31 days old
        var db: OpaquePointer?
        if sqlite3_open(cacheDBURL.path, &db) == SQLITE_OK {
            let sql = "UPDATE hash_cache SET last_accessed = ? WHERE file_path = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                let thirtyOneDaysAgo = Date().timeIntervalSince1970 - (31 * 24 * 3600)
                sqlite3_bind_double(stmt, 1, thirtyOneDaysAgo)
                sqlite3_bind_text(stmt, 2, (fileURL.path as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            sqlite3_close(db)
        }
        
        // Recreate cache (SQLite DB is kept, NSCache is empty)
        cache = HashCache(databaseURL: cacheDBURL)
        
        // Run eviction
        await cache.evictStale()
        
        // Cache should be empty now
        let retrieved = await cache.getHashes(for: fileURL, size: size, mtime: mtime)
        XCTAssertNil(retrieved)
    }
    
    func testConcurrentReadsAndWrites() async throws {
        let iterations = 100
        let urls = (0..<iterations).map {
            tempDirectoryURL.appendingPathComponent("concurrent_file_\($0).txt")
        }
        
        for url in urls {
            try "data".write(to: url, atomically: true, encoding: .utf8)
        }
        
        let fixedMtime = 123456789.0
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                let url = urls[i]
                
                // Write task
                group.addTask {
                    await self.cache.store(url: url, size: 4, mtime: fixedMtime, pass1: "p1-\(i)", pass2: "p2-\(i)")
                }
                
                // Read task
                group.addTask {
                    _ = await self.cache.getHashes(for: url, size: 4, mtime: fixedMtime)
                }
            }
        }
        
        // Check that at least the last item was saved and is readable
        let finalRetrieved = await cache.getHashes(for: urls[iterations - 1], size: 4, mtime: fixedMtime)
        XCTAssertNotNil(finalRetrieved)
    }
}
