import XCTest
@testable import SmartFileSorter

final class FavoriteFoldersManagerTests: XCTestCase {
    var tempFileURL: URL!
    var manager: FavoriteFoldersManager!
    
    override func setUp() {
        super.setUp()
        let tempDir = NSTemporaryDirectory()
        let fileName = "favorites_test_\(UUID().uuidString).json"
        tempFileURL = URL(fileURLWithPath: tempDir).appendingPathComponent(fileName)
        manager = FavoriteFoldersManager(customFileURL: tempFileURL)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFileURL)
        super.tearDown()
    }
    
    func testAddFavorite() {
        XCTAssertTrue(manager.favorites.isEmpty)
        
        let path = NSHomeDirectory() + "/Downloads"
        manager.addFavorite(path: path, name: "Downloads")
        
        XCTAssertEqual(manager.favorites.count, 1)
        XCTAssertEqual(manager.favorites[0].name, "Downloads")
        XCTAssertEqual(manager.favorites[0].path, "~/Downloads") // Normalized to ~ if home directory prefix matches
    }
    
    func testMaxFiveFavorites() {
        // Add 6 distinct folders
        for i in 1...6 {
            manager.addFavorite(path: "/some/path/folder\(i)", name: "Folder \(i)")
        }
        
        // Assert count is capped at 5
        XCTAssertEqual(manager.favorites.count, 5)
        
        // Assert oldest (Folder 1) is deleted, leaving Folder 2 through 6
        XCTAssertEqual(manager.favorites[0].name, "Folder 2")
        XCTAssertEqual(manager.favorites[4].name, "Folder 6")
    }
    
    func testRemoveFavorite() {
        manager.addFavorite(path: "/some/path/folderA", name: "Folder A")
        manager.addFavorite(path: "/some/path/folderB", name: "Folder B")
        
        XCTAssertEqual(manager.favorites.count, 2)
        
        manager.removeFavorite(path: "/some/path/folderA")
        
        XCTAssertEqual(manager.favorites.count, 1)
        XCTAssertEqual(manager.favorites[0].name, "Folder B")
    }
    
    func testTildeExpansion() {
        let fav = FavoriteFolder(name: "Downloads", path: "~/Downloads")
        
        XCTAssertEqual(fav.absolutePath, NSHomeDirectory() + "/Downloads")
        XCTAssertEqual(fav.absoluteURL.path, NSHomeDirectory() + "/Downloads")
    }
    
    func testPersistence() {
        manager.addFavorite(path: "/some/path/folderP", name: "Folder P")
        XCTAssertEqual(manager.favorites.count, 1)
        
        // Instantiate a new manager pointing to the same file
        let secondManager = FavoriteFoldersManager(customFileURL: tempFileURL)
        
        XCTAssertEqual(secondManager.favorites.count, 1)
        XCTAssertEqual(secondManager.favorites[0].name, "Folder P")
        XCTAssertEqual(secondManager.favorites[0].path, "/some/path/folderP")
    }
}
