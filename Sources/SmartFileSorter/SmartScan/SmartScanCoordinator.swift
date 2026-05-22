import Foundation
import Combine

@MainActor
final class SmartScanCoordinator: ObservableObject {
    public static let shared = SmartScanCoordinator()

    @Published var progress = ScanProgress()
    @Published var results: ScanResults?
    @Published var viewState: SmartScanState = .scanning

    private var scanTask: Task<Void, Never>?

    // TTL: якщо scan був менш ніж 5 хв тому — повертає кеш
    private var lastScanDate: Date?
    private let cacheTTL: TimeInterval = 300

    public init() {}

    func startScan(at url: URL) {
        if let last = lastScanDate, Date().timeIntervalSince(last) < cacheTTL, results != nil, results?.scannedPath == url {
            if viewState == .scanning {
                viewState = .results
            }
            return
        }
        viewState = .scanning
        results = nil
        progress = ScanProgress()
        scanTask?.cancel()
        scanTask = Task { await runScan(at: url) }
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
    }

    private func runScan(at url: URL) async {
        // Три кроки паралельно через TaskGroup
        let allIssues = await withTaskGroup(of: [ScanIssue].self) { group in
            group.addTask { await self.runCleanup(at: url) }
            group.addTask { await self.runDuplicates(at: url) }
            group.addTask { await self.runSimilarPhotos(at: url) }

            var collected: [ScanIssue] = []
            for await issues in group {
                collected.append(contentsOf: issues)
            }
            return collected
        }

        guard !Task.isCancelled else { return }

        let sorted = allIssues.sorted { $0.category < $1.category }
        self.results = ScanResults(issues: sorted, scannedPath: url, scannedAt: .now)
        self.lastScanDate = .now
        self.progress.overallFraction = 1.0
        self.viewState = .results
    }

    // ── Cleanup ──────────────────────────────────────────────
    private func runCleanup(at url: URL) async -> [ScanIssue] {
        await MainActor.run { self.progress.cleanup = .running }

        // Шукаємо: .DS_Store, *.tmp, Thumbs.db
        let patterns = [".DS_Store", "*.tmp", "Thumbs.db"]
        var found: [URL] = []
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]) else {
            return []
        }
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            let name = fileURL.lastPathComponent
            if patterns.contains(where: { name == $0 || name.hasSuffix($0.replacingOccurrences(of: "*", with: "")) }) {
                found.append(fileURL)
            }
        }

        let totalBytes = found.reduce(Int64(0)) { acc, u in
            let size = (try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return acc + Int64(size)
        }

        let issues: [ScanIssue] = found.isEmpty ? [] : [
            ScanIssue(
                id: UUID(),
                category: .cleanup,
                displayName: "Тимчасові файли (\(found.count))",
                detail: "Знайдено в \(url.lastPathComponent)",
                urls: found,
                bytes: totalBytes,
                isSelected: true
            )
        ]

        let summary = found.isEmpty ? "Чисто" : "\(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))"
        await MainActor.run { self.progress.cleanup = .done(summary: summary) }
        return issues
    }

    // ── Duplicates ────────────────────────────────────────────
    private func runDuplicates(at url: URL) async -> [ScanIssue] {
        await MainActor.run { self.progress.duplicates = .running }

        // Делегуємо існуючому DuplicateFinder
        let finder = DuplicateFinder()
        let groups = await finder.findDuplicates(in: url)

        var issues: [ScanIssue] = []
        for group in groups {
            guard group.files.count > 1 else { continue }
            let keeper = group.files.first!
            let toDelete = Array(group.files.dropFirst())
            let bytes = toDelete.reduce(Int64(0)) { acc, u in
                let size = (try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return acc + Int64(size)
            }
            issues.append(ScanIssue(
                id: UUID(),
                category: .duplicate,
                displayName: "\(keeper.lastPathComponent) · ×\(group.files.count)",
                detail: "Залишаємо: \(keeper.lastPathComponent)",
                urls: toDelete,
                bytes: bytes,
                isSelected: true
            ))
        }

        let totalBytes = issues.reduce(Int64(0)) { $0 + $1.bytes }
        let summary = issues.isEmpty ? "Дублікатів немає" :
            "\(issues.count) груп · \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))"
        await MainActor.run { self.progress.duplicates = .done(summary: summary) }
        return issues
    }

    // ── Similar Photos ────────────────────────────────────────
    private func runSimilarPhotos(at url: URL) async -> [ScanIssue] {
        await MainActor.run { self.progress.similarPhotos = .running }

        // Делегуємо існуючому Vision-based similar photos engine
        let engine = SimilarPhotosEngine()
        let clusters = await engine.findClusters(in: url)

        var issues: [ScanIssue] = []
        for cluster in clusters {
            guard cluster.photos.count > 1 else { continue }
            let toDelete = Array(cluster.photos.dropFirst())
            let bytes = toDelete.reduce(Int64(0)) { acc, u in
                let size = (try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return acc + Int64(size)
            }
            issues.append(ScanIssue(
                id: UUID(),
                category: .similarPhoto,
                displayName: "\(cluster.label) — \(cluster.photos.count) схожих",
                detail: "Vision AI ≥ \(Int(cluster.minSimilarity * 100))% схожості",
                urls: toDelete,
                bytes: bytes,
                isSelected: false  // UNCHECKED за замовчуванням
            ))
        }

        let summary = issues.isEmpty ? "Схожих немає" : "\(issues.count) кластери"
        await MainActor.run { self.progress.similarPhotos = .done(summary: summary) }
        return issues
    }
}
