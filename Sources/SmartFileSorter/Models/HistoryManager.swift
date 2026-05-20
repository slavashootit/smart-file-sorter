import Foundation

public struct BatchOperation: Codable, Equatable {
    public let originalPath: String
    public let newPath: String
    public let isTrashed: Bool
    public let fileSize: Int64
    
    public init(originalPath: String, newPath: String, isTrashed: Bool = false, fileSize: Int64 = 0) {
        self.originalPath = originalPath
        self.newPath = newPath
        self.isTrashed = isTrashed
        self.fileSize = fileSize
    }
}

public struct BatchRecord: Codable, Identifiable, Equatable {
    public var id: UUID
    public var timestamp: Date
    public var operations: [BatchOperation]
    public var createdDirs: [String]
    public var profileName: String?
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), operations: [BatchOperation] = [], createdDirs: [String] = [], profileName: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.operations = operations
        self.createdDirs = createdDirs
        self.profileName = profileName
    }
}

/// Менеджер історії для збереження партій сортування та підтримки Undo
public class HistoryManager: ObservableObject {
    
    public static let shared = HistoryManager()
    
    @Published private var batches: [BatchRecord] = []
    
    public var historyDirectoryURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SmartSorter")
    }
    
    public var historyFileURL: URL {
        return historyDirectoryURL.appendingPathComponent("history.json")
    }
    
    public init() {
        loadHistory()
    }
    
    /// Завантаження історії сортування
    public func loadHistory() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: historyFileURL.path) {
            self.batches = []
            return
        }
        do {
            let data = try Data(contentsOf: historyFileURL)
            self.batches = try JSONDecoder().decode([BatchRecord].self, from: data)
            print("[HISTORY] Завантажено \(batches.count) партій історії")
        } catch {
            print("[HISTORY] Помилка завантаження історії: \(error.localizedDescription)")
            self.batches = []
        }
    }
    
    /// Збереження історії сортування з лімітом в 50 партій
    public func saveHistory() {
        let fileManager = FileManager.default
        do {
            if !fileManager.fileExists(atPath: historyDirectoryURL.path) {
                try fileManager.createDirectory(at: historyDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            if batches.count > 50 {
                batches = Array(batches.suffix(50))
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(batches)
            try data.write(to: historyFileURL, options: .atomic)
            print("[HISTORY] Історію збережено у history.json")
        } catch {
            print("[HISTORY] Помилка збереження історії: \(error.localizedDescription)")
        }
    }
    
    /// Додати нову партію сортування в історію
    public func addBatch(_ batch: BatchRecord) {
        batches.append(batch)
        saveHistory()
    }
    
    /// Отримати список партій
    public func getBatches() -> [BatchRecord] {
        return batches
    }
    
    /// Очищення всієї історії
    public func clearAllHistory() {
        batches.removeAll()
        saveHistory()
    }
    
    /// Перевірка чи є записи в історії
    public func checkHistoryExists() -> Bool {
        return !batches.isEmpty
    }
    
    /// Безпечне перенесення об'єкта до Смітника (Trash)
    public func trashItem(at url: URL) -> URL? {
        let fileManager = FileManager.default
        do {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
            if let resultPath = resultingURL?.path {
                print("[HISTORY] Успішно перенесено у Смітник: \(url.lastPathComponent) -> \(resultPath)")
                return resultingURL as URL?
            }
            return nil
        } catch {
            print("[HISTORY] Помилка видалення в Смітник для \(url.path): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Скасування останньої партії сортування (Undo)
    public func undoLastBatch() -> Bool {
        guard !batches.isEmpty else {
            print("[HISTORY] Немає партій для скасування")
            return false
        }
        
        let fileManager = FileManager.default
        let lastBatch = batches.removeLast()
        
        print("[HISTORY] Скасування партії \(lastBatch.id) від \(lastBatch.timestamp)...")
        
        // Відновлюємо файли з кінця черги
        for op in lastBatch.operations.reversed() {
            let currentURL = URL(fileURLWithPath: op.newPath)
            let originalURL = URL(fileURLWithPath: op.originalPath)
            
            if fileManager.fileExists(atPath: currentURL.path) {
                do {
                    let parentDir = originalURL.deletingLastPathComponent()
                    if !fileManager.fileExists(atPath: parentDir.path) {
                        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
                    }
                    try fileManager.moveItem(at: currentURL, to: originalURL)
                    print("[HISTORY] Скасовано: '\(currentURL.lastPathComponent)' -> '\(originalURL.path)'")
                } catch {
                    print("[HISTORY] Помилка відновлення файлу \(currentURL.path): \(error.localizedDescription)")
                }
            } else {
                print("[HISTORY] Файл відсутній для скасування: \(currentURL.path)")
            }
        }
        
        // Видаляємо створені порожні директорії
        for dirPath in lastBatch.createdDirs.reversed() {
            let dirURL = URL(fileURLWithPath: dirPath)
            if fileManager.fileExists(atPath: dirURL.path) {
                if let contents = try? fileManager.contentsOfDirectory(atPath: dirURL.path), contents.isEmpty {
                    try? fileManager.removeItem(at: dirURL)
                    print("[HISTORY] Видалено порожню створену папку: \(dirPath)")
                }
            }
        }
        
        saveHistory()
        return true
    }
}
