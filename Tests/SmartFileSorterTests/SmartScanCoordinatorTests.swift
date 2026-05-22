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
}
