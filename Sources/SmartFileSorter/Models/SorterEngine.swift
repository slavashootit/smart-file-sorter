import Foundation
import AppKit

public enum SortMode: String, Codable {
    case type
    case date
}

public struct MoveRecord: Codable {
    public let original: String
    public let new: String
    
    public init(original: String, new: String) {
        self.original = original
        self.new = new
    }
}

public struct SessionHistory: Codable {
    public let base_dir: String
    public var moves: [MoveRecord]
    public var created_dirs: [String]
    
    public init(base_dir: String, moves: [MoveRecord] = [], created_dirs: [String] = []) {
        self.base_dir = base_dir
        self.moves = moves
        self.created_dirs = created_dirs
    }
}

public struct SortProgress: Sendable {
    public let processedCount: Int
    public let totalCount: Int
    public let currentItem: String
    public let logEntry: String?
    public let isFinished: Bool
    public let finalLogs: [String]?
    
    public init(processedCount: Int, totalCount: Int, currentItem: String, logEntry: String? = nil, isFinished: Bool = false, finalLogs: [String]? = nil) {
        self.processedCount = processedCount
        self.totalCount = totalCount
        self.currentItem = currentItem
        self.logEntry = logEntry
        self.isFinished = isFinished
        self.finalLogs = finalLogs
    }
}

public class SorterEngine {
    
    public static let shared = SorterEngine()
    
    public init() {}
    
    // Категорії та відповідні розширення файлів
    public var fileCategories: [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for (category, extensions) in ConfigManager.shared.categories {
            result[category] = Set(extensions)
        }
        return result
    }
    
    private let monthsUa = [
        1: "Січень", 2: "Лютий", 3: "Березень", 4: "Квітень", 5: "Травень", 6: "Червень",
        7: "Липень", 8: "Серпень", 9: "Вересень", 10: "Жовтень", 11: "Листопад", 12: "Грудень"
    ]
    
    // Перевірка, чи папка має бути виключена
    public func isExcludedDir(_ url: URL) -> Bool {
        return ConfigManager.shared.shouldExclude(url: url)
    }
    
    // Класифікувати один файл за розширенням
    public func getFileCategory(_ url: URL) -> String {
        return ConfigManager.shared.getFileCategory(url)
    }
    
    // Рекурсивний аналіз папки для визначення категорії (чиста/змішана/порожня)
    public func getDirectoryCategoryAndFiles(_ dirURL: URL) -> (category: String?, files: [URL]) {
        var allFiles: [URL] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (nil, [])
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                  let isDir = resourceValues.isDirectory, !isDir else {
                continue
            }
            if fileURL.lastPathComponent.hasPrefix(".") {
                continue
            }
            allFiles.append(fileURL)
        }
        
        if allFiles.isEmpty {
            return (nil, []) // Порожня
        }
        
        var firstCategory: String? = nil
        for fileURL in allFiles {
            let cat = getFileCategory(fileURL)
            if firstCategory == nil {
                firstCategory = cat
            } else if firstCategory != cat {
                return ("mixed", allFiles) // Змішана
            }
        }
        
