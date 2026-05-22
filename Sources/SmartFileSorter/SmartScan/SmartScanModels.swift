import Foundation

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
