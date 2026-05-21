import Foundation
import SQLite3
@testable import SmartFileSorter

@main
@MainActor
struct Benchmark {
    static func main() async {
        print("=== SMART FILE SORTER PERFORMANCE BENCHMARK ===")
        
        let fileManager = FileManager.default
        
        // 1. Create a temporary folder for benchmark files
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let benchmarkDir = currentDir.appendingPathComponent("HashCacheBenchmark_\(UUID().uuidString)")
        try! fileManager.createDirectory(at: benchmarkDir, withIntermediateDirectories: true)
        
        print("Generating test files...")
        let distinctCount = 50
        let duplicatesPerFile = 6
        let totalFiles = distinctCount * duplicatesPerFile
        let fileSizeInBytes = 250 * 1024 // 250 KB
        
        // Generate distinct random data buffers
        var fileData: [Data] = []
        for _ in 0..<distinctCount {
            var data = Data(count: fileSizeInBytes)
            _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, fileSizeInBytes, $0.baseAddress!) }
            fileData.append(data)
        }
        
        // Write duplicate files
        for i in 0..<distinctCount {
            let data = fileData[i]
            for j in 0..<duplicatesPerFile {
                let fileURL = benchmarkDir.appendingPathComponent("file_\(i)_dup_\(j).bin")
                try! data.write(to: fileURL)
            }
        }
        
        // Calculate total size of the folder
        var folderSize: Int64 = 0
        let contents = try! fileManager.contentsOfDirectory(at: benchmarkDir, includingPropertiesForKeys: [.fileSizeKey], options: [])
        for file in contents {
            let attrs = try! fileManager.attributesOfItem(atPath: file.path)
            folderSize += attrs[.size] as! Int64
        }
        
        let folderSizeMB = Double(folderSize) / (1024 * 1024)
        print("Generated \(totalFiles) files. Total folder size: \(String(format: "%.2f", folderSizeMB)) MB")
        
        // 2. Setup DuplicateFinder
        let finder = DuplicateFinder()
        
        // 3. COLD RUN (Clear cache first)
        print("\nClearing cache...")
        await HashCache.shared.clear()
        
        print("Starting Cold Scan...")
        let coldStart = Date()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            finder.scan(at: benchmarkDir.path) {
                continuation.resume()
            }
        }
        
        let coldDuration = Date().timeIntervalSince(coldStart)
        print("Cold Scan completed in \(String(format: "%.4f", coldDuration)) seconds.")
        XCTAssertEqual(finder.duplicatesCount, (duplicatesPerFile - 1) * distinctCount)
        
        // 4. WARM RUN (Use populated cache)
        print("\nStarting Warm Scan...")
        let warmStart = Date()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            finder.scan(at: benchmarkDir.path) {
                continuation.resume()
            }
        }
        
        let warmDuration = Date().timeIntervalSince(warmStart)
        print("Warm Scan completed in \(String(format: "%.4f", warmDuration)) seconds.")
        
        // 5. Calculations
        let improvement = ((coldDuration - warmDuration) / coldDuration) * 100
        print("\nSpeed improvement: \(String(format: "%.2f", improvement))%")
        
        // Get DB path and size
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbURL = appSupport.appendingPathComponent("SmartFileSorter/hash_cache.db")
        var dbSizeStr = "Unknown"
        if fileManager.fileExists(atPath: dbURL.path) {
            let dbAttrs = try! fileManager.attributesOfItem(atPath: dbURL.path)
            let dbSizeBytes = dbAttrs[.size] as! Int64
            dbSizeStr = "\(Double(dbSizeBytes) / 1024.0) KB"
        }
        print("hash_cache.db size: \(dbSizeStr) (Path: \(dbURL.path))")
        
        // Clean up temporary files
        try! fileManager.removeItem(at: benchmarkDir)
        print("\nBenchmark completed and temporary files cleaned up.")
    }
}