        return (firstCategory, allFiles) // Чиста
    }
    
    // Генерація унікального імені призначення для уникнення перезапису
    public func uniqueDestPath(baseFolder: URL, source: URL) -> URL {
        var dest = baseFolder.appendingPathComponent(source.lastPathComponent)
        let ext = source.pathExtension
        let baseName = source.deletingPathExtension().lastPathComponent
        var counter = 1
        
        var isDir: Bool = false
        var isDirVal: AnyObject?
        try? (source as NSURL).getResourceValue(&isDirVal, forKey: .isDirectoryKey)
        if let number = isDirVal as? NSNumber {
            isDir = number.boolValue
        }
        
        while FileManager.default.fileExists(atPath: dest.path) {
            if isDir {
                dest = baseFolder.appendingPathComponent("\(baseName)_\(counter)")
            } else {
                let suffix = ext.isEmpty ? "" : ".\(ext)"
                dest = baseFolder.appendingPathComponent("\(baseName)_\(counter)\(suffix)")
            }
            counter += 1
        }
        return dest
    }
    
    // Сортування файлів та підпапок
    public func sortFiles(
        folderPath: String,
        sortMode: SortMode,
        categories: [String: Bool],
        dryRun: Bool,
        detectDuplicates: Bool = false
    ) -> AsyncStream<SortProgress> {
        return AsyncStream(SortProgress.self, bufferingPolicy: .bufferingNewest(100)) { continuation in
            let task = Task {
                let fileManager = FileManager.default
                let targetURL = URL(fileURLWithPath: folderPath)
                
                guard fileManager.fileExists(atPath: targetURL.path) else {
                    continuation.yield(SortProgress(
                        processedCount: 0,
                        totalCount: 0,
                        currentItem: "",
                        logEntry: "Помилка: вказана папка не існує!",
                        isFinished: true,
                        finalLogs: ["Помилка: вказана папка не існує!"]
                    ))
                    continuation.finish()
                    return
                }
                
                let actionWord = dryRun ? "Попередній перегляд" : "Сортування"
                var filesToSort: [URL] = []
                var dirsToSort: [URL] = []
                
                // Зчитуємо вміст кореня папки
                do {
                    let contents = try fileManager.contentsOfDirectory(at: targetURL, includingPropertiesForKeys: [.isDirectoryKey], options: [])
                    for item in contents {
                        if item.lastPathComponent.hasPrefix(".") {
                            continue
                        }
                        var isDirVal: AnyObject?
                        try? (item as NSURL).getResourceValue(&isDirVal, forKey: .isDirectoryKey)
                        let isDir = (isDirVal as? NSNumber)?.boolValue ?? false
                        
                        if isDir {
                            if !self.isExcludedDir(item) {
                                dirsToSort.append(item)
                            }
                        } else {
                            filesToSort.append(item)
                        }
                    }
                } catch {
                    continuation.yield(SortProgress(
                        processedCount: 0,
                        totalCount: 0,
                        currentItem: "",
                        logEntry: "Не вдалося отримати доступ до папки: \(error.localizedDescription)",
                        isFinished: true,
                        finalLogs: ["Не вдалося отримати доступ до папки: \(error.localizedDescription)"]
                    ))
                    continuation.finish()
                    return
                }
                
                // Сортуємо алфавітно
                filesToSort.sort { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
                dirsToSort.sort { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
                
                let totalCount = filesToSort.count + dirsToSort.count
                if totalCount == 0 {
                    continuation.yield(SortProgress(
                        processedCount: 0,
                        totalCount: 0,
                        currentItem: "",
                        logEntry: "У цій папці немає файлів чи підпапок для сортування.",
                        isFinished: true,
                        finalLogs: [
                            "У цій папці немає файлів чи підпапок для сортування.",
                            "--- Процес завершено ---"
                        ]
                    ))
                    continuation.finish()
                    return
                }
                
                var processedCount = 0
                var movedCount = 0
                var ignoredCount = 0
                var duplicateCount = 0
                var logs: [String] = []
                var history = SessionHistory(base_dir: targetURL.path)
                
                // Попередній аналіз дублікатів (size -> quick -> full) за допомогою XXHash64
                var duplicateMap: [URL: URL] = [:]
                if detectDuplicates {
                    var sizeMap: [Int64: [URL]] = [:]
                    for fileURL in filesToSort {
                        if Task.isCancelled { break }
                        let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
                        if size > 0 {
                            sizeMap[size, default: []].append(fileURL)
                        }
                    }
                    
                    var pass1Map: [String: [URL]] = [:]
                    for (size, urls) in sizeMap where urls.count > 1 {
                        if Task.isCancelled { break }
                        for url in urls {
                            if Task.isCancelled { break }
                            
                            let mtime = ((try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)?.timeIntervalSince1970) ?? 0
                            
                            var pass1: String? = nil
                             if let hashes = await HashCache.shared.getHashes(for: url, size: size, mtime: mtime) {
                                 pass1 = hashes.pass1
                             }
                            
                            if pass1 == nil {
                                if let calculated = XXHash64.getPass1Hash(url: url) {
                                    pass1 = calculated
                                    await HashCache.shared.store(url: url, size: size, mtime: mtime, pass1: calculated, pass2: nil)
                                }
                            }
                            
                            if let finalPass1 = pass1 {
                                let key = "\(size)-\(finalPass1)"
                                pass1Map[key, default: []].append(url)
                            }
                        }
                    }
                    
                    for (key, urls) in pass1Map where urls.count > 1 {
                        if Task.isCancelled { break }
                        var pass2Map: [String: [URL]] = [:]
                        
                        let components = key.components(separatedBy: "-")
                        let pass1Hash = components.dropFirst().joined(separator: "-")
                        
                        for url in urls {
                            if Task.isCancelled { break }
                            
                            let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                            let mtime = ((try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)?.timeIntervalSince1970) ?? 0
                            
                            var pass2: String? = nil
                             if let hashes = await HashCache.shared.getHashes(for: url, size: size, mtime: mtime) {
                                 pass2 = hashes.pass2
                             }
                            
                            if pass2 == nil {
                                if let calculated = XXHash64.getPass2Hash(url: url, checkCancellation: { Task.isCancelled }) {
                                    pass2 = calculated
                                    await HashCache.shared.store(url: url, size: size, mtime: mtime, pass1: pass1Hash, pass2: calculated)
                                }
                            }
                            
                            if let finalPass2 = pass2 {
                                pass2Map[finalPass2, default: []].append(url)
                            }
                        }
                        
                        for (_, matchedUrls) in pass2Map where matchedUrls.count > 1 {
                            let sortedMatched = matchedUrls.sorted(by: { $0.path.localizedCompare($1.path) == .orderedAscending })
                            let original = sortedMatched[0]
                            for dup in sortedMatched.dropFirst() {
                                duplicateMap[dup] = original
                            }
                        }
                    }
                }
                
                // Допоміжна функція для логування створення папок в історію
                func recordDirCreation(_ dirURL: URL) {
                    var p = dirURL
                    var parentsToCreate: [URL] = []
                    while p.path != targetURL.path && p.path != p.deletingLastPathComponent().path {
                        if !fileManager.fileExists(atPath: p.path) {
                            parentsToCreate.append(p)
                        }
                        p = p.deletingLastPathComponent()
                    }
                    for parent in parentsToCreate.reversed() {
                        if !history.created_dirs.contains(parent.path) {
                            history.created_dirs.append(parent.path)
                        }
                    }
                }
                
                var cancelled = false
                
                // 1. Спочатку сортуємо чисті підпапки
                for dirURL in dirsToSort {
                    if Task.isCancelled {
                        cancelled = true
                        break
                    }
                    
                    let currentItemName = dirURL.lastPathComponent
                    let (catOpt, dirFiles) = self.getDirectoryCategoryAndFiles(dirURL)
                    
                    guard let cat = catOpt else {
                        ignoredCount += 1
                        processedCount += 1
                        let log = "[ПРОПУЩЕНО] Папка '\(dirURL.lastPathComponent)' порожня"
                        logs.append(log)
                        continuation.yield(SortProgress(processedCount: processedCount, totalCount: totalCount, currentItem: currentItemName, logEntry: log))
                        continue
                    }
                    
                    if cat == "mixed" {
                        ignoredCount += 1
                        processedCount += 1
                        let log = "[ПРОПУЩЕНО] Папка '\(dirURL.lastPathComponent)' містить змішані файли (не сортуємо)"
                        logs.append(log)
                        continuation.yield(SortProgress(processedCount: processedCount, totalCount: totalCount, currentItem: currentItemName, logEntry: log))
                        continue
                    }
                    
                    // Чиста папка - перевіряємо, чи увімкнено її категорію
                    if !(categories[cat] ?? true) {
                        ignoredCount += 1
                        processedCount += 1
                        continuation.yield(SortProgress(processedCount: processedCount, totalCount: totalCount, currentItem: currentItemName))
                        continue
                    }
                    
                    var destFolder: URL? = nil
                    if sortMode == .type {
                        destFolder = targetURL.appendingPathComponent(cat)
                    } else if sortMode == .date {
                        // Визначаємо дату за найновішим файлом
                        let newestFile = dirFiles.max(by: { url1, url2 in
                            let date1 = (try? url1.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                            let date2 = (try? url2.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                            return date1 < date2
                        })
                        
                        if let newest = newestFile {
                            let date = (try? newest.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]).contentModificationDate) ?? Date()
                            let calendar = Calendar.current
                            let year = String(calendar.component(.year, from: date))
                            let monthNum = calendar.component(.month, from: date)
                            let monthName = self.monthsUa[monthNum] ?? "Місяць"
                            let folderName = String(format: "%@-%02d_%@", year, monthNum, monthName)
                            destFolder = targetURL.appendingPathComponent(year).appendingPathComponent(folderName)
                        }
                    }
                    
                    guard let dest = destFolder else {
                        ignoredCount += 1
                        processedCount += 1
                        continuation.yield(SortProgress(processedCount: processedCount, totalCount: totalCount, currentItem: currentItemName))
                        continue
                    }
                    
                    if dirURL.deletingLastPathComponent().path == dest.path {
                        processedCount += 1
                        continuation.yield(SortProgress(processedCount: processedCount, totalCount: totalCount, currentItem: currentItemName))
                        continue
                    }
                    
                    let destDirPath = self.uniqueDestPath(baseFolder: dest, source: dirURL)
                    let relDest = destDirPath.path.replacingOccurrences(of: targetURL.path + "/", with: "")
                    
                    var logLine = ""
                    if dryRun {
                        logLine = "[ПЛАНУЄТЬСЯ] Папку '\(dirURL.lastPathComponent)' (тільки \(cat.lowercased())) -> в '\(relDest)'"
                        logs.append(logLine)
                    } else {
                        do {
                            recordDirCreation(dest)
                            try fileManager.createDirectory(at: dest, withIntermediateDirectories: true, attributes: nil)
                            try fileManager.moveItem(at: dirURL, to: destDirPath)
                            logLine = "[УСПІШНО] Папку '\(dirURL.lastPathComponent)' -> перенесено в '\(relDest)'"
                            logs.append(logLine)
                            history.moves.append(MoveRecord(original: dirURL.path, new: destDirPath.path))
                        } catch {
                            logLine = "[ПОМИЛКА] Не вдалося перемістити папку '\(dirURL.lastPathComponent)': \(error.localizedDescription)"
                            logs.append(logLine)
                        }
                    }
                    movedCount += 1
                    processedCount += 1
                    continuation.yield(SortProgress(processedCount: processedCount, totalCount: totalCount, currentItem: currentItemName, logEntry: logLine))
                }
                
                // 2. Сортуємо окремі файли в корені
                for fileURL in filesToSort {
                    if Task.isCancelled || cancelled {
                        cancelled = true
                        break
                    }
                    
                    let currentItemName = fileURL.lastPathComponent
                    var isDuplicate = false
                    var originalFile: URL? = nil
                    
                    if detectDuplicates {
                        if let orig = duplicateMap[fileURL] {
                            isDuplicate = true
                            originalFile = orig
                        }
                    }
                    
                    var logLine = ""
                    if isDuplicate, let orig = originalFile {
                        if dryRun {
                            logLine = "[ДУБЛІКАТ] '\(fileURL.lastPathComponent)' є копією '\(orig.lastPathComponent)' -> буде перенесено в Смітник"
                            logs.append(logLine)
                        } else {
                            if let trashedURL = HistoryManager.shared.trashItem(at: fileURL) {
                                logLine = "[ДУБЛІКАТ] '\(fileURL.lastPathComponent)' -> перенесено в Смітник"
                                logs.append(logLine)
                                history.moves.append(MoveRecord(original: fileURL.path, new: trashedURL.path))
                            } else {
                                logLine = "[ПОМИЛКА] Не вдалося перемістити дублікат '\(fileURL.lastPathComponent)' у Смітник"
                                logs.append(logLine)
                            }
                        }
                        duplicateCount += 1
                        movedCount += 1
                        processedCount += 1
                        continuation.yield(SortProgress(processedCount: processedCount, totalCount: totalCount, currentItem: currentItemName, logEntry: logLine))
                        continue
                    }
                    
                    // Звичайне сортування файлу
                    let cat = self.getFileCategory(fileURL)
                    if !(categories[cat] ?? true) {
                        ignoredCount += 1
                        processedCount += 1
                        continuation.yield(SortProgress(processedCount: processedCount, totalCount: totalCount, currentItem: currentItemName))
                        continue
                    }
                    
                    var destFolder: URL? = nil
                    if sortMode == .type {
                        destFolder = targetURL.appendingPathComponent(cat)
                    } else if sortMode == .date {
                        let date = (try? fileURL.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]).contentModificationDate) ?? Date()
                        let calendar = Calendar.current
                        let year = String(calendar.component(.year, from: date))
                        let monthNum = calendar.component(.month, from: date)
                        let monthName = self.monthsUa[monthNum] ?? "Місяць"
                        let folderName = String(format: "%@-%02d_%@", year, monthNum, monthName)
                        destFolder = targetURL.appendingPathComponent(year).appendingPathComponent(folderName)
                    }
                    
                    guard let dest = destFolder else {
                        ignoredCount += 1
                        processedCount += 1
                        continuation.yield(SortProgress(processedCount: processedCount, totalCount: totalCount, currentItem: currentItemName))
                        continue
                    }
                    
                    if fileURL.deletingLastPathComponent().path == dest.path {
                        processedCount += 1
                        continuation.yield(SortProgress(processedCount: processedCount, totalCount: totalCount, currentItem: currentItemName))
                        continue
                    }
                    
                    let destFilePath = self.uniqueDestPath(baseFolder: dest, source: fileURL)
                    let relDest = destFilePath.path.replacingOccurrences(of: targetURL.path + "/", with: "")
                    
                    if dryRun {
                        logLine = "[ПЛАНУЄТЬСЯ] '\(fileURL.lastPathComponent)' -> в '\(dest.lastPathComponent)'"
                        logs.append(logLine)
                    } else {
                        do {
                            recordDirCreation(dest)
                            try fileManager.createDirectory(at: dest, withIntermediateDirectories: true, attributes: nil)
                            try fileManager.moveItem(at: fileURL, to: destFilePath)
                            logLine = "[УСПІШНО] '\(fileURL.lastPathComponent)' -> '\(relDest)'"
                            logs.append(logLine)
                            
                            await MainActor.run {
                                if NSApplication.shared.isRunning {
                                    FileAnimator.shared.triggerMovement(
                                        name: fileURL.lastPathComponent,
                                        isFolder: false,
                                        from: CGPoint(x: CGFloat.random(in: 100...200), y: CGFloat.random(in: 100...200)),
                                        to: CGPoint(x: CGFloat.random(in: 400...500), y: CGFloat.random(in: 350...450))
                                    )
                                }
                            }
                            history.moves.append(MoveRecord(original: fileURL.path, new: destFilePath.path))
                        } catch {
                            logLine = "[ПОМИЛКА] Не вдалося перемістити '\(fileURL.lastPathComponent)': \(error.localizedDescription)"
                            logs.append(logLine)
                        }
                    }
                    movedCount += 1
                    processedCount += 1
                    continuation.yield(SortProgress(processedCount: processedCount, totalCount: totalCount, currentItem: currentItemName, logEntry: logLine))
                }
                
                // Звіт та фіналізація
                var finalLogs: [String] = []
                if cancelled {
                    finalLogs.append("\n--- Процес перервано користувачем ---")
                    finalLogs.append("Перервано: \(movedCount) з \(totalCount) об'єктів. Undo доступний як зазвичай.")
                    
                    // Зберігаємо часткову сесію
                    if !history.moves.isEmpty && !dryRun {
                        let batchOps = history.moves.map { move -> BatchOperation in
                            let size = (try? fileManager.attributesOfItem(atPath: move.new)[.size] as? Int64) ?? 0
                            let isTrash = move.new.contains("/.Trash/") || move.new.contains("/Trash/")
                            return BatchOperation(originalPath: move.original, newPath: move.new, isTrashed: isTrash, fileSize: size)
                        }
                        let batch = BatchRecord(
                            timestamp: Date(),
                            operations: batchOps,
                            createdDirs: history.created_dirs,
                            isCancelled: true
                        )
                        HistoryManager.shared.addBatch(batch)
                    }
                } else {
                    finalLogs.append("\n--- \(actionWord) завершено ---")
                    if dryRun {
                        finalLogs.append("Буде впорядковано об'єктів: \(movedCount)")
                        if detectDuplicates {
                            finalLogs.append("З них дублікатів: \(duplicateCount)")
                        }
                        finalLogs.append("Проігноровано/пропущено: \(ignoredCount)")
                        finalLogs.append("Жодних змін на диску не було проведено.")
                    } else {
                        finalLogs.append("Успішно впорядковано об'єктів: \(movedCount)")
                        if detectDuplicates {
                            finalLogs.append("З них перенесено як дублікати: \(duplicateCount)")
                        }
                        finalLogs.append("Проігноровано/пропущено: \(ignoredCount)")
                        
                        // Зберігаємо історію
                        if !history.moves.isEmpty {
                            let batchOps = history.moves.map { move -> BatchOperation in
                                let size = (try? fileManager.attributesOfItem(atPath: move.new)[.size] as? Int64) ?? 0
                                let isTrash = move.new.contains("/.Trash/") || move.new.contains("/Trash/")
                                return BatchOperation(originalPath: move.original, newPath: move.new, isTrashed: isTrash, fileSize: size)
                            }
                            let batch = BatchRecord(
                                timestamp: Date(),
                                operations: batchOps,
                                createdDirs: history.created_dirs,
                                isCancelled: false
                            )
                            HistoryManager.shared.addBatch(batch)
                        }
                    }
                }
                
                continuation.yield(SortProgress(
                    processedCount: processedCount,
                    totalCount: totalCount,
                    currentItem: "",
                    logEntry: nil,
                    isFinished: true,
                    finalLogs: finalLogs
                ))
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable termination in
                if case .cancelled = termination {
                    task.cancel()
                }
            }
        }
    }
    
    // Скасування останнього сортування (Undo)
    public func undoSorting() -> [String] {
        return HistoryManager.shared.undoLastBatch()
    }
    
    // Перевірка наявності файлу історії
    public func checkHistoryExists() -> Bool {
        return HistoryManager.shared.checkHistoryExists()
    }
}

extension SorterEngine {
    public func moveToTrash(_ urls: [URL]) async throws {
        for url in urls {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }
}

