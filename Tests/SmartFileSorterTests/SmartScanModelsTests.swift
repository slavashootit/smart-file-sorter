import XCTest
@testable import SmartFileSorter

final class SmartScanModelsTests: XCTestCase {
    func test_totalBytes_onlyCountsSelected() {
        let issues = [
            ScanIssue(id: UUID(), category: .cleanup, displayName: "a", detail: "",
                      urls: [], bytes: 100, isSelected: true),
            ScanIssue(id: UUID(), category: .duplicate, displayName: "b", detail: "",
                      urls: [], bytes: 200, isSelected: false),
        ]
        let results = ScanResults(issues: issues, scannedPath: URL(fileURLWithPath: "/tmp"), scannedAt: .now)
        XCTAssertEqual(results.totalBytes, 100)
    }

    func test_grouped_sortedByCategory() {
        let issues = [
            ScanIssue(id: UUID(), category: .similarPhoto, displayName: "p", detail: "", urls: [], bytes: 0, isSelected: false),
            ScanIssue(id: UUID(), category: .cleanup, displayName: "c", detail: "", urls: [], bytes: 0, isSelected: true),
        ]
        let results = ScanResults(issues: issues, scannedPath: URL(fileURLWithPath: "/tmp"), scannedAt: .now)
        XCTAssertEqual(results.grouped.first?.category, .cleanup)
    }

    func test_similarPhoto_defaultNotSelected() {
        let issue = ScanIssue(id: UUID(), category: .similarPhoto, displayName: "x",
                              detail: "", urls: [], bytes: 0, isSelected: false)
        XCTAssertFalse(issue.isSelected)
    }
}
