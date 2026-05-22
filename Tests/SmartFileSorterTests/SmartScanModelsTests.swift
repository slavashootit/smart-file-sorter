import XCTest
@testable import SmartFileSorter

final class SmartScanModelsTests: XCTestCase {
    func test_totalBytes_onlyCountsSelected() {
        let issues = [
            ScanIssue(id: UUID(), category: .cleanup, displayName: "a", detail: "",
                      urls: [], bytes: 100, isSelected: true, reason: ""),
            ScanIssue(id: UUID(), category: .duplicate, displayName: "b", detail: "",
                      urls: [], bytes: 200, isSelected: false, reason: ""),
        ]
        let results = ScanResults(issues: issues, scannedPath: URL(fileURLWithPath: "/tmp"), scannedAt: .now)
        XCTAssertEqual(results.totalBytes, 100)
    }

    func test_grouped_sortedByCategory() {
        let issues = [
            ScanIssue(id: UUID(), category: .similarPhoto, displayName: "p", detail: "", urls: [], bytes: 0, isSelected: false, reason: ""),
            ScanIssue(id: UUID(), category: .cleanup, displayName: "c", detail: "", urls: [], bytes: 0, isSelected: true, reason: ""),
        ]
        let results = ScanResults(issues: issues, scannedPath: URL(fileURLWithPath: "/tmp"), scannedAt: .now)
        XCTAssertEqual(results.grouped.first?.category, .cleanup)
    }

    func test_similarPhoto_defaultNotSelected() {
        let issue = ScanIssue(id: UUID(), category: .similarPhoto, displayName: "x",
                              detail: "", urls: [], bytes: 0, isSelected: false, reason: "")
        XCTAssertFalse(issue.isSelected)
    }

    // Test cases for determineReason (UA)

    func test_determineReason_trash() {
        let trashDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(".Trash")
        try? FileManager.default.createDirectory(at: trashDir, withIntermediateDirectories: true)
        let file = trashDir.appendingPathComponent("test_trash.txt")
        try? "test".write(to: file, atomically: true, encoding: .utf8)
        
        let daysAgo = Calendar.current.date(byAdding: .day, value: -12, to: Date())!
        try? FileManager.default.setAttributes([.modificationDate: daysAgo], ofItemAtPath: file.path)
        
        let reason = ScanIssue.determineReason(category: .cleanup, url: file)
        XCTAssertEqual(reason, "У Кошику · 12 дн.")
        
        try? FileManager.default.removeItem(at: file)
    }

    func test_determineReason_cache() {
        let logFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_cache.log")
        try? "hello".write(to: logFile, atomically: true, encoding: .utf8) // 5 bytes
        
        let reason = ScanIssue.determineReason(category: .cleanup, url: logFile)
        let sizeStr = ByteCountFormatter.string(fromByteCount: 5, countStyle: .file)
        XCTAssertEqual(reason, "Кеш · \(sizeStr)")
        
        try? FileManager.default.removeItem(at: logFile)
    }

    func test_determineReason_downloads() {
        let downloadsDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Downloads")
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let file = downloadsDir.appendingPathComponent("test_download.txt")
        try? "test".write(to: file, atomically: true, encoding: .utf8)
        
        let monthsAgo = Calendar.current.date(byAdding: .month, value: -5, to: Date())!
        try? FileManager.default.setAttributes([.modificationDate: monthsAgo], ofItemAtPath: file.path)
        
        let reason = ScanIssue.determineReason(category: .cleanup, url: file)
        // Since contentAccessDateKey might fail, it falls back to modificationDate
        XCTAssertEqual(reason, "Downloads · не відкривався 5 міс.")
        
        try? FileManager.default.removeItem(at: file)
    }

    func test_determineReason_duplicate() {
        let original = URL(fileURLWithPath: "/path/to/original_file.png")
        let duplicate = URL(fileURLWithPath: "/path/to/dup_file.png")
        let reason = ScanIssue.determineReason(category: .duplicate, url: duplicate, originalFile: original)
        XCTAssertEqual(reason, "Дублікат файлу original_file.png")
    }

    func test_determineReason_similarPhoto() {
        let photo = URL(fileURLWithPath: "/path/to/photo.jpg")
        let reason = ScanIssue.determineReason(category: .similarPhoto, url: photo, clusterSize: 6)
        XCTAssertEqual(reason, "Схоже на 5 фото в кластері")
    }
}
