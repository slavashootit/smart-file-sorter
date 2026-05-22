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

        var issues: [ScanIssue] = []
        for fileURL in found {
            let size = Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            let reason = ScanIssue.determineReason(category: .cleanup, url: fileURL)
            issues.append(ScanIssue(
                id: UUID(),
                category: .cleanup,
                displayName: fileURL.lastPathComponent,
                detail: fileURL.path,
                urls: [fileURL],
                bytes: size,
                isSelected: true,
                reason: reason
            ))
        }

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
            for dupFile in toDelete {
                let size = Int64((try? dupFile.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                let reason = ScanIssue.determineReason(category: .duplicate, url: dupFile, originalFile: keeper)
                issues.append(ScanIssue(
                    id: UUID(),
                    category: .duplicate,
                    displayName: dupFile.lastPathComponent,
                    detail: "Дублікат файлу \(keeper.lastPathComponent)",
                    urls: [dupFile],
                    bytes: size,
                    isSelected: true,
                    reason: reason
                ))
            }
        }

        let totalBytes = issues.reduce(Int64(0)) { $0 + $1.bytes }
        let summary = issues.isEmpty ? "Дублікатів немає" :
            "\(issues.count) файлів · \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))"
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
            for photoURL in toDelete {
                let size = Int64((try? photoURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                let reason = ScanIssue.determineReason(category: .similarPhoto, url: photoURL, clusterSize: cluster.photos.count)
                issues.append(ScanIssue(
                    id: UUID(),
                    category: .similarPhoto,
                    displayName: photoURL.lastPathComponent,
                    detail: reason,
                    urls: [photoURL],
                    bytes: size,
                    isSelected: false, // UNCHECKED за замовчуванням
                    reason: reason
                ))
            }
        }

        let summary = issues.isEmpty ? "Схожих немає" : "\(issues.count) фото"
        await MainActor.run { self.progress.similarPhotos = .done(summary: summary) }
        return issues
    }
}
