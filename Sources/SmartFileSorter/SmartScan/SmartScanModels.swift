import Foundation

enum SmartScanState {
    case scanning
    case results
    case confirmingFixAll
}

// Категорії за пріоритетом відображення
enum ScanIssueCategory: Int, Comparable, CaseIterable {
    case cleanup = 0      // зелений — безпечно
    case duplicate = 1    // жовтий — потребує уваги
    case similarPhoto = 2 // оранжевий — потрібне рішення

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct ScanIssue: Identifiable, Hashable {
    let id: UUID
    let category: ScanIssueCategory
    let displayName: String        // "backup_2024.zip · ×2"
    let detail: String             // шлях або опис
    let urls: [URL]                // всі файли які будуть переміщені
    let bytes: Int64
    var isSelected: Bool           // false за замовчуванням для .similarPhoto
    let reason: String

    public static func determineReason(category: ScanIssueCategory, url: URL, originalFile: URL? = nil, clusterSize: Int? = nil) -> String {
        switch category {
        case .cleanup:
            let fm = FileManager.default
            let path = url.path
            let attr = try? fm.attributesOfItem(atPath: path)
            
            if path.contains("/.Trash/") || path.hasSuffix("/.Trash") {
                let modDate = attr?[.modificationDate] as? Date ?? Date()
                let days = Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? 0
                return "У Кошику · \(days) дн."
            } else if path.contains("/Library/Caches/") || path.contains("/Library/Logs/") || url.pathExtension.lowercased() == "log" || url.pathExtension.lowercased() == "tmp" || path.contains("/Caches/") {
                let size = attr?[.size] as? Int64 ?? 0
                let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                return "Кеш · \(sizeStr)"
            } else if path.contains("/Downloads/") {
                var accessDate = Date()
                if let resourceValues = try? url.resourceValues(forKeys: [.contentAccessDateKey]),
                   let date = resourceValues.contentAccessDate {
                    accessDate = date
                } else if let modDate = attr?[.modificationDate] as? Date {
                    accessDate = modDate
                }
                let months = Calendar.current.dateComponents([.month], from: accessDate, to: Date()).month ?? 0
                return "Downloads · не відкривався \(months) міс."
            } else {
                // Default fallback for other cleanup files (like .DS_Store outside standard dirs)
                let size = attr?[.size] as? Int64 ?? 0
                let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                return "Кеш · \(sizeStr)"
            }
        case .duplicate:
            if let originalFile = originalFile {
                return "Дублікат файлу \(originalFile.lastPathComponent)"
            }
            return "Дублікат файлу"
        case .similarPhoto:
            if let clusterSize = clusterSize {
                return "Схоже на \(clusterSize - 1) фото в кластері"
            }
            return "Схоже фото"
        }
    }
}

struct ScanResults: Equatable {
    let issues: [ScanIssue]        // вже відсортовані за category
    let scannedPath: URL
    let scannedAt: Date

    var totalBytes: Int64 { issues.filter(\.isSelected).reduce(0) { $0 + $1.bytes } }
    var issueCount: Int { issues.count }
    var isEmpty: Bool { issues.isEmpty }

    // Згруповані для UI
    var grouped: [(category: ScanIssueCategory, items: [ScanIssue])] {
        Dictionary(grouping: issues, by: \.category)
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }
    
    static func == (lhs: ScanResults, rhs: ScanResults) -> Bool {
        lhs.scannedAt == rhs.scannedAt && lhs.scannedPath == rhs.scannedPath && lhs.issues == rhs.issues
    }
}

struct ScanProgress {
    enum StepState { case waiting, running, done(summary: String) }

    var cleanup:  StepState = .waiting
    var duplicates: StepState = .waiting
    var similarPhotos: StepState = .waiting
    var overallFraction: Double = 0.0  // 0.0 → 1.0
    var currentPath: String = ""
}
