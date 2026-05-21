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

public class SorterEngine {
    
    public static let shared = SorterEngine()
    
    public init() {}
    
    // Категорії та відповідні розширення файлів
    public let fileCategories: [String: Set<String>] = [
        "Зображення": ["jpg", "jpeg", "png", "gif", "bmp", "heic", "tiff", "svg", "webp"],
        "Відео": ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"],
        "Документи": ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "odt", "csv", "pages", "numbers", "key"],
        "Аудіо": ["mp3", "wav", "m4a", "flac", "aac", "ogg", "wma"],
        "Архіви": ["zip", "rar", "7z", "tar", "gz", "dmg", "pkg"]
    ]
    
    private let monthsUa = [
        1: "Січень", 2: "Лютий", 3: "Березень", 4: "Квітень", 5: "Травень", 6: "Червень",
        7: "Липень", 8: "Серпень", 9: "Вересень", 10: "Жовтень", 11: "Листопад", 12: "Грудень"
    ]
    
    private let excludedNames: Set<String> = ["Відео", "Зображення", "Документи", "Аудіо", "Архіви", "Дублікати", "Інші файли"]
    

    
    // Перевірка, чи папка має бути виключена
    public func isExcludedDir(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if excludedNames.contains(name) {
            return true
        }
        if name.count == 4, name.allSatisfy({ $0.isNumber }) {
            return true
        }
        return false
    }
    
    
    // Класифікувати один файл за розширенням
    public func getFileCategory(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        for (category, extensions) in fileCategories {
            if extensions.contains(ext) {
                return category
            }
        }
        return "Інші файли"
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
    ) -> [String] {
        var logs: [String] = []
        let fileManager = FileManager.default
        let targetURL = URL(fileURLWithPath: folderPath)
        
        guard fileManager.fileExists(atPath: targetURL.path) else {
            return ["Помилка: вказана папка не існує!"]
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
                    if !isExcludedDir(item) {
                        dirsToSort.append(item)
                    }
                } else {
                    filesToSort.append(item)
                }
            }
        } catch {
            return ["Не вдалося отримати доступ до папки: \(error.localizedDescription)"]
        }
        
        // Сортуємо алфавітно
        filesToSort.sort { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
        dirsToSort.sort { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
        
        if filesToSort.isEmpty && dirsToSort.isEmpty {
            logs.append("У цій папці немає файлів чи підпапок для сортування.")
            logs.append("--- Процес завершено ---")
            return logs
        }
        
        var movedCount = 0
        var ignoredCount = 0
        var duplicateCount = 0
        
        var history = SessionHistory(base_dir: targetURL.path)
        
        // Попередній аналіз дублікатів (size -> quick -> full) за допомогою XXHash64
        var duplicateMap: [URL: URL] = [:]
        if detectDuplicates {
            var sizeMap: [Int64: [URL]] = [:]
            for fileURL in filesToSort {
                let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
                if size > 0 {
                    sizeMap[size, default: []].append(fileURL)
                }
            }
            
            var pass1Map: [String: [URL]] = [:]
            for (size, urls) in sizeMap where urls.count > 1 {
                for url in urls {
                    if let pass1 = XXHash64.getPass1Hash(url: url) {
                        let key = "\(size)-\(pass1)"
                        pass1Map[key, default: []].append(url)
                    }
                }
            }
            
            for (_, urls) in pass1Map where urls.count > 1 {
                var pass2Map: [String: [URL]] = [:]
                for url in urls {
                    if let pass2 = XXHash64.getPass2Hash(url: url) {
                        pass2Map[pass2, default: []].append(url)
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
        
        // 1. Спочатку сортуємо чисті підпапки
        for dirURL in dirsToSort {
            let (catOpt, dirFiles) = getDirectoryCategoryAndFiles(dirURL)
            
            guard let cat = catOpt else {
                ignoredCount += 1
                logs.append("[ПРОПУЩЕНО] Папка '\(dirURL.lastPathComponent)' порожня")
                continue
            }
            
            if cat == "mixed" {
                ignoredCount += 1
                logs.append("[ПРОПУЩЕНО] Папка '\(dirURL.lastPathComponent)' містить змішані файли (не сортуємо)")
                continue
            }
            
            // Чиста папка - перевіряємо, чи увімкнено її категорію
            if !(categories[cat] ?? true) {
                ignoredCount += 1
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
                    let monthName = monthsUa[monthNum] ?? "Місяць"
                    let folderName = String(format: "%@-%02d_%@", year, monthNum, monthName)
                    destFolder = targetURL.appendingPathComponent(year).appendingPathComponent(folderName)
                }
            }
            
            guard let dest = destFolder else {
                ignoredCount += 1
                continue
            }
            
            if dirURL.deletingLastPathComponent().path == dest.path {
                continue
            }
            
            let destDirPath = uniqueDestPath(baseFolder: dest, source: dirURL)
            let relDest = destDirPath.path.replacingOccurrences(of: targetURL.path + "/", with: "")
            
            if dryRun {
                logs.append("[ПЛАНУЄТЬСЯ] Папку '\(dirURL.lastPathComponent)' (тільки \(cat.lowercased())) -> в '\(relDest)'")
            } else {
                do {
                    recordDirCreation(dest)
                    try fileManager.createDirectory(at: dest, withIntermediateDirectories: true, attributes: nil)
                    try fileManager.moveItem(at: dirURL, to: destDirPath)
                    logs.append("[УСПІШНО] Папку '\(dirURL.lastPathComponent)' -> перенесено в '\(relDest)'")
                    history.moves.append(MoveRecord(original: dirURL.path, new: destDirPath.path))
                } catch {
                    logs.append("[ПОМИЛКА] Не вдалося перемістити папку '\(dirURL.lastPathComponent)': \(error.localizedDescription)")
                }
            }
            movedCount += 1
        }
        
        // 2. Сортуємо окремі файли в корені
        for fileURL in filesToSort {
            var isDuplicate = false
            var originalFile: URL? = nil
            
            if detectDuplicates {
                if let orig = duplicateMap[fileURL] {
                    isDuplicate = true
                    originalFile = orig
                }
            }
            
            if isDuplicate, let orig = originalFile {
                if dryRun {
                    logs.append("[ДУБЛІКАТ] '\(fileURL.lastPathComponent)' є копією '\(orig.lastPathComponent)' -> буде перенесено в Смітник")
                } else {
                    if let trashedURL = HistoryManager.shared.trashItem(at: fileURL) {
                        logs.append("[ДУБЛІКАТ] '\(fileURL.lastPathComponent)' -> перенесено в Смітник")
                        history.moves.append(MoveRecord(original: fileURL.path, new: trashedURL.path))
                    } else {
                        logs.append("[ПОМИЛКА] Не вдалося перемістити дублікат '\(fileURL.lastPathComponent)' у Смітник")
                    }
                }
                duplicateCount += 1
                movedCount += 1
                continue
            }
            
            // Звичайне сортування файлу
            let cat = getFileCategory(fileURL)
            if !(categories[cat] ?? true) {
                ignoredCount += 1
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
                let monthName = monthsUa[monthNum] ?? "Місяць"
                let folderName = String(format: "%@-%02d_%@", year, monthNum, monthName)
                destFolder = targetURL.appendingPathComponent(year).appendingPathComponent(folderName)
            }
            
            guard let dest = destFolder else {
                ignoredCount += 1
                continue
            }
            
            if fileURL.deletingLastPathComponent().path == dest.path {
                continue
            }
            
            let destFilePath = uniqueDestPath(baseFolder: dest, source: fileURL)
            let relDest = destFilePath.path.replacingOccurrences(of: targetURL.path + "/", with: "")
            
            if dryRun {
                logs.append("[ПЛАНУЄТЬСЯ] '\(fileURL.lastPathComponent)' -> в '\(dest.lastPathComponent)'")
            } else {
                do {
                    recordDirCreation(dest)
                    try fileManager.createDirectory(at: dest, withIntermediateDirectories: true, attributes: nil)
                    try fileManager.moveItem(at: fileURL, to: destFilePath)
                    logs.append("[УСПІШНО] '\(fileURL.lastPathComponent)' -> '\(relDest)'")
                    if NSApp != nil {
                        FileAnimator.shared.triggerMovement(
                            name: fileURL.lastPathComponent,
                            isFolder: false,
                            from: CGPoint(x: CGFloat.random(in: 100...200), y: CGFloat.random(in: 100...200)),
                            to: CGPoint(x: CGFloat.random(in: 400...500), y: CGFloat.random(in: 350...450))
                        )
                    }
                    history.moves.append(MoveRecord(original: fileURL.path, new: destFilePath.path))
                } catch {
                    logs.append("[ПОМИЛКА] Не вдалося перемістити '\(fileURL.lastPathComponent)': \(error.localizedDescription)")
                }
            }
            movedCount += 1
        }
        
        logs.append("\n--- \(actionWord) завершено ---")
        if dryRun {
            logs.append("Буде впорядковано об'єктів: \(movedCount)")
            if detectDuplicates {
                logs.append("З них дублікатів: \(duplicateCount)")
            }
            logs.append("Проігноровано/пропущено: \(ignoredCount)")
            logs.append("Жодних змін на диску не було проведено.")
        } else {
            logs.append("Успішно впорядковано об'єктів: \(movedCount)")
            if detectDuplicates {
                logs.append("З них перенесено як дублікати: \(duplicateCount)")
            }
            logs.append("Проігноровано/пропущено: \(ignoredCount)")
            
            // Зберігаємо історію
            if !history.moves.isEmpty {
                let batchOps = history.moves.map { move -> BatchOperation in
                    let size = (try? fileManager.attributesOfItem(atPath: move.new)[.size] as? Int64) ?? 0
                    let isTrash = move.new.contains("/.Trash/") || move.new.contains("/Trash/")
                    return BatchOperation(originalPath: move.original, newPath: move.new, isTrashed: isTrash, fileSize: size)
                }
                let activeProfile = UserDefaults.standard.string(forKey: "active_profile") ?? "Home"
                let batch = BatchRecord(
                    timestamp: Date(),
                    operations: batchOps,
                    createdDirs: history.created_dirs,
                    profileName: activeProfile
                )
                HistoryManager.shared.addBatch(batch)
            }
        }
        
        return logs
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
