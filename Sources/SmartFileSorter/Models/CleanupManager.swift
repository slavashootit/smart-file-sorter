import Foundation

public struct LargeFileItem: Identifiable, Equatable {
    public let id = UUID()
    public let url: URL
    public let size: Int64
    public let lastOpened: Date
    public let category: String
}

public struct EmptyFolderItem: Identifiable, Equatable {
    public let id = UUID()
    public let url: URL
}

public final class CleanupManager: ObservableObject {
    @Published public var largeFiles: [LargeFileItem] = []
    @Published public var oldDownloads: [LargeFileItem] = []
    @Published public var emptyFolders: [EmptyFolderItem] = []
    @Published public var isScanning = false
    @Published public var progress: Double = 0.0
    
    private var isCancelled = false
    
    public init() {}
    
    public func cancelScan() {
        isCancelled = true
        isScanning = false
    }
    
    // 1. Пошук великих файлів (> X MB)
    public func scanLargeFiles(at path: String, minSizeMB: Int64 = 100, completion: @escaping () -> Void) {
        isCancelled = false
        isScanning = true
        progress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let rootURL = URL(fileURLWithPath: path)
            let minSizeBytes = minSizeMB * 1024 * 1024
            var results: [LargeFileItem] = []
            
            let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            var processed = 0
            while let fileURL = enumerator?.nextObject() as? URL {
                if self.isCancelled { break }
                
                let filePath = fileURL.path
                if self.shouldExclude(path: filePath) {
                    enumerator?.skipDescendants()
                    continue
                }
                
                var isDir: AnyObject?
                try? (fileURL as NSURL).getResourceValue(&isDir, forKey: .isDirectoryKey)
                if let isDirBool = isDir as? Bool, isDirBool {
                    continue
                }
                
                var sizeObj: AnyObject?
                try? (fileURL as NSURL).getResourceValue(&sizeObj, forKey: .fileSizeKey)
                if let size = sizeObj as? Int64, size >= minSizeBytes {
                    let lastOpened = self.getLastOpenedDate(for: fileURL)
                    let category = self.getFileCategory(fileURL)
                    results.append(LargeFileItem(url: fileURL, size: size, lastOpened: lastOpened, category: category))
                }
                
                processed += 1
                if processed % 500 == 0 {
                    DispatchQueue.main.async {
                        self.progress = min(0.9, Double(processed) / 10000.0) // Бутафорський прогрес для великих папок
                    }
                }
            }
            
            let sortedResults = results.sorted { $0.size > $1.size }
            
            DispatchQueue.main.async {
                self.largeFiles = sortedResults
                self.progress = 1.0
                self.isScanning = false
                completion()
            }
        }
    }
    
    // 2. Пошук старих завантажень (> N днів у ~/Downloads)
    public func scanOldDownloads(daysThreshold: Int = 30, completion: @escaping () -> Void) {
        isCancelled = false
        isScanning = true
        progress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let homeDir = NSHomeDirectory()
            let downloadsURL = URL(fileURLWithPath: "\(homeDir)/Downloads")
            
            let now = Date()
            let limitDate = now.addingTimeInterval(TimeInterval(-daysThreshold * 24 * 60 * 60))
            var results: [LargeFileItem] = []
            
            let enumerator = fileManager.enumerator(
                at: downloadsURL,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentAccessDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            while let fileURL = enumerator?.nextObject() as? URL {
                if self.isCancelled { break }
                
                var isDir: AnyObject?
                try? (fileURL as NSURL).getResourceValue(&isDir, forKey: .isDirectoryKey)
                if let isDirBool = isDir as? Bool, isDirBool {
                    continue
                }
                
                var creationDateObj: AnyObject?
                try? (fileURL as NSURL).getResourceValue(&creationDateObj, forKey: .creationDateKey)
                
                if let creationDate = creationDateObj as? Date, creationDate < limitDate {
                    var sizeObj: AnyObject?
                    try? (fileURL as NSURL).getResourceValue(&sizeObj, forKey: .fileSizeKey)
                    let size = (sizeObj as? Int64) ?? 0
                    let lastOpened = self.getLastOpenedDate(for: fileURL)
                    let category = self.getFileCategory(fileURL)
                    results.append(LargeFileItem(url: fileURL, size: size, lastOpened: lastOpened, category: category))
                }
            }
            
            let sorted = results.sorted { $0.size > $1.size }
            
            DispatchQueue.main.async {
                self.oldDownloads = sorted
                self.progress = 1.0
                self.isScanning = false
                completion()
            }
        }
    }
    
    // 3. Пошук порожніх папок
    public func scanEmptyFolders(at path: String, completion: @escaping () -> Void) {
        isCancelled = false
        isScanning = true
        progress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let rootURL = URL(fileURLWithPath: path)
            var results: [EmptyFolderItem] = []
            
            let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            while let fileURL = enumerator?.nextObject() as? URL {
                if self.isCancelled { break }
                
                let filePath = fileURL.path
                if self.shouldExclude(path: filePath) {
                    enumerator?.skipDescendants()
                    continue
                }
                
                var isDir: AnyObject?
                try? (fileURL as NSURL).getResourceValue(&isDir, forKey: .isDirectoryKey)
                if let isDirBool = isDir as? Bool, isDirBool {
                    if self.isEmptyFolder(fileURL) {
                        results.append(EmptyFolderItem(url: fileURL))
                        // Оскільки папка порожня, немає сенсу перевіряти вкладені підпапки
                        enumerator?.skipDescendants()
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.emptyFolders = results
                self.progress = 1.0
                self.isScanning = false
                completion()
            }
        }
    }
    
    // 4. Очищення Trash старше N днів (opt-in)
    public func purgeTrashItems(olderThanDays days: Int) -> Int {
        let fileManager = FileManager.default
        let homeDir = NSHomeDirectory()
        let trashURL = URL(fileURLWithPath: "\(homeDir)/.Trash")
        
        guard let enumerator = fileManager.enumerator(
            at: trashURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        let now = Date()
        let limitDate = now.addingTimeInterval(TimeInterval(-days * 24 * 60 * 60))
        var itemsToDelete: [URL] = []
        
        while let fileURL = enumerator.nextObject() as? URL {
            var isDirectory: AnyObject?
            try? (fileURL as NSURL).getResourceValue(&isDirectory, forKey: .isDirectoryKey)
            
            var modDate: AnyObject?
            try? (fileURL as NSURL).getResourceValue(&modDate, forKey: .contentModificationDateKey)
            
            if let date = modDate as? Date, date < limitDate {
                itemsToDelete.append(fileURL)
                if let isDirBool = isDirectory as? Bool, isDirBool {
                    enumerator.skipDescendants()
                }
            }
        }
        
        var deletedCount = 0
        for item in itemsToDelete {
            do {
                try fileManager.removeItem(at: item)
                deletedCount += 1
            } catch {
                print("[CLEANUP] Не вдалося видалити елемент зі смітника \(item.path): \(error.localizedDescription)")
            }
        }
        return deletedCount
    }
    
    // Допоміжні функції
    private func isEmptyFolder(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) else {
            return false
        }
        if contents.isEmpty { return true }
        
        for item in contents {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                if !isEmptyFolder(item) {
                    return false
                }
            } else {
                return false
            }
        }
        return true
    }
    
    private func getLastOpenedDate(for url: URL) -> Date {
        var lastUsed: AnyObject?
        try? (url as NSURL).getResourceValue(&lastUsed, forKey: .contentAccessDateKey)
        return (lastUsed as? Date) ?? (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? Date()
    }
    
    private func getFileCategory(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let fileCategories: [String: Set<String>] = [
            "Зображення": Set(["png", "jpg", "jpeg", "gif", "heic", "tiff", "raw", "psd"]),
            "Відео": Set(["mp4", "mov", "avi", "mkv", "webm", "flv"]),
            "Документи": Set(["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "pages", "numbers", "key"]),
            "Аудіо": Set(["mp3", "wav", "aac", "flac", "m4a", "ogg"]),
            "Архіви": Set(["zip", "tar", "gz", "rar", "7z", "dmg", "pkg"])
        ]
        
        for (category, extensions) in fileCategories {
            if extensions.contains(ext) {
                return category
            }
        }
        return "Інші файли"
    }
    
    private func shouldExclude(path: String) -> Bool {
        if path.hasPrefix("/System") || path.hasPrefix("/Library") || path.hasPrefix("/private") ||
           path.hasPrefix("/usr") || path.hasPrefix("/bin") || path.hasPrefix("/sbin") {
            return true
        }
        
        let homeDir = NSHomeDirectory()
        if path.hasPrefix("\(homeDir)/Library") || path.hasPrefix("\(homeDir)/.Trash") {
            return true
        }
        
        let pathComponents = URL(fileURLWithPath: path).pathComponents
        for component in pathComponents {
            let compLower = component.lowercased()
            if compLower == ".git" || compLower == "node_modules" || compLower == ".trash" ||
               compLower == "timemachine.backupdb" || compLower.hasSuffix(".backupbundle") || compLower.hasSuffix(".backupdb") {
                return true
            }
        }
        return false
    }
}
