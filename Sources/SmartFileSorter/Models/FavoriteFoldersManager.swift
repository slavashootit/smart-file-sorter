import Foundation
import Combine

public struct FavoriteFolder: Codable, Hashable, Equatable {
    public let name: String?
    public let path: String
    
    public init(name: String? = nil, path: String) {
        self.name = name
        self.path = path
    }
    
    public var absolutePath: String {
        return (path as NSString).expandingTildeInPath
    }
    
    public var absoluteURL: URL {
        return URL(fileURLWithPath: absolutePath)
    }
    
    public var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        let lastComp = absoluteURL.lastPathComponent
        return lastComp.isEmpty ? path : lastComp
    }
}

public struct FavoriteFoldersConfig: Codable {
    public var scanFavorites: [FavoriteFolder]
}

public final class FavoriteFoldersManager: ObservableObject {
    public static let shared = FavoriteFoldersManager()
    
    @Published public var favorites: [FavoriteFolder] = []
    
    public var customFileURL: URL?
    
    private var fileURL: URL {
        if let custom = customFileURL {
            return custom
        }
        return ConfigManager.shared.configDirectoryURL.appendingPathComponent("favorites.json")
    }
    
    private let queue = DispatchQueue(label: "com.smartfilesorter.favoritemanager", qos: .userInitiated)
    
    public init(customFileURL: URL? = nil) {
        self.customFileURL = customFileURL
        load()
    }
    
    public func load() {
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode(FavoriteFoldersConfig.self, from: data)
                self.favorites = decoded.scanFavorites
                return
            } catch {
                print("Failed to load favorites: \(error)")
            }
        }
        
        // Defaults if file doesn't exist
        self.favorites = []
    }
    
    public func save() {
        let config = FavoriteFoldersConfig(scanFavorites: favorites)
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save favorites: \(error)")
        }
    }
    
    public func addFavorite(path: String, name: String? = nil) {
        let normalizedPath = normalizePath(path)
        
        // Remove existing duplicate
        favorites.removeAll(where: { normalizePath($0.path) == normalizedPath })
        
        let newFav = FavoriteFolder(name: name, path: normalizedPath)
        favorites.append(newFav)
        
        // Keep maximum of 5 entries, remove oldest (at index 0)
        while favorites.count > 5 {
            favorites.removeFirst()
        }
        
        save()
    }
    
    public func removeFavorite(path: String) {
        let normalizedPath = normalizePath(path)
        favorites.removeAll(where: { normalizePath($0.path) == normalizedPath })
        save()
    }
    
    private func normalizePath(_ rawPath: String) -> String {
        let home = NSHomeDirectory()
        var path = rawPath
        if path.hasPrefix(home) {
            path = "~" + path.dropFirst(home.count)
        }
        return path
      }
}
