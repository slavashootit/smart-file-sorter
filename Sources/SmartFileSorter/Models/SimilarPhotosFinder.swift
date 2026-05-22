import Foundation
import Vision
import AppKit

public struct SimilarPhotoGroup: Identifiable, Equatable {
    public let id: UUID
    public var photos: [URL]
    
    public init(id: UUID = UUID(), photos: [URL]) {
        self.id = id
        self.photos = photos
    }
}

public final class SimilarPhotosFinder: ObservableObject {
    @Published public var isScanning = false
    @Published public var progress: Double = 0.0
    @Published public var currentFile: String = ""
    @Published public var similarGroups: [SimilarPhotoGroup] = []
    @Published public var scannedCount = 0
    
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
    
    public func scan(at path: String, threshold: Float = 0.15, completion: @escaping () -> Void) {
        isCancelled = false
        DispatchQueue.main.async {
            self.isScanning = true
            self.progress = 0.0
            self.currentFile = "Пошук зображень..."
            self.similarGroups = []
            self.scannedCount = 0
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let rootURL = URL(fileURLWithPath: path)
            var imageURLs: [URL] = []
            
            let allowedExtensions = Set(["jpg", "jpeg", "png", "heic"])
            
            let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            while let fileURL = enumerator?.nextObject() as? URL {
                if self.isCancelled { break }
                
                let ext = fileURL.pathExtension.lowercased()
                if allowedExtensions.contains(ext) {
                    imageURLs.append(fileURL)
                }
            }
            
            if self.isCancelled || imageURLs.isEmpty {
                DispatchQueue.main.async {
                    self.isScanning = false
                    completion()
                }
                return
            }
            
            let totalImages = imageURLs.count
            var featurePrints: [(url: URL, print: VNFeaturePrintObservation)] = []
            let lock = NSLock()
            var processedCount = 0
            
            let group = DispatchGroup()
            
            for url in imageURLs {
                if self.isCancelled { break }
                
                let operation = BlockOperation {
                    if self.isCancelled { return }
                    
                    let requestHandler = VNImageRequestHandler(url: url, options: [:])
                    let request = VNGenerateImageFeaturePrintRequest()
                    
                    do {
                        try requestHandler.perform([request])
                        if let observation = request.results?.first as? VNFeaturePrintObservation {
                            lock.lock()
                            featurePrints.append((url: url, print: observation))
                            processedCount += 1
                            let currentProgress = (Double(processedCount) / Double(totalImages)) * 0.7
                            let filename = url.lastPathComponent
                            DispatchQueue.main.async {
                                self.progress = currentProgress
                                self.currentFile = "Аналіз Vision AI: \(filename)"
                            }
                            lock.unlock()
                        }
                    } catch {
                        // Пропускаємо файли, які неможливо розпарсити Vision
                        lock.lock()
                        processedCount += 1
                        lock.unlock()
                    }
                }
                
                group.enter()
                operation.completionBlock = {
                    group.leave()
                }
                self.queue.addOperation(operation)
            }
            
            group.wait()
            
            if self.isCancelled || featurePrints.isEmpty {
                DispatchQueue.main.async {
                    self.isScanning = false
                    completion()
                }
                return
            }
            
            // 5. Групування за схожістю (Порівняння векторів)
            DispatchQueue.main.async {
                self.currentFile = "Групування схожих фото..."
                self.progress = 0.8
            }
            
            var groups: [SimilarPhotoGroup] = []
            var visited = Set<URL>()
            
            for i in 0..<featurePrints.count {
                if self.isCancelled { break }
                
                let current = featurePrints[i]
                if visited.contains(current.url) { continue }
                
                var groupPhotos = [current.url]
                
                for j in (i+1)..<featurePrints.count {
                    let other = featurePrints[j]
                    if visited.contains(other.url) { continue }
                    
                    var distance: Float = 2.0
                    do {
                        try current.print.computeDistance(&distance, to: other.print)
                        // Менша відстань = більша схожість
                        if distance <= threshold {
                            groupPhotos.append(other.url)
                        }
                    } catch {
                        print("[VISION] Помилка обчислення відстані: \(error.localizedDescription)")
                    }
                }
                
                if groupPhotos.count > 1 {
                    for url in groupPhotos {
                        visited.insert(url)
                    }
                    groups.append(SimilarPhotoGroup(photos: groupPhotos))
                }
                
                let groupProgress = 0.8 + (Double(i) / Double(featurePrints.count)) * 0.2
                DispatchQueue.main.async {
                    self.progress = groupProgress
                }
            }
            
            DispatchQueue.main.async {
                self.similarGroups = groups
                self.scannedCount = imageURLs.count
                self.progress = 1.0
                self.isScanning = false
                completion()
            }
        }
    }
}

public struct SimilarPhotosCluster: Sendable {
    public let label: String
    public let photos: [URL]
    public let minSimilarity: Double
    
    public init(label: String, photos: [URL], minSimilarity: Double) {
        self.label = label
        self.photos = photos
        self.minSimilarity = minSimilarity
    }
}

public final class SimilarPhotosEngine: @unchecked Sendable {
    public init() {}
    
    public func findClusters(in url: URL) async -> [SimilarPhotosCluster] {
        let finder = SimilarPhotosFinder()
        return await withCheckedContinuation { continuation in
            finder.scan(at: url.path, threshold: 0.15) {
                let clusters = finder.similarGroups.enumerated().map { (index, group) in
                    SimilarPhotosCluster(
                        label: "Група \(index + 1)",
                        photos: group.photos,
                        minSimilarity: 0.85
                    )
                }
                continuation.resume(returning: clusters)
            }
        }
    }
}

