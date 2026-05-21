import Foundation
import CryptoKit

public struct DuplicateGroup: Identifiable, Equatable {
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

public final class DuplicateFinder: ObservableObject {
    @Published public var isScanning = false
    @Published public var progress: Double = 0.0
    @Published public var currentFile: String = ""
    @Published public var duplicateGroups: [DuplicateGroup] = []
    @Published public var scannedCount = 0
    @Published public var duplicatesCount = 0
    @Published public var potentialSavings: Int64 = 0
    
    private var isCancelled = false
    private let queue = OperationQueue()
    
    public init() {
        queue.maxConcurrentOperationCount = ProcessInfo.processInfo.activeProcessorCount
    }
    
    public func cancelScan() {
        isCancelled = true
        queue.cancelAllOperations()
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
        
        DispatchQueue.global(qos: .userInitiated).async {
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
            let lock = NSLock()
            var pass1Candidates: [URL] = []
            for (_, files) in sizeCandidates {
                pass1Candidates.append(contentsOf: files)
            }
            
            var pass1Map: [String: [URL]] = [:]
            var completedCount = 0
            
            let pass1Group = DispatchGroup()
            
            for file in pass1Candidates {
                if self.isCancelled { break }
                
                let operation = BlockOperation {
                    if self.isCancelled { return }
                    
                    if let hash1 = self.getPass1Hash(url: file) {
                        let size = (try? fileManager.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                        let key = "\(size)-\(hash1)"
                        
                        lock.lock()
                        pass1Map[key, default: []].append(file)
                        completedCount += 1
                        let currentProgress = (Double(completedCount) / Double(totalCandidatesCount)) * 0.5
                        let filename = file.lastPathComponent
                        DispatchQueue.main.async {
                            self.progress = currentProgress
                            self.currentFile = "[Прохід 1] Аналіз: \(filename)"
                        }
                        lock.unlock()
                    }
                }
                
                pass1Group.enter()
                operation.completionBlock = {
                    pass1Group.leave()
                }
                self.queue.addOperation(operation)
            }
            
            pass1Group.wait()
            
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
            let pass2Group = DispatchGroup()
            
            for (_, files) in pass2CandidatesMap {
                if self.isCancelled { break }
                
                for file in files {
                    if self.isCancelled { break }
                    
                    let operation = BlockOperation {
                        if self.isCancelled { return }
                        
                        if let hash2 = self.getPass2Hash(url: file, useSHA256: useSHA256) {
                            lock.lock()
                            pass2Map[hash2, default: []].append(file)
                            pass2CompletedCount += 1
                            let currentProgress = 0.5 + ((Double(pass2CompletedCount) / Double(totalPass2Count)) * 0.5)
                            let filename = file.lastPathComponent
                            DispatchQueue.main.async {
                                self.progress = currentProgress
                                self.currentFile = "[Прохід 2] Хешування: \(filename)"
                            }
                            lock.unlock()
                        }
                    }
                    
                    pass2Group.enter()
                    operation.completionBlock = {
                        pass2Group.leave()
                    }
                    self.queue.addOperation(operation)
                }
            }
            
            pass2Group.wait()
            
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
                    // Фільтруємо hardlinks: якщо inode однаковий, це не дублікат
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
