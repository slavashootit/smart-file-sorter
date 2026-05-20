import Foundation
import CoreML
import Vision
import NaturalLanguage
import SQLite3

public class SemanticSearchEngine: ObservableObject {
    public static let shared = SemanticSearchEngine()
    
    @Published public var downloadProgress: Double = 0.0
    @Published public var isDownloading = false
    @Published public var isModelLoaded = true  // Always ready — uses built-in Vision
    
    private var db: OpaquePointer?
    
    private init() {
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDirURL = appSupportURL.appendingPathComponent("com.slavashootit.smart-file-sorter")
            try? fileManager.createDirectory(at: appDirURL, withIntermediateDirectories: true)
            let dbURL = appDirURL.appendingPathComponent("embeddings.sqlite")
            
            if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
                let query = """
                CREATE TABLE IF NOT EXISTS embeddings (
                    path TEXT PRIMARY KEY,
                    vector BLOB,
                    labels TEXT,
                    timestamp REAL
                );
                """
                var statement: OpaquePointer?
                if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_step(statement)
                }
                sqlite3_finalize(statement)
                
                // Add labels column if migrating from old schema
                let alterQuery = "ALTER TABLE embeddings ADD COLUMN labels TEXT;"
                var alterStmt: OpaquePointer?
                sqlite3_prepare_v2(db, alterQuery, -1, &alterStmt, nil)
                sqlite3_step(alterStmt)
                sqlite3_finalize(alterStmt)
            }
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    public func startDownload() {
        // No download needed — Vision framework is built-in
        isModelLoaded = true
    }
    
    // MARK: - Vision Classification Labels (Synchronous)
    
    /// Classify an image synchronously and return top labels.
    /// Safe to call from any background thread.
    public func classifyImageSync(at url: URL) -> [String] {
        // Check DB cache first
        if let cached = getCachedLabels(for: url) {
            return cached
        }
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, [
                kCGImageSourceShouldCache: false
              ] as CFDictionary) else {
            return []
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNClassifyImageRequest()
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("[SemanticSearch] Vision classify error: \(error.localizedDescription)")
            return []
        }
        
        guard let observations = request.results as? [VNClassificationObservation] else {
            return []
        }
        
        // Take top labels with confidence > 0.25
        let topLabels = observations
            .filter { $0.confidence > 0.25 }
            .prefix(15)
            .map { $0.identifier.lowercased() }
        
        let labels = Array(topLabels)
        saveCachedLabels(for: url, labels: labels)
        return labels
    }
    
    // MARK: - Text-based Search (Label Matching)
    
    /// Match query text against Vision classification labels.
    public func searchByText(query: String, in labels: [String]) -> Float {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let queryWords = queryLower.split(separator: " ").map(String.init)
        
        var matchScore: Float = 0.0
        
        for label in labels {
            // Split multi-word labels (e.g. "human_face" -> ["human", "face"])
            let labelParts = label.split(whereSeparator: { $0 == "_" || $0 == "-" || $0 == " " }).map(String.init)
            
            for word in queryWords {
                // Direct label match
                if label.contains(word) || word.contains(label) {
                    matchScore += 1.0
                    continue
                }
                // Match against label parts
                for part in labelParts {
                    if part.contains(word) || word.contains(part) {
                        matchScore += 0.8
                        break
                    }
                }
            }
        }
        
        // Normalize by query word count
        if !queryWords.isEmpty {
            matchScore = matchScore / Float(queryWords.count)
        }
        
        return min(matchScore, 1.0)
    }
    
    // MARK: - Embedding Cache (SQLite)
    
    public func saveEmbedding(for url: URL, vector: [Float]) {
        let path = url.path
        let query = "INSERT OR REPLACE INTO embeddings (path, vector, timestamp) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (path as NSString).utf8String, -1, nil)
            
            let data = Data(bytes: vector, count: vector.count * MemoryLayout<Float>.size)
            _ = data.withUnsafeBytes { rawBuffer in
                sqlite3_bind_blob(statement, 2, rawBuffer.baseAddress, Int32(data.count), nil)
            }
            
            sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("[Embeddings DB] Error inserting vector")
            }
        }
        sqlite3_finalize(statement)
    }
    
    public func getEmbedding(for url: URL) -> [Float]? {
        let path = url.path
        let query = "SELECT vector FROM embeddings WHERE path = ?;"
        var statement: OpaquePointer?
        var vector: [Float]? = nil
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (path as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                if let blob = sqlite3_column_blob(statement, 0) {
                    let byteCount = Int(sqlite3_column_bytes(statement, 0))
                    let floatCount = byteCount / MemoryLayout<Float>.size
                    let pointer = blob.assumingMemoryBound(to: Float.self)
                    let buffer = UnsafeBufferPointer(start: pointer, count: floatCount)
                    vector = Array(buffer)
                }
            }
        }
        sqlite3_finalize(statement)
        return vector
    }
    
    // MARK: - Label Cache (SQLite)
    
    private func saveCachedLabels(for url: URL, labels: [String]) {
        let path = url.path
        let labelsStr = labels.joined(separator: ",")
        let query = "INSERT OR REPLACE INTO embeddings (path, labels, timestamp) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (path as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (labelsStr as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    public func getCachedLabels(for url: URL) -> [String]? {
        let path = url.path
        let query = "SELECT labels FROM embeddings WHERE path = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (path as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                if let cStr = sqlite3_column_text(statement, 0) {
                    let labelsStr = String(cString: cStr)
                    let labels = labelsStr.split(separator: ",").map(String.init)
                    sqlite3_finalize(statement)
                    return labels.isEmpty ? nil : labels
                }
            }
        }
        sqlite3_finalize(statement)
        return nil
    }
    
    // Legacy compatibility
    public func cosineSimilarity(_ v1: [Float], _ v2: [Float]) -> Float {
        guard v1.count == v2.count, !v1.isEmpty else { return 0.0 }
        var dotProduct: Float = 0.0
        var magnitude1: Float = 0.0
        var magnitude2: Float = 0.0
        for i in 0..<v1.count {
            dotProduct += v1[i] * v2[i]
            magnitude1 += v1[i] * v1[i]
            magnitude2 += v2[i] * v2[i]
        }
        guard magnitude1 > 0, magnitude2 > 0 else { return 0.0 }
        return dotProduct / (sqrt(magnitude1) * sqrt(magnitude2))
    }
    
    public func textEmbedding(for query: String) -> [Float] {
        return [Float](repeating: 0, count: 512)
    }
    
    public func imageEmbedding(for url: URL, completion: @escaping ([Float]?) -> Void) {
        if let cached = getEmbedding(for: url) {
            completion(cached)
            return
        }
        
        let requestHandler = VNImageRequestHandler(url: url, options: [:])
        let request = VNGenerateImageFeaturePrintRequest { request, error in
            guard let observation = request.results?.first as? VNFeaturePrintObservation, error == nil else {
                completion(nil)
                return
            }
            
            let data = observation.data
            let floatCount = data.count / MemoryLayout<Float>.size
            var vector = [Float](repeating: 0, count: floatCount)
            _ = vector.withUnsafeMutableBytes { data.copyBytes(to: $0) }
            
            var finalVector = [Float](repeating: 0, count: 512)
            for i in 0..<min(vector.count, 512) {
                finalVector[i] = vector[i]
            }
            
            self.saveEmbedding(for: url, vector: finalVector)
            completion(finalVector)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            try? requestHandler.perform([request])
        }
    }
}
