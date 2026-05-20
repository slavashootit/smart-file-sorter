import XCTest
@testable import SmartFileSorter

final class CleanupTests: XCTestCase {
    
    var tempDirectoryURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Створюємо унікальну тимчасову папку для тестів
        let tempDir = FileManager.default.temporaryDirectory
        tempDirectoryURL = tempDir.appendingPathComponent("SmartFileSorterCleanupTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        try super.tearDownWithError()
    }
    
    // 1. Тест XXHash64
    func testXXHash64Correctness() throws {
        let text = "Hello World! This is a test of the XXHash64 algorithm in Swift."
        let data = text.data(using: .utf8)!
        
        let hash = XXHash64.hash(data)
        XCTAssertNotEqual(hash, 0)
        
        // Перевіримо потокове хешування
        let fileURL = tempDirectoryURL.appendingPathComponent("test_hash.txt")
        try data.write(to: fileURL)
        
        let streamHash = try XXHash64.hashOfFile(at: fileURL)
        XCTAssertEqual(hash, streamHash, "Потоковий хеш має збігатися з хешем у пам'яті")
    }
    
    // 2. Тест DuplicateFinder
    func testDuplicateFinderDetectsDuplicates() throws {
        let content1 = "Exact duplicate content".data(using: .utf8)!
        let content2 = "Different content".data(using: .utf8)!
        
        // Створюємо файли-дублікати
        let fileA = tempDirectoryURL.appendingPathComponent("fileA.txt")
        let fileB = tempDirectoryURL.appendingPathComponent("fileB.txt")
        let fileC = tempDirectoryURL.appendingPathComponent("fileC.txt")
        
        try content1.write(to: fileA)
        try content1.write(to: fileB) // Дублікат A
        try content2.write(to: fileC) // Унікальний
        
        let finder = DuplicateFinder()
        let expectation = XCTestExpectation(description: "Scan duplicates completion")
        
        finder.scan(at: tempDirectoryURL.path) {
            XCTAssertEqual(finder.duplicateGroups.count, 1)
            if let group = finder.duplicateGroups.first {
                XCTAssertEqual(group.files.count, 2)
                XCTAssertTrue(group.files.contains(fileA))
                XCTAssertTrue(group.files.contains(fileB))
                XCTAssertFalse(group.files.contains(fileC))
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // 3. Тест CleanupManager: Пошук великих файлів
    func testCleanupManagerLargeFiles() throws {
        // Створюємо файл на 2 МБ
        let data2MB = Data(count: 2 * 1024 * 1024)
        let largeFile = tempDirectoryURL.appendingPathComponent("large.bin")
        try data2MB.write(to: largeFile)
        
        // Створюємо файл на 500 КБ (малий)
        let data500KB = Data(count: 500 * 1024)
        let smallFile = tempDirectoryURL.appendingPathComponent("small.bin")
        try data500KB.write(to: smallFile)
        
        let manager = CleanupManager()
        let expectation = XCTestExpectation(description: "Scan large files completion")
        
        // Шукаємо файли розміром більше 1 МБ
        manager.scanLargeFiles(at: tempDirectoryURL.path, minSizeMB: 1) {
            XCTAssertEqual(manager.largeFiles.count, 1)
            XCTAssertEqual(manager.largeFiles.first?.url, largeFile)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // 4. Тест CleanupManager: Пошук порожніх папок
    func testCleanupManagerEmptyFolders() throws {
        // Створюємо порожню папку
        let emptyFolder = tempDirectoryURL.appendingPathComponent("EmptyFolder")
        try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true, attributes: nil)
        
        // Створюємо не порожню папку
        let nonEmptyFolder = tempDirectoryURL.appendingPathComponent("NonEmptyFolder")
        try FileManager.default.createDirectory(at: nonEmptyFolder, withIntermediateDirectories: true, attributes: nil)
        let someFile = nonEmptyFolder.appendingPathComponent("file.txt")
        try "content".write(to: someFile, atomically: true, encoding: .utf8)
        
        // Створюємо папку, що містить тільки порожню папку (має вважатися порожньою)
        let nestedEmptyFolderParent = tempDirectoryURL.appendingPathComponent("NestedEmptyParent")
        let nestedEmptyChild = nestedEmptyFolderParent.appendingPathComponent("NestedChild")
        try FileManager.default.createDirectory(at: nestedEmptyChild, withIntermediateDirectories: true, attributes: nil)
        
        let manager = CleanupManager()
        let expectation = XCTestExpectation(description: "Scan empty folders completion")
        
        manager.scanEmptyFolders(at: tempDirectoryURL.path) {
            let paths = manager.emptyFolders.map { $0.url.path }
            XCTAssertTrue(paths.contains(emptyFolder.path))
            XCTAssertTrue(paths.contains(nestedEmptyFolderParent.path))
            XCTAssertFalse(paths.contains(nonEmptyFolder.path))
            XCTAssertFalse(paths.contains(someFile.path))
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
