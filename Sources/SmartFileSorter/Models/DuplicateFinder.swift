import Foundation
import CryptoKit
import os

public struct DuplicateGroup: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let hash: String
    public let fileSize: Int64
    public var files: [URL]
    
    public init(id: UUID = UUID(), hash: String, fileSize: Int64, files: [URL]) {
        self.id = id
        self.hash = hash
        self.fileSize = fileSize
        self.files = files
    }
}

public final class DuplicateFinder: ObservableObject, @unchecked Sendable {
    public static let shared = DuplicateFinder()
    
    @Published public var isScanning = false
    @Published public var progress: Double = 0.0
    @Published public var currentFile: String = ""
    @Published public var duplicateGroups: [DuplicateGroup] = []
    @Published public var scannedCount = 0
    @Published public var duplicatesCount = 0
    @Published public var potentialSavings: Int64 = 0
    
    private var isCancelled = false
    
    public init() {}
    
    public func cancelScan() {
        isCancelled = true
        DispatchQueue.main.async {
            self.isScanning = false
        }
    }
    
    public func scan(at path: String, useSHA256: Bool = false, completion: @escaping () -> Void) {
        isCancelled = false
        DispatchQueue.main.async {
            self.isScanning = true
            self.progress = 0.0
            self.currentFile = "Підготовка до сканування..."
            self.duplicateGroups = []
            self.scannedCount = 0
            self.duplicatesCount = 0
            self.potentialSavings = 0
        }
        
        Task {
            let fileManager = FileManager.default
            let rootURL = URL(fileURLWithPath: path)
            var allFiles: [URL] = []
            
            // 1. Рекурсивне збирання файлів з урахуванням виключень
            let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
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
                    // Перевіряємо чи це App bundle чи інший пакет
                    let ext = fileURL.pathExtension.lowercased()
                    if ext == "app" || ext == "framework" || ext == "bundle" {
                        enumerator?.skipDescendants()
                    }
                    continue
                }
                
                allFiles.append(fileURL)
            }
            
            if self.isCancelled {
                DispatchQueue.main.async { completion() }
                return
            }
            
