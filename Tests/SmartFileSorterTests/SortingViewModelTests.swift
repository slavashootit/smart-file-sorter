import XCTest
import SwiftUI
@testable import SmartFileSorter

@MainActor
final class SortingViewModelTests: XCTestCase {
    
    private var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }
    
    func testAnalyseGroupsByCategory() async {
        // Create 3 jpg files and 2 pdf files
        for i in 1...3 {
            let fileURL = tempDir.appendingPathComponent("pic_\(i).jpg")
            try? "dummy data".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        for i in 1...2 {
            let fileURL = tempDir.appendingPathComponent("doc_\(i).pdf")
            try? "dummy data".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        let viewModel = SortingViewModel()
        await viewModel.analyse(url: tempDir, categories: ["photos", "documents"])
        
        guard case .preview(let groups) = viewModel.state else {
            XCTFail("State should be preview")
            return
        }
        
        XCTAssertEqual(groups.count, 2)
        
        let photosGroup = groups.first { $0.category == "Фото" }
        let docsGroup = groups.first { $0.category == "Документи" }
        
        XCTAssertNotNil(photosGroup)
        XCTAssertNotNil(docsGroup)
        
        XCTAssertEqual(photosGroup?.files.count, 3)
        XCTAssertEqual(docsGroup?.files.count, 2)
    }
    
    func testDisabledCategoryExcludedFromPreview() async {
        // Create 3 jpg files and 2 pdf files
        for i in 1...3 {
            let fileURL = tempDir.appendingPathComponent("pic_\(i).jpg")
            try? "dummy data".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        for i in 1...2 {
            let fileURL = tempDir.appendingPathComponent("doc_\(i).pdf")
            try? "dummy data".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        let viewModel = SortingViewModel()
        // Only docs are enabled
        await viewModel.analyse(url: tempDir, categories: ["documents"])
        
        guard case .preview(let groups) = viewModel.state else {
            XCTFail("State should be preview")
            return
        }
        
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].category, "Документи")
        XCTAssertNil(groups.first { $0.category == "Фото" })
    }
    
    func testSortGroupDestinationPath() {
        let baseFolder = URL(fileURLWithPath: "/Users/test/Downloads")
        let destination = baseFolder.appendingPathComponent("Фото")
        
        let group = SortGroup(
            category: "Фото",
            destination: destination,
            files: [baseFolder.appendingPathComponent("image.jpg")],
            isEnabled: true
        )
        
        XCTAssertEqual(group.destination.path, "/Users/test/Downloads/Фото")
    }
    
    func testOtherCategoryIsFallback() async {
        // Create a file with unknown extension
        let fileURL = tempDir.appendingPathComponent("test.xyz")
        try? "dummy data".write(to: fileURL, atomically: true, encoding: .utf8)
        
        let viewModel = SortingViewModel()
        
        // 1. With "other" category enabled
        await viewModel.analyse(url: tempDir, categories: ["other"])
        guard case .preview(let groupsWithOther) = viewModel.state else {
            XCTFail("State should be preview")
            return
        }
        XCTAssertEqual(groupsWithOther.count, 1)
        XCTAssertEqual(groupsWithOther[0].category, "Інше")
        XCTAssertEqual(groupsWithOther[0].files.first?.lastPathComponent, "test.xyz")
        
        // 2. Without "other" category enabled
        await viewModel.analyse(url: tempDir, categories: [])
        guard case .preview(let groupsWithoutOther) = viewModel.state else {
            XCTFail("State should be preview")
            return
        }
        XCTAssertTrue(groupsWithoutOther.isEmpty)
    }
    
    func testSortCountMatchesEnabledGroups() {
        let destination1 = tempDir.appendingPathComponent("Фото")
        let destination2 = tempDir.appendingPathComponent("Документи")
        
        let group1 = SortGroup(
            category: "Фото",
            destination: destination1,
            files: [tempDir.appendingPathComponent("1.jpg"), tempDir.appendingPathComponent("2.jpg")],
            isEnabled: true
        )
        let group2 = SortGroup(
            category: "Документи",
            destination: destination2,
            files: [tempDir.appendingPathComponent("1.pdf")],
            isEnabled: true
        )
        
        var groups = [group1, group2]
        
        // Both enabled: sum should be 3
        var enabledCount = groups.filter(\.isEnabled).reduce(0) { $0 + $1.files.count }
        XCTAssertEqual(enabledCount, 3)
        
        // Disable group 2: sum should be 2
        groups[1].isEnabled = false
        enabledCount = groups.filter(\.isEnabled).reduce(0) { $0 + $1.files.count }
        XCTAssertEqual(enabledCount, 2)
    }
}
