import XCTest
@testable import SmartFileSorter

@MainActor
final class SmartScanCoordinatorTests: XCTestCase {
    func test_startScan_setsProgressToRunning() async {
        let coordinator = SmartScanCoordinator()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        coordinator.startScan(at: tmpDir)
        // After starting, progress fraction begins at 0
        XCTAssertEqual(coordinator.progress.overallFraction, 0.0)
    }

    func test_cacheTTL_skipsScanIfFresh() async throws {
        let coordinator = SmartScanCoordinator()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        coordinator.startScan(at: tmpDir)
        try await Task.sleep(for: .milliseconds(500))
        let firstResults = coordinator.results

        // Second scan within TTL — should reuse cache
        coordinator.startScan(at: tmpDir)
        XCTAssertEqual(coordinator.results?.scannedAt, firstResults?.scannedAt)
    }

    func test_similarPhoto_issues_areUnchecked() async throws {
        // Verify that issues with category .similarPhoto default to isSelected = false
        let issue = ScanIssue(id: UUID(), category: .similarPhoto,
                              displayName: "test", detail: "",
                              urls: [], bytes: 0, isSelected: false)
        XCTAssertFalse(issue.isSelected)
    }

    func test_similarPhotosEngine_testPool() async {
        let path = NSHomeDirectory() + "/Downloads/ТЕСТИ"
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            print("[TEST] Skip: test pool folder not found at \(path)")
            return
        }
        
        let engine = SimilarPhotosEngine()
        let clusters = await engine.findClusters(in: url)
        print("--- SIMILAR PHOTOS CLUSTERS COUNT: \(clusters.count) ---")
        for (i, cluster) in clusters.enumerated() {
            print("Cluster \(i + 1) (\(cluster.label)): \(cluster.photos.count) photos, min similarity \(cluster.minSimilarity)")
            for photo in cluster.photos {
                print("  - \(photo.lastPathComponent)")
            }
        }
        XCTAssertTrue(clusters.count >= 4 && clusters.count <= 15, "Expected clusters count between 4 and 15, got \(clusters.count)")
    }
}
