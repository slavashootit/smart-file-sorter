import Foundation

@main
struct SorterEngineTests {
    static func main() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let sandboxURL = home.appendingPathComponent(".gemini/antigravity/scratch/file_sorter/test_sandbox")
        
        // Setup sandbox
        if fileManager.fileExists(atPath: sandboxURL.path) {
            try? fileManager.removeItem(at: sandboxURL)
        }
        try! fileManager.createDirectory(at: sandboxURL, withIntermediateDirectories: true, attributes: nil)
        
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
        
        print("--- ЗАПУСК ТЕСТУВАННЯ СОРТУВАННЯ ТА СКАСУВАННЯ (SWIFT NATIVE) ---")
        
        let engine = SorterEngine.shared
        
        // Очищаємо попередню історію
        if fileManager.fileExists(atPath: engine.historyFileURL.path) {
            try? fileManager.removeItem(at: engine.historyFileURL)
        }
        
        let categories = [
            "Зображення": true,
            "Відео": true,
            "Документи": true,
            "Аудіо": true,
            "Архіви": true,
            "Інші файли": true
        ]
        
        // 1. Тестування Dry Run
        print("\n1. Тестування попереднього перегляду (dryRun=true)...")
        let _ = engine.sortFiles(
            folderPath: sandboxURL.path,
            sortMode: .type,
            categories: categories,
            dryRun: true,
            detectDuplicates: true
        )
        
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("video1.mp4").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image_copy.png").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("pure_videos").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("pure_pics").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("mixed_stuff").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("empty_folder").path))
        assert(!engine.checkHistoryExists(), "Dry run не повинен створювати файл історії")
        print("✓ Попередній перегляд працює коректно (усі об'єкти залишились на місці)")
        
