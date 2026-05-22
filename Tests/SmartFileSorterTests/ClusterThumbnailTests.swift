import XCTest
import SwiftUI
@testable import SmartFileSorter

@MainActor
final class ClusterThumbnailTests: XCTestCase {
    
    func testOriginalIsLargestFile() {
        let issueSmall = ScanIssue(id: UUID(), category: .similarPhoto, displayName: "small.png", detail: "", urls: [URL(fileURLWithPath: "/path/1")], bytes: 100, isSelected: true, reason: "")
        let issueLarge = ScanIssue(id: UUID(), category: .similarPhoto, displayName: "large.png", detail: "", urls: [URL(fileURLWithPath: "/path/2")], bytes: 300, isSelected: false, reason: "")
        let issueMedium = ScanIssue(id: UUID(), category: .similarPhoto, displayName: "medium.png", detail: "", urls: [URL(fileURLWithPath: "/path/3")], bytes: 200, isSelected: true, reason: "")
        
        let photos = [issueSmall, issueLarge, issueMedium]
        
        var largestIndex = 0
        var largestSize: Int64 = -1
        for (idx, photo) in photos.enumerated() {
            if photo.bytes > largestSize {
                largestSize = photo.bytes
                largestIndex = idx
            }
        }
        
        let cluster = ScanCluster(photos: photos, originalIndex: largestIndex)
        
        XCTAssertEqual(cluster.originalIndex, 1)
        XCTAssertEqual(cluster.photos[cluster.originalIndex].displayName, "large.png")
    }
    
    func testOriginalNotSelectedByDefault() {
        let issueSmall = ScanIssue(id: UUID(), category: .similarPhoto, displayName: "small.png", detail: "", urls: [URL(fileURLWithPath: "/path/1")], bytes: 100, isSelected: true, reason: "")
        let issueLarge = ScanIssue(id: UUID(), category: .similarPhoto, displayName: "large.png", detail: "", urls: [URL(fileURLWithPath: "/path/2")], bytes: 300, isSelected: false, reason: "")
        let issueMedium = ScanIssue(id: UUID(), category: .similarPhoto, displayName: "medium.png", detail: "", urls: [URL(fileURLWithPath: "/path/3")], bytes: 200, isSelected: true, reason: "")
        
        let photos = [issueSmall, issueLarge, issueMedium]
        let cluster = ScanCluster(photos: photos, originalIndex: 1)
        
        XCTAssertFalse(cluster.photos[1].isSelected)
        XCTAssertTrue(cluster.photos[0].isSelected)
        XCTAssertTrue(cluster.photos[2].isSelected)
    }
    
    func testClusterDeleteCountMatchesSelected() {
        let issueSmall = ScanIssue(id: UUID(), category: .similarPhoto, displayName: "small.png", detail: "", urls: [URL(fileURLWithPath: "/path/1")], bytes: 100, isSelected: true, reason: "")
        let issueLarge = ScanIssue(id: UUID(), category: .similarPhoto, displayName: "large.png", detail: "", urls: [URL(fileURLWithPath: "/path/2")], bytes: 300, isSelected: false, reason: "")
        let issueMedium = ScanIssue(id: UUID(), category: .similarPhoto, displayName: "medium.png", detail: "", urls: [URL(fileURLWithPath: "/path/3")], bytes: 200, isSelected: true, reason: "")
        
        let photos = [issueSmall, issueLarge, issueMedium]
        let cluster = ScanCluster(photos: photos, originalIndex: 1)
        
        let deleteCount = cluster.photos.filter(\.isSelected).count
        XCTAssertEqual(deleteCount, 2)
    }
    
    func testThumbnailCacheHit() async {
        let loader = ThumbnailLoader.shared
        await loader.clearCache()
        
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        
        let testImageURL = tmpDir.appendingPathComponent("test.png")
        let size = NSSize(width: 1, height: 1)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: testImageURL)
        }
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: testImageURL.path))
        
        let firstImg = await loader.loadThumbnail(for: testImageURL, size: 72)
        XCTAssertNotNil(firstImg)
        
        let firstCallCount = await loader.generatorCallCount
        XCTAssertGreaterThan(firstCallCount, 0)
        
        let secondImg = await loader.loadThumbnail(for: testImageURL, size: 72)
        XCTAssertNotNil(secondImg)
        
        let secondCallCount = await loader.generatorCallCount
        XCTAssertEqual(firstCallCount, secondCallCount)
    }
}
