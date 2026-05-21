import XCTest
import CoreServices
@testable import SmartFileSorter

final class SorterEngineTests: XCTestCase {
    
    private var tempDirectoryURL: URL!
    private var sandboxURL: URL!
    private var engine: SorterEngine!
    private var fileManager: FileManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        tempDirectoryURL = tempDir.appendingPathComponent("SmartFileSorterEngineTests_\(UUID().uuidString)")
        sandboxURL = tempDirectoryURL.appendingPathComponent("test_sandbox")
        try fileManager.createDirectory(at: sandboxURL, withIntermediateDirectories: true)
        engine = SorterEngine.shared
        
        // Clear previous history
        HistoryManager.shared.clearAllHistory()
    }
    
    override func tearDownWithError() throws {
        if fileManager.fileExists(atPath: tempDirectoryURL.path) {
            try? fileManager.removeItem(at: tempDirectoryURL)
        }
        engine = nil
        fileManager = nil
        try super.tearDownWithError()
    }
    
    private func createDefaultSandboxFiles() {
        // 1. Створюємо унікальні файли в корені
        try! "unique video content 1".write(to: sandboxURL.appendingPathComponent("video1.mp4"), atomically: true, encoding: .utf8)
        try! "unique audio content".write(to: sandboxURL.appendingPathComponent("song.mp3"), atomically: true, encoding: .utf8)
        try! "unique document content".write(to: sandboxURL.appendingPathComponent("doc1.pdf"), atomically: true, encoding: .utf8)
        
        // 2. Створюємо дублікати в корені
        try! "duplicate image content".write(to: sandboxURL.appendingPathComponent("image.png"), atomically: true, encoding: .utf8)
        try! "duplicate image content".write(to: sandboxURL.appendingPathComponent("image_copy.png"), atomically: true, encoding: .utf8)
        try! "duplicate image content".write(to: sandboxURL.appendingPathComponent("image_another_copy.png"), atomically: true, encoding: .utf8)
        
        // 3. Створюємо чисту підпапку з відео
        let pureVideosURL = sandboxURL.appendingPathComponent("pure_videos")
        try! fileManager.createDirectory(at: pureVideosURL, withIntermediateDirectories: true, attributes: nil)
        try! "clip 1 video".write(to: pureVideosURL.appendingPathComponent("clip1.mp4"), atomically: true, encoding: .utf8)
        try! "clip 2 video".write(to: pureVideosURL.appendingPathComponent("clip2.mov"), atomically: true, encoding: .utf8)
        
        // 4. Створюємо чисту підпапку з картинками
        let purePicsURL = sandboxURL.appendingPathComponent("pure_pics")
        try! fileManager.createDirectory(at: purePicsURL, withIntermediateDirectories: true, attributes: nil)
        try! "photo 1".write(to: purePicsURL.appendingPathComponent("photo1.jpg"), atomically: true, encoding: .utf8)
        try! "photo 2".write(to: purePicsURL.appendingPathComponent("photo2.png"), atomically: true, encoding: .utf8)
        
        // 5. Створюємо змішану підпапку
        let mixedURL = sandboxURL.appendingPathComponent("mixed_stuff")
        try! fileManager.createDirectory(at: mixedURL, withIntermediateDirectories: true, attributes: nil)
        try! "pic in mixed".write(to: mixedURL.appendingPathComponent("pic.jpg"), atomically: true, encoding: .utf8)
        try! "contract in mixed".write(to: mixedURL.appendingPathComponent("contract.pdf"), atomically: true, encoding: .utf8)
        
        // 6. Створюємо порожню підпапку
        let emptyURL = sandboxURL.appendingPathComponent("empty_folder")
        try! fileManager.createDirectory(at: emptyURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    private func runSorterEngine(
        folderPath: String,
        sortMode: SortMode,
        categories: [String: Bool],
        dryRun: Bool,
        detectDuplicates: Bool
    ) async -> [String] {
        let stream = engine.sortFiles(
            folderPath: folderPath,
            sortMode: sortMode,
            categories: categories,
            dryRun: dryRun,
            detectDuplicates: detectDuplicates
        )
        var finalLogs: [String] = []
        for await progress in stream {
            if progress.isFinished {
                finalLogs = progress.finalLogs ?? []
            }
        }
        return finalLogs
    }
    
    // 1. Тестування Dry Run
    func testSorterEngineDryRun() async throws {
        createDefaultSandboxFiles()
        
        let categories = [
            "Зображення": true,
            "Відео": true,
            "Документи": true,
            "Аудіо": true,
            "Архіви": true,
            "Інші файли": true
        ]
        
        _ = await runSorterEngine(
            folderPath: sandboxURL.path,
            sortMode: .type,
            categories: categories,
            dryRun: true,
            detectDuplicates: true
        )
        
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("video1.mp4").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image_copy.png").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("pure_videos").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("pure_pics").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("mixed_stuff").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("empty_folder").path))
        XCTAssertFalse(engine.checkHistoryExists(), "Dry run не повинен створювати файл історії")
    }
    
    // 2. Тестування реального сортування
    func testSorterEngineRealSorting() async throws {
        createDefaultSandboxFiles()
        
        let categories = [
            "Зображення": true,
            "Відео": true,
            "Документи": true,
            "Аудіо": true,
            "Архіви": true,
            "Інші файли": true
        ]
        
        let logsReal = await runSorterEngine(
            folderPath: sandboxURL.path,
            sortMode: .type,
            categories: categories,
            dryRun: false,
            detectDuplicates: true
        )
        print("--- testSorterEngineRealSorting LOGS ---")
        for log in logsReal {
            print(log)
        }
        print("-----------------------------------------")
        XCTAssertFalse(logsReal.isEmpty)
        
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Відео/video1.mp4").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Аудіо/song.mp3").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Документи/doc1.pdf").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Зображення/image_another_copy.png").path))
        XCTAssertFalse(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image.png").path))
        XCTAssertFalse(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image_copy.png").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Відео/pure_videos/clip1.mp4").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Зображення/pure_pics/photo1.jpg").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("mixed_stuff/pic.jpg").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("empty_folder").path))
        XCTAssertTrue(engine.checkHistoryExists(), "Має створитися файл історії")
    }
    
    // 3. Тестування скасування сортування (Undo)
    func testSorterEngineUndo() async throws {
        createDefaultSandboxFiles()
        
        let categories = [
            "Зображення": true,
            "Відео": true,
            "Документи": true,
            "Аудіо": true,
            "Архіви": true,
            "Інші файли": true
        ]
        
        _ = await runSorterEngine(
            folderPath: sandboxURL.path,
            sortMode: .type,
            categories: categories,
            dryRun: false,
            detectDuplicates: true
        )
        
        XCTAssertTrue(engine.checkHistoryExists())
        
        let undoLogs = engine.undoSorting()
        print("--- testSorterEngineUndo LOGS ---")
        for log in undoLogs {
            print(log)
        }
        print("---------------------------------")
        XCTAssertFalse(undoLogs.isEmpty)
        
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("video1.mp4").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("song.mp3").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("doc1.pdf").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image.png").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image_copy.png").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image_another_copy.png").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("pure_videos/clip1.mp4").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("pure_pics/photo1.jpg").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("mixed_stuff/pic.jpg").path))
        XCTAssertTrue(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("empty_folder").path))
        
        XCTAssertFalse(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Відео").path))
        XCTAssertFalse(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Зображення").path))
        XCTAssertFalse(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Аудіо").path))
        XCTAssertFalse(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Документи").path))
        XCTAssertFalse(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Дублікати").path))
        XCTAssertFalse(engine.checkHistoryExists(), "Файл історії має бути порожнім/відсутнім після Undo")
    }
    
    // 4. Тестування SecurityBookmarks
    func testSecurityBookmarks() throws {
        let bookmarkMgr = SecurityBookmarks.shared
        let testBookmarkFolder = sandboxURL.appendingPathComponent("bookmark_test_dir")
        try fileManager.createDirectory(at: testBookmarkFolder, withIntermediateDirectories: true, attributes: nil)
        
        let bookmarkSaved = bookmarkMgr.saveBookmark(for: testBookmarkFolder)
        XCTAssertTrue(bookmarkSaved, "Має успішно зберегти закладку безпеки")
        
        let restoredBookmarks = bookmarkMgr.restoreAllBookmarks()
        XCTAssertTrue(restoredBookmarks.map { $0.path }.contains(testBookmarkFolder.path), "restoredBookmarks має містити тестову папку")
        
        bookmarkMgr.startAccessing(testBookmarkFolder)
        bookmarkMgr.stopAccessing(testBookmarkFolder)
        bookmarkMgr.removeBookmark(for: testBookmarkFolder)
        
        let restoredAfterRemove = bookmarkMgr.restoreAllBookmarks()
        XCTAssertFalse(restoredAfterRemove.map { $0.path }.contains(testBookmarkFolder.path), "Після видалення закладка не повинна відновлюватись")
    }
    
    // 5. Тестування FSEventsWatcher
    func testFSEventsWatcher() throws {
        let watcher = FSEventsWatcher.shared
        let watchDir = sandboxURL.appendingPathComponent("watch_test_dir")
        try fileManager.createDirectory(at: watchDir, withIntermediateDirectories: true, attributes: nil)
        
        let watchAdded = watcher.watchFolder(path: watchDir.path)
        XCTAssertTrue(watchAdded, "Має успішно додати папку до відстеження")
        XCTAssertTrue(watcher.getWatchedPaths().contains(watchDir.path), "getWatchedPaths має містити додану папку")
        XCTAssertTrue(watcher.isWatching(), "Стрім моніторингу має бути запущений")
        
        // Створюємо синхронізацію для очікування події FSEvents
        let expectation = XCTestExpectation(description: "FSEvents event expectation")
        var receivedPaths: [String] = []
        
        watcher.onEvents = { paths in
            receivedPaths.append(contentsOf: paths)
            expectation.fulfill()
        }
        
        // Створюємо новий файл у відстежуваній папці
        let triggerFile = watchDir.appendingPathComponent("new_file.txt")
        try! "hello event watcher".write(to: triggerFile, atomically: true, encoding: .utf8)
        
        // Очікуємо події протягом 3 секунд (латенція стріму 1.0 сек)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(result, .completed, "FSEventsWatcher не зафіксував додавання файлу")
        XCTAssertTrue(receivedPaths.contains(triggerFile.path), "Отримані події мають містити шлях створеного файлу")
        
        // Тестування призупинення
        watcher.pauseAll()
        XCTAssertFalse(watcher.isWatching(), "Після pauseAll моніторинг має призупинитись")
        
        watcher.resumeAll()
        XCTAssertTrue(watcher.isWatching(), "Після resumeAll моніторинг має запуститись знову")
        
        watcher.shutdown()
        XCTAssertTrue(watcher.getWatchedPaths().isEmpty, "Після shutdown список відстежуваних папок має бути порожнім")
    }
    
    // 6. Тестування RuleEngine
    func testRuleEngineBasicConditions() throws {
        let ruleEngine = RuleEngine.shared
        
        // Створюємо тестовий файл
        let ruleTestDir = sandboxURL.appendingPathComponent("rules_test_dir")
        try fileManager.createDirectory(at: ruleTestDir, withIntermediateDirectories: true, attributes: nil)
        
        let testFile = ruleTestDir.appendingPathComponent("Report_2026.pdf")
        try "pdf file content data".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Тестуємо окремі умови
        let condName = RuleCondition(type: .nameMatches, value: "report")
        let condExt = RuleCondition(type: .extensionIs, value: "pdf")
        let condKind = RuleCondition(type: .kindIs, value: "doc")
        let condSize = RuleCondition(type: .sizeGreaterThan, value: "5")
        
        XCTAssertTrue(ruleEngine.evaluate(condition: condName, for: testFile), "Умова nameMatches має повернути true")
        XCTAssertTrue(ruleEngine.evaluate(condition: condExt, for: testFile), "Умова extensionIs має повернути true")
        XCTAssertTrue(ruleEngine.evaluate(condition: condKind, for: testFile), "Умова kindIs (doc) має повернути true")
        XCTAssertTrue(ruleEngine.evaluate(condition: condSize, for: testFile), "Умова sizeGreaterThan має повернути true")
        
        // Тестуємо невідповідні умови
        let condBadName = RuleCondition(type: .nameMatches, value: "photo")
        let condBadExt = RuleCondition(type: .extensionIs, value: "png")
        let condBadSize = RuleCondition(type: .sizeLessThan, value: "5")
        
        XCTAssertFalse(ruleEngine.evaluate(condition: condBadName, for: testFile), "Невірна умова nameMatches має повернути false")
        XCTAssertFalse(ruleEngine.evaluate(condition: condBadExt, for: testFile), "Невірна умова extensionIs має повернути false")
        XCTAssertFalse(ruleEngine.evaluate(condition: condBadSize, for: testFile), "Невірна умова sizeLessThan має повернути false")
    }
    
    // 7. Тестування RuleEngine Execution and Serialization
    func testRuleEngineExecutionAndSerialization() throws {
        let ruleEngine = RuleEngine.shared
        
        // Очищаємо перед тестом
        if fileManager.fileExists(atPath: ruleEngine.rulesFileURL.path) {
            try? fileManager.removeItem(at: ruleEngine.rulesFileURL)
        }
        
        let ruleTestDir = sandboxURL.appendingPathComponent("rules_test_dir")
        let ruleDestDir = sandboxURL.appendingPathComponent("rules_dest_dir")
        try fileManager.createDirectory(at: ruleTestDir, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: ruleDestDir, withIntermediateDirectories: true, attributes: nil)
        
        let testFile = ruleTestDir.appendingPathComponent("Report_2026.pdf")
        try "pdf file content data".write(to: testFile, atomically: true, encoding: .utf8)
        
        let condName = RuleCondition(type: .nameMatches, value: "report")
        let condExt = RuleCondition(type: .extensionIs, value: "pdf")
        let condKind = RuleCondition(type: .kindIs, value: "doc")
        
        let rule = Rule(
            name: "Сортувати звіти PDF",
            enabled: true,
            conditions: [condName, condExt, condKind],
            actions: [
                RuleAction(type: .rename, value: "Sorted_%filename%_%YYYY%_%MM%.%ext%"),
                RuleAction(type: .moveTo, value: ruleDestDir.path)
            ]
        )
        
        XCTAssertTrue(ruleEngine.match(rule: rule, for: testFile), "Правило має відповідати файлу")
        
        // Виконуємо правило
        let execResult = ruleEngine.execute(rule: rule, for: testFile)
        XCTAssertTrue(execResult.success, "Виконання дій правила має бути успішним")
        
        let calendar = Calendar.current
        let year = String(format: "%04d", calendar.component(.year, from: Date()))
        let month = String(format: "%02d", calendar.component(.month, from: Date()))
        let expectedNewName = "Sorted_Report_2026_\(year)_\(month).pdf"
        let expectedFinalURL = ruleDestDir.appendingPathComponent(expectedNewName)
        
        XCTAssertTrue(fileManager.fileExists(atPath: expectedFinalURL.path), "Файл має бути перейменований та переміщений")
        XCTAssertEqual(execResult.finalURL.path, expectedFinalURL.path, "Кінцевий URL має відповідати очікуваному шляху")
        
        // Тестування збереження та завантаження правил у JSON
        ruleEngine.rules = [rule]
        ruleEngine.saveRules()
        
        ruleEngine.rules = []
        ruleEngine.loadRules()
        
        XCTAssertEqual(ruleEngine.rules.count, 1, "Має завантажитись 1 збережене правило")
        XCTAssertEqual(ruleEngine.rules.first?.name, "Сортувати звіти PDF", "Ім'я завантаженого правила має співпадати")
        XCTAssertEqual(ruleEngine.rules.first?.actions.count, 2, "Кількість дій має бути 2")
        
        // Очищення rules.json
        if fileManager.fileExists(atPath: ruleEngine.rulesFileURL.path) {
            try? fileManager.removeItem(at: ruleEngine.rulesFileURL)
        }
    }
    
    // 8. Тестування HistoryManager (Trash and Undo)
    func testHistoryManagerTrashAndUndo() throws {
        let historyMgr = HistoryManager.shared
        
        // Створюємо тестовий файл для переміщення в Смітник
        let trashSourceDir = sandboxURL.appendingPathComponent("trash_source_dir")
        try fileManager.createDirectory(at: trashSourceDir, withIntermediateDirectories: true, attributes: nil)
        let fileToTrash = trashSourceDir.appendingPathComponent("duplicate_to_remove.txt")
        try "duplicate text".write(to: fileToTrash, atomically: true, encoding: .utf8)
        
        // Видаляємо в Смітник
        let resultURL = historyMgr.trashItem(at: fileToTrash)
        XCTAssertNotNil(resultURL, "Має успішно перенести файл до Смітника")
        XCTAssertFalse(fileManager.fileExists(atPath: fileToTrash.path), "Файлу більше не повинно існувати за оригінальним шляхом")
        XCTAssertTrue(fileManager.fileExists(atPath: resultURL!.path), "Файл має існувати в Смітнику")
        
        // Створюємо партію історії, де новим шляхом є шлях у Смітнику
        let batchOp = BatchOperation(originalPath: fileToTrash.path, newPath: resultURL!.path, isTrashed: true)
        let batch = BatchRecord(
            id: UUID(),
            timestamp: Date(),
            operations: [batchOp],
            createdDirs: [],
            profileName: "TestProfile"
        )
        
        historyMgr.addBatch(batch)
        XCTAssertTrue(historyMgr.checkHistoryExists(), "Історія має містити додану партію")
        
        // Виконуємо скасування (Undo)
        let undoLogs = historyMgr.undoLastBatch()
        XCTAssertFalse(undoLogs.isEmpty)
        XCTAssertTrue(fileManager.fileExists(atPath: fileToTrash.path), "Скасування має повернути файл зі Смітника")
        XCTAssertFalse(fileManager.fileExists(atPath: resultURL!.path), "Файл має бути видалений зі Смітника")
    }
    
    // 9. Тестування RuleEngine v2 Features
    func testRuleEngineV2Features() throws {
        let ruleEngine = RuleEngine.shared
        
        let ruleTestDir = sandboxURL.appendingPathComponent("rules_test_dir")
        try fileManager.createDirectory(at: ruleTestDir, withIntermediateDirectories: true, attributes: nil)
        
        let testFileV2 = ruleTestDir.appendingPathComponent("photo_123.jpg")
        try "jpeg content data".write(to: testFileV2, atomically: true, encoding: .utf8)
        
        // 8.1. Тестуємо рекурсивні (nested) умови OR
        let condJpg = RuleCondition(type: .extensionIs, value: "jpg")
        let condPng = RuleCondition(type: .extensionIs, value: "png")
        let groupOr = RuleCondition(logicalOperator: .or, subconditions: [condJpg, condPng])
        
        XCTAssertTrue(ruleEngine.evaluate(condition: groupOr, for: testFileV2), "Nested OR group (jpg OR png) має повернути true")
        
        // 8.2. Тестуємо Regex-умови
        let condRegexValid = RuleCondition(type: .filenameMatchesRegex, value: "^photo_\\d{3}\\.jpg$")
        let condRegexInvalid = RuleCondition(type: .filenameMatchesRegex, value: "[invalid regex")
        
        XCTAssertTrue(ruleEngine.evaluate(condition: condRegexValid, for: testFileV2), "Regex '^photo_\\d{3}\\.jpg$' має повернути true")
        XCTAssertFalse(ruleEngine.evaluate(condition: condRegexInvalid, for: testFileV2), "Невалідний Regex має повернути false і не впасти")
        
        // 8.3. Тестуємо додавання тегів Finder та умов hasTag / doesNotHaveTag
        let ruleTags = Rule(
            name: "Додати тег Red",
            enabled: true,
            conditions: [condJpg],
            actions: [RuleAction(type: .addTag, value: "Red")]
        )
        let execTagsResult = ruleEngine.execute(rule: ruleTags, for: testFileV2)
        XCTAssertTrue(execTagsResult.success, "Додавання тегу має пройти успішно")
        
        let condHasTag = RuleCondition(type: .hasTag, value: "Red")
        let condNoTag = RuleCondition(type: .doesNotHaveTag, value: "Green")
        XCTAssertTrue(ruleEngine.evaluate(condition: condHasTag, for: testFileV2), "hasTag (Red) має повернути true")
        XCTAssertTrue(ruleEngine.evaluate(condition: condNoTag, for: testFileV2), "doesNotHaveTag (Green) має повернути true")
        
        // 8.4. Тестуємо архівацію в ZIP
        let ruleZip = Rule(
            name: "Архівувати в ZIP",
            enabled: true,
            conditions: [condJpg],
            actions: [RuleAction(type: .archiveToZIP, value: "")]
        )
        let execZipResult = ruleEngine.execute(rule: ruleZip, for: testFileV2)
        XCTAssertTrue(execZipResult.success, "Архівація повинна пройти успішно")
        XCTAssertEqual(execZipResult.finalURL.pathExtension, "zip", "Кінцевий файл повинен мати розширення zip")
        XCTAssertTrue(fileManager.fileExists(atPath: execZipResult.finalURL.path), "ZIP файл повинен існувати")
        XCTAssertFalse(fileManager.fileExists(atPath: testFileV2.path), "Оригінальний файл повинен бути видалений після архівації")
        
        // Очищаємо ZIP
        try? fileManager.removeItem(at: execZipResult.finalURL)
        
        // 8.5. Тестуємо детектор конфліктів
        let ruleConflict1 = Rule(
            name: "Конфлікт 1",
            enabled: true,
            conditions: [condPng],
            actions: [RuleAction(type: .moveTo, value: "/tmp/path1")]
        )
        let ruleConflict2 = Rule(
            name: "Конфлікт 2",
            enabled: true,
            conditions: [condPng],
            actions: [RuleAction(type: .moveTo, value: "/tmp/path2")]
        )
        
        ruleEngine.rules = [ruleConflict1, ruleConflict2]
        let conflicts = ruleEngine.detectConflicts()
        XCTAssertEqual(conflicts.count, 1, "Детектор має знайти один конфлікт")
        XCTAssertTrue(conflicts.first?.contains("мають однакові умови, але переміщують файли в різні папки") ?? false)
    }
}