        // 2. Тестування реального сортування
        print("\n2. Тестування реального сортування з пошуком дублікатів...")
        let logsReal = engine.sortFiles(
            folderPath: sandboxURL.path,
            sortMode: .type,
            categories: categories,
            dryRun: false,
            detectDuplicates: true
        )
        for log in logsReal {
            print(log)
        }
        
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Відео/video1.mp4").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Аудіо/song.mp3").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Документи/doc1.pdf").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Зображення/image_another_copy.png").path))
        assert(!fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image.png").path))
        assert(!fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image_copy.png").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Відео/pure_videos/clip1.mp4").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Зображення/pure_pics/photo1.jpg").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("mixed_stuff/pic.jpg").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("empty_folder").path))
        assert(engine.checkHistoryExists(), "Має створитися файл історії")
        print("✓ Сортування чистих папок та збереження змішаних/порожніх пройшло успішно")
        
        // 3. Тестування скасування сортування (Undo)
        print("\n3. Тестування функції скасування сортування (Undo)...")
        let _ = engine.undoSorting()
        
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("video1.mp4").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("song.mp3").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("doc1.pdf").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image.png").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image_copy.png").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("image_another_copy.png").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("pure_videos/clip1.mp4").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("pure_pics/photo1.jpg").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("mixed_stuff/pic.jpg").path))
        assert(fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("empty_folder").path))
        
        assert(!fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Відео").path))
        assert(!fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Зображення").path))
        assert(!fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Аудіо").path))
        assert(!fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Документи").path))
        assert(!fileManager.fileExists(atPath: sandboxURL.appendingPathComponent("Дублікати").path))
        assert(!engine.checkHistoryExists(), "Файл історії має бути видалено після Undo")
        print("✓ Скасування (Undo) працює бездоганно")
        
        // 4. Тестування SecurityBookmarks
        print("\n4. Тестування SecurityBookmarks...")
        let bookmarkMgr = SecurityBookmarks.shared
        let testBookmarkFolder = sandboxURL.appendingPathComponent("bookmark_test_dir")
        try! fileManager.createDirectory(at: testBookmarkFolder, withIntermediateDirectories: true, attributes: nil)
        
        let bookmarkSaved = bookmarkMgr.saveBookmark(for: testBookmarkFolder)
        assert(bookmarkSaved, "Має успішно зберегти закладку безпеки")
        
        let restoredBookmarks = bookmarkMgr.restoreAllBookmarks()
        assert(restoredBookmarks.map { $0.path }.contains(testBookmarkFolder.path), "restoredBookmarks має містити тестову папку")
        
        bookmarkMgr.startAccessing(testBookmarkFolder)
        bookmarkMgr.stopAccessing(testBookmarkFolder)
        bookmarkMgr.removeBookmark(for: testBookmarkFolder)
        
        let restoredAfterRemove = bookmarkMgr.restoreAllBookmarks()
        assert(!restoredAfterRemove.map { $0.path }.contains(testBookmarkFolder.path), "Після видалення закладка не повинна відновлюватись")
        print("✓ SecurityBookmarks працює коректно")
        
        // 5. Тестування FSEventsWatcher
        print("\n5. Тестування FSEventsWatcher...")
        let watcher = FSEventsWatcher.shared
        let watchDir = sandboxURL.appendingPathComponent("watch_test_dir")
        try! fileManager.createDirectory(at: watchDir, withIntermediateDirectories: true, attributes: nil)
        
        let watchAdded = watcher.watchFolder(path: watchDir.path)
        assert(watchAdded, "Має успішно додати папку до відстеження")
        assert(watcher.getWatchedPaths().contains(watchDir.path), "getWatchedPaths має містити додану папку")
        assert(watcher.isWatching(), "Стрім моніторингу має бути запущений")
        
        // Створюємо синхронізацію для очікування події FSEvents
        let semaphore = DispatchSemaphore(value: 0)
        var receivedPaths: [String] = []
        
        watcher.onEvents = { paths in
            receivedPaths.append(contentsOf: paths)
            semaphore.signal()
        }
        
        // Створюємо новий файл у відстежуваній папці
        let triggerFile = watchDir.appendingPathComponent("new_file.txt")
        try! "hello event watcher".write(to: triggerFile, atomically: true, encoding: .utf8)
        
        // Очікуємо події протягом 3 секунд (латенція стріму 1.0 сек)
        let waitResult = semaphore.wait(timeout: .now() + 3.0)
        assert(waitResult == .success, "FSEventsWatcher не зафіксував додавання файлу")
        assert(receivedPaths.contains(triggerFile.path), "Отримані події мають містити шлях створеного файлу")
        print("✓ FSEventsWatcher успішно перехопив подію створення файлу")
        
        // Тестування призупинення
        watcher.pauseAll()
        assert(!watcher.isWatching(), "Після pauseAll моніторинг має призупинитись")
        
        watcher.resumeAll()
        assert(watcher.isWatching(), "Після resumeAll моніторинг має запуститись знову")
        
        watcher.shutdown()
        assert(watcher.getWatchedPaths().isEmpty, "Після shutdown список відстежуваних папок має бути порожнім")
        print("✓ FSEventsWatcher керування стрімом працює коректно")

        // 6. Тестування RuleEngine
        print("\n6. Тестування RuleEngine...")
        let ruleEngine = RuleEngine.shared
        
        // Очищаємо перед тестом
        if fileManager.fileExists(atPath: ruleEngine.rulesFileURL.path) {
            try? fileManager.removeItem(at: ruleEngine.rulesFileURL)
        }
        
        // Створюємо тестовий файл
        let ruleTestDir = sandboxURL.appendingPathComponent("rules_test_dir")
        let ruleDestDir = sandboxURL.appendingPathComponent("rules_dest_dir")
        try! fileManager.createDirectory(at: ruleTestDir, withIntermediateDirectories: true, attributes: nil)
        try! fileManager.createDirectory(at: ruleDestDir, withIntermediateDirectories: true, attributes: nil)
        
        let testFile = ruleTestDir.appendingPathComponent("Report_2026.pdf")
        try! "pdf file content data".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Тестуємо окремі умови
        let condName = RuleCondition(type: .nameMatches, value: "report")
        let condExt = RuleCondition(type: .extensionIs, value: "pdf")
        let condKind = RuleCondition(type: .kindIs, value: "doc")
        let condSize = RuleCondition(type: .sizeGreaterThan, value: "5")
        
        assert(ruleEngine.evaluate(condition: condName, for: testFile), "Умова nameMatches має повернути true")
        assert(ruleEngine.evaluate(condition: condExt, for: testFile), "Умова extensionIs має повернути true")
        assert(ruleEngine.evaluate(condition: condKind, for: testFile), "Умова kindIs (doc) має повернути true")
        assert(ruleEngine.evaluate(condition: condSize, for: testFile), "Умова sizeGreaterThan має повернути true")
        
        // Тестуємо невідповідні умови
        let condBadName = RuleCondition(type: .nameMatches, value: "photo")
        let condBadExt = RuleCondition(type: .extensionIs, value: "png")
        let condBadSize = RuleCondition(type: .sizeLessThan, value: "5")
        
        assert(!ruleEngine.evaluate(condition: condBadName, for: testFile), "Невірна умова nameMatches має повернути false")
        assert(!ruleEngine.evaluate(condition: condBadExt, for: testFile), "Невірна умова extensionIs має повернути false")
        assert(!ruleEngine.evaluate(condition: condBadSize, for: testFile), "Невірна умова sizeLessThan має повернути false")
        
        // Створюємо та додаємо правило
        let rule = Rule(
            name: "Сортувати звіти PDF",
            enabled: true,
            conditions: [condName, condExt, condKind],
            actions: [
                RuleAction(type: .rename, value: "Sorted_%filename%_%YYYY%_%MM%.%ext%"),
                RuleAction(type: .moveTo, value: ruleDestDir.path)
            ]
        )
        
        assert(ruleEngine.match(rule: rule, for: testFile), "Правило має відповідати файлу")
        
        // Виконуємо правило
        let execResult = ruleEngine.execute(rule: rule, for: testFile)
        assert(execResult.success, "Виконання дій правила має бути успішним")
        
        let calendar = Calendar.current
        let year = String(format: "%04d", calendar.component(.year, from: Date()))
        let month = String(format: "%02d", calendar.component(.month, from: Date()))
        let expectedNewName = "Sorted_Report_2026_\(year)_\(month).pdf"
        let expectedFinalURL = ruleDestDir.appendingPathComponent(expectedNewName)
        
        assert(fileManager.fileExists(atPath: expectedFinalURL.path), "Файл має бути перейменований та переміщений у цільову папку")
        assert(execResult.finalURL.path == expectedFinalURL.path, "Кінцевий URL має відповідати очікуваному шляху")
        print("✓ Умови та дії правил виконуються успішно")
        
        // Тестування збереження та завантаження правил у JSON
        ruleEngine.rules = [rule]
        ruleEngine.saveRules()
        
        // Скидаємо список і завантажуємо знову
        ruleEngine.rules = []
        ruleEngine.loadRules()
        
        assert(ruleEngine.rules.count == 1, "Має завантажитись 1 збережене правило")
        assert(ruleEngine.rules[0].name == "Сортувати звіти PDF", "Ім'я завантаженого правила має співпадати")
        assert(ruleEngine.rules[0].actions.count == 2, "Кількість дій має бути 2")
        print("✓ Збереження та завантаження rules.json працює коректно")
        
        // Очищення rules.json
        if fileManager.fileExists(atPath: ruleEngine.rulesFileURL.path) {
            try? fileManager.removeItem(at: ruleEngine.rulesFileURL)
        }

        // 7. Тестування HistoryManager
        print("\n7. Тестування HistoryManager...")
        let historyMgr = HistoryManager.shared
        
        // Очищаємо перед тестом
        historyMgr.clearAllHistory()
        if fileManager.fileExists(atPath: historyMgr.historyFileURL.path) {
            try? fileManager.removeItem(at: historyMgr.historyFileURL)
        }
        
        // Створюємо тестовий файл для переміщення в Смітник
        let trashSourceDir = sandboxURL.appendingPathComponent("trash_source_dir")
        try! fileManager.createDirectory(at: trashSourceDir, withIntermediateDirectories: true, attributes: nil)
        let fileToTrash = trashSourceDir.appendingPathComponent("duplicate_to_remove.txt")
        try! "duplicate text".write(to: fileToTrash, atomically: true, encoding: .utf8)
        
        // Видаляємо в Смітник
        let resultURL = historyMgr.trashItem(at: fileToTrash)
        assert(resultURL != nil, "Має успішно перенести файл до Смітника та повернути його новий URL")
        assert(!fileManager.fileExists(atPath: fileToTrash.path), "Файлу більше не повинно існувати за оригінальним шляхом")
        assert(fileManager.fileExists(atPath: resultURL!.path), "Файл має існувати в Смітнику")
        
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
        assert(historyMgr.checkHistoryExists(), "Історія має містити додану партію")
        
        // Виконуємо скасування (Undo), що має дістати файл зі Смітника!
        let undoSuccess = historyMgr.undoLastBatch()
        assert(undoSuccess, "Скасування партії має пройти успішно")
        assert(fileManager.fileExists(atPath: fileToTrash.path), "Скасування має повернути файл зі Смітника назад до оригінального шляху")
        assert(!fileManager.fileExists(atPath: resultURL!.path), "Файл має бути видалений зі Смітника після відновлення")
        print("✓ HistoryManager trashItem та undoLastBatch працюють коректно")
        
        // 8. Тестування RuleEngine v2
        print("\n8. Тестування RuleEngine v2 (nested groups, regex, tags, zip, conflict detector)...")
        
        let testFileV2 = ruleTestDir.appendingPathComponent("photo_123.jpg")
        try! "jpeg content data".write(to: testFileV2, atomically: true, encoding: .utf8)
        
        // 8.1. Тестуємо рекурсивні (nested) умови OR
        let condJpg = RuleCondition(type: .extensionIs, value: "jpg")
        let condPng = RuleCondition(type: .extensionIs, value: "png")
        let groupOr = RuleCondition(logicalOperator: .or, subconditions: [condJpg, condPng])
        
        assert(ruleEngine.evaluate(condition: groupOr, for: testFileV2), "Nested OR group (jpg OR png) має повернути true")
        
        // 8.2. Тестуємо Regex-умови
        let condRegexValid = RuleCondition(type: .filenameMatchesRegex, value: "^photo_\\d{3}\\.jpg$")
        let condRegexInvalid = RuleCondition(type: .filenameMatchesRegex, value: "[invalid regex")
        
        assert(ruleEngine.evaluate(condition: condRegexValid, for: testFileV2), "Regex '^photo_\\d{3}\\.jpg$' має повернути true")
        assert(!ruleEngine.evaluate(condition: condRegexInvalid, for: testFileV2), "Невалідний Regex має повернути false і не впасти")
        
        // 8.3. Тестуємо додавання тегів Finder та умов hasTag / doesNotHaveTag
        let ruleTags = Rule(
            name: "Додати тег Red",
            enabled: true,
            conditions: [condJpg],
            actions: [RuleAction(type: .addTag, value: "Red")]
        )
        let execTagsResult = ruleEngine.execute(rule: ruleTags, for: testFileV2)
        assert(execTagsResult.success, "Додавання тегу має пройти успішно")
        
        let condHasTag = RuleCondition(type: .hasTag, value: "Red")
        let condNoTag = RuleCondition(type: .doesNotHaveTag, value: "Green")
        assert(ruleEngine.evaluate(condition: condHasTag, for: testFileV2), "hasTag (Red) має повернути true")
        assert(ruleEngine.evaluate(condition: condNoTag, for: testFileV2), "doesNotHaveTag (Green) має повернути true")
        
        // 8.4. Тестуємо архівацію в ZIP
        let ruleZip = Rule(
            name: "Архівувати в ZIP",
            enabled: true,
            conditions: [condJpg],
            actions: [RuleAction(type: .archiveToZIP, value: "")]
        )
        let execZipResult = ruleEngine.execute(rule: ruleZip, for: testFileV2)
        assert(execZipResult.success, "Архівація повинна пройти успішно")
        assert(execZipResult.finalURL.pathExtension == "zip", "Кінцевий файл повинен мати розширення zip")
        assert(fileManager.fileExists(atPath: execZipResult.finalURL.path), "ZIP файл повинен існувати")
        assert(!fileManager.fileExists(atPath: testFileV2.path), "Оригінальний файл повинен бути видалений після архівації")
        
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
        assert(conflicts.count == 1, "Детектор має знайти один конфлікт")
        assert(conflicts[0].contains("мають однакові умови, але переміщують файли в різні папки"), "Текст попередження має містити опис конфлікту")
        print("✓ RuleEngine v2 (nested conditions, regex, tags, zip, conflict detector) перевірено")

        print("\nУСІ АВТОМАТИЧНІ ТЕСТИ УСПІШНО ПРОЙДЕНО! 🎉")
        
        // Clean up
        if fileManager.fileExists(atPath: sandboxURL.path) {
            try? fileManager.removeItem(at: sandboxURL)
        }
    }
}