            // 2. Групування за розміром (Швидкий пре-фільтр)
            var sizeMap: [Int64: [URL]] = [:]
            for file in allFiles {
                let size = (try? fileManager.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                if size > 0 {
                    sizeMap[size, default: []].append(file)
                }
            }
            
            // Залишаємо тільки ті розміри, де є більше одного файлу
            let sizeCandidates = sizeMap.filter { $0.value.count > 1 }
            let totalCandidatesCount = sizeCandidates.reduce(0) { $0 + $1.value.count }
            
            if totalCandidatesCount == 0 {
                DispatchQueue.main.async {
                    self.isScanning = false
                    completion()
                }
                return
            }
            
            // 3. Перший прохід (Pass 1): Хешування 4KB початку + 4KB кінця
            var pass1Candidates: [URL] = []
            for (_, files) in sizeCandidates {
                pass1Candidates.append(contentsOf: files)
            }
            
            var pass1Map: [String: [URL]] = [:]
            var completedCount = 0
            
            let maxConcurrentTasks = ProcessInfo.processInfo.activeProcessorCount
            
            await withTaskGroup(of: (String, URL)?.self) { group in
                var activeTasks = 0
                for file in pass1Candidates {
                    if self.isCancelled { break }
                    
                    if activeTasks >= maxConcurrentTasks {
                        if let result = await group.next() {
                            if let (key, fileURL) = result {
                                pass1Map[key, default: []].append(fileURL)
                                completedCount += 1
                                let currentProgress = (Double(completedCount) / Double(totalCandidatesCount)) * 0.5
                                let filename = fileURL.lastPathComponent
                                DispatchQueue.main.async {
                                    self.progress = currentProgress
                                    self.currentFile = "[Прохід 1] Аналіз: \(filename)"
                                }
                            }
                        }
                        activeTasks -= 1
                    }
                    
                    activeTasks += 1
                    group.addTask {
                        if self.isCancelled { return nil }
                        
                        let size = (try? fileManager.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                        let mtime = ((try? fileManager.attributesOfItem(atPath: file.path)[.modificationDate] as? Date)?.timeIntervalSince1970) ?? 0
                        
                        var hash1: String? = nil
                        if let hashes = await HashCache.shared.getHashes(for: file, size: size, mtime: mtime) {
                            hash1 = hashes.pass1
                        }
                        
                        if hash1 == nil {
                            if let calculated = self.getPass1Hash(url: file) {
                                hash1 = calculated
                                await HashCache.shared.store(url: file, size: size, mtime: mtime, pass1: calculated, pass2: nil)
                            }
                        }
                        
                        if let finalHash1 = hash1 {
                            let key = "\(size)-\(finalHash1)"
                            return (key, file)
                        }
                        return nil
                    }
                }
                
                while activeTasks > 0 {
                    if let result = await group.next() {
                        if let (key, fileURL) = result {
                            pass1Map[key, default: []].append(fileURL)
                            completedCount += 1
                            let currentProgress = (Double(completedCount) / Double(totalCandidatesCount)) * 0.5
                            let filename = fileURL.lastPathComponent
                            DispatchQueue.main.async {
                                self.progress = currentProgress
                                self.currentFile = "[Прохід 1] Аналіз: \(filename)"
                            }
                        }
                    }
                    activeTasks -= 1
                }
            }
            
            if self.isCancelled {
                DispatchQueue.main.async { completion() }
                return
            }
            
            // Фільтруємо унікальні Pass 1 хеші
            let pass2CandidatesMap = pass1Map.filter { $0.value.count > 1 }
            let totalPass2Count = pass2CandidatesMap.reduce(0) { $0 + $1.value.count }
            
            if totalPass2Count == 0 {
                DispatchQueue.main.async {
                    self.isScanning = false
                    completion()
                }
                return
            }
            
            // 4. Другий прохід (Pass 2): Повний потоковий хеш
            var pass2Map: [String: [URL]] = [:]
            var pass2CompletedCount = 0
            
            await withTaskGroup(of: (String, URL)?.self) { group in
                var activeTasks = 0
                for (key, files) in pass2CandidatesMap {
                    if self.isCancelled { break }
                    
                    let components = key.components(separatedBy: "-")
                    let pass1Hash = components.dropFirst().joined(separator: "-")
                    
                    for file in files {
                        if self.isCancelled { break }
                        
                        if activeTasks >= maxConcurrentTasks {
                            if let result = await group.next() {
                                if let (finalHash2, fileURL) = result {
                                    pass2Map[finalHash2, default: []].append(fileURL)
                                    pass2CompletedCount += 1
                                    let currentProgress = 0.5 + ((Double(pass2CompletedCount) / Double(totalPass2Count)) * 0.5)
                                    let filename = fileURL.lastPathComponent
                                    DispatchQueue.main.async {
                                        self.progress = currentProgress
                                        self.currentFile = "[Прохід 2] Хешування: \(filename)"
                                    }
                                }
                            }
                            activeTasks -= 1
                        }
                        
                        activeTasks += 1
                        group.addTask {
                            if self.isCancelled { return nil }
                            
                            let size = (try? fileManager.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                            let mtime = ((try? fileManager.attributesOfItem(atPath: file.path)[.modificationDate] as? Date)?.timeIntervalSince1970) ?? 0
                            
                            var hash2: String? = nil
                            if let hashes = await HashCache.shared.getHashes(for: file, size: size, mtime: mtime) {
                                hash2 = hashes.pass2
                            }
                            
                            if hash2 == nil {
                                if let calculated = self.getPass2Hash(url: file, useSHA256: useSHA256) {
                                    hash2 = calculated
                                    // Only cache in SQLite if we are NOT using SHA-256
                                    if !useSHA256 {
                                        await HashCache.shared.store(url: file, size: size, mtime: mtime, pass1: pass1Hash, pass2: calculated)
                                    }
                                }
                            }
                            
                            if let finalHash2 = hash2 {
                                return (finalHash2, file)
                            }
                            return nil
                        }
                    }
                }
                
                while activeTasks > 0 {
                    if let result = await group.next() {
                        if let (finalHash2, fileURL) = result {
                            pass2Map[finalHash2, default: []].append(fileURL)
                            pass2CompletedCount += 1
                            let currentProgress = 0.5 + ((Double(pass2CompletedCount) / Double(totalPass2Count)) * 0.5)
                            let filename = fileURL.lastPathComponent
                            DispatchQueue.main.async {
                                self.progress = currentProgress
                                self.currentFile = "[Прохід 2] Хешування: \(filename)"
                            }
                        }
                    }
                    activeTasks -= 1
                }
            }
            
            if self.isCancelled {
                DispatchQueue.main.async { completion() }
                return
            }
            
            // 5. Виявлення hardlinks та формування фінальних груп
            var finalGroups: [DuplicateGroup] = []
            var foundDuplicates = 0
            var savings: Int64 = 0
            
            for (hash, files) in pass2Map {
                if files.count > 1 {
                    // Фільтруємо hardlinks: якщо inode開放однаковий, це не дублікат
                    var uniqueInodes = Set<String>()
                    var filteredFiles: [URL] = []
                    
                    for file in files {
                        if let inode = self.fileInode(at: file) {
                            let key = "\(inode.dev)-\(inode.ino)"
                            if !uniqueInodes.contains(key) {
                                uniqueInodes.insert(key)
                                filteredFiles.append(file)
                            }
                        } else {
                            filteredFiles.append(file)
                        }
                    }
                    
                    if filteredFiles.count > 1 {
                        let size = (try? fileManager.attributesOfItem(atPath: filteredFiles[0].path)[.size] as? Int64) ?? 0
                        let group = DuplicateGroup(hash: hash, fileSize: size, files: filteredFiles)
                        finalGroups.append(group)
                        
                        foundDuplicates += (filteredFiles.count - 1)
                        savings += (size * Int64(filteredFiles.count - 1))
                    }
                }
            }
            
            let sortedGroups = finalGroups.sorted { $0.fileSize * Int64($0.files.count) > $1.fileSize * Int64($1.files.count) }
            
            DispatchQueue.main.async {
                self.duplicateGroups = sortedGroups
                self.duplicatesCount = foundDuplicates
                self.potentialSavings = savings
                self.scannedCount = allFiles.count
                self.progress = 1.0
                self.isScanning = false
                completion()
            }
        }
    }
    
    private func getPass1Hash(url: URL) -> String? {
        return XXHash64.getPass1Hash(url: url)
    }
    
    private func getPass2Hash(url: URL, useSHA256: Bool) -> String? {
        if useSHA256 {
            guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? fileHandle.close() }
            let chunkSize = 65536
            var shaHasher = SHA256()
            while let chunk = try? fileHandle.read(upToCount: chunkSize), !chunk.isEmpty {
                if self.isCancelled { return nil }
                shaHasher.update(data: chunk)
            }
            let digest = shaHasher.finalize()
            return digest.map { String(format: "%02hhx", $0) }.joined()
        } else {
            return XXHash64.getPass2Hash(url: url, checkCancellation: { self.isCancelled })
        }
    }
    
    private func fileInode(at url: URL) -> (dev: dev_t, ino: ino_t)? {
        var fileStat = stat()
        if stat(url.path, &fileStat) == 0 {
            return (fileStat.st_dev, fileStat.st_ino)
        }
        return nil
    }
    
    private func shouldExclude(path: String) -> Bool {
        return ConfigManager.shared.shouldExclude(url: URL(fileURLWithPath: path))
    }
}

extension DuplicateFinder {
    public func findDuplicates(in url: URL) async -> [DuplicateGroup] {
        await withCheckedContinuation { continuation in
            self.scan(at: url.path) {
                continuation.resume(returning: self.duplicateGroups)
            }
        }
    }
}

