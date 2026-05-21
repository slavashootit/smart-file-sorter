import Foundation

public struct ExclusionsConfig: Codable, Equatable {
    public var excludedNames: [String]
    public var regexPatterns: [String]
    public var excludedPaths: [String]
    
    public init(excludedNames: [String], regexPatterns: [String], excludedPaths: [String]) {
        self.excludedNames = excludedNames
        self.regexPatterns = regexPatterns
        self.excludedPaths = excludedPaths
    }
}

public final class ConfigManager: ObservableObject {
    public static let shared = ConfigManager()
    
    public var configDirectoryURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SmartFileSorter").appendingPathComponent("config")
    }
    
    public var categoriesFileURL: URL {
        return configDirectoryURL.appendingPathComponent("categories.json")
    }
    
    public var exclusionsFileURL: URL {
        return configDirectoryURL.appendingPathComponent("exclusions.json")
    }
    
    @Published public var categories: [String: [String]] = [:]
    @Published public var exclusions: ExclusionsConfig = ExclusionsConfig(excludedNames: [], regexPatterns: [], excludedPaths: [])
    
    private let queue = DispatchQueue(label: "com.smartfilesorter.configmanager", qos: .userInitiated)
    
    private init() {
        setupDirectories()
        loadCategories()
        loadExclusions()
    }
    
    private func setupDirectories() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configDirectoryURL.path) {
            try? fileManager.createDirectory(at: configDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    private func loadCategories() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: categoriesFileURL.path) {
            do {
                let data = try Data(contentsOf: categoriesFileURL)
                let loaded = try JSONDecoder().decode([String: [String]].self, from: data)
                self.categories = loaded
                return
            } catch {
                print("Failed to load categories, using defaults: \(error)")
            }
        }
        
        // Default categories
        self.categories = [
            "Зображення": ["jpg", "jpeg", "png", "gif", "bmp", "heic", "tiff", "svg", "webp", "raw"],
            "Відео": ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"],
            "Документи": ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "odt", "csv", "pages", "numbers", "key"],
            "Аудіо": ["mp3", "wav", "m4a", "flac", "aac", "ogg", "wma"],
            "Архіви": ["zip", "rar", "7z", "tar", "gz", "dmg", "pkg"]
        ]
        saveCategories()
    }
    
    private func loadExclusions() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: exclusionsFileURL.path) {
            do {
                let data = try Data(contentsOf: exclusionsFileURL)
                let loaded = try JSONDecoder().decode(ExclusionsConfig.self, from: data)
                self.exclusions = loaded
                return
            } catch {
                print("Failed to load exclusions, using defaults: \(error)")
            }
        }
        
        // Default exclusions
        self.exclusions = ExclusionsConfig(
            excludedNames: [
                "Відео", "Зображення", "Документи", "Аудіо", "Архіви", "Дублікати", "Інші файли",
                ".git", "node_modules", ".Trash", ".trash", "timemachine.backupdb"
            ],
            regexPatterns: [
                "^\\d{4}$",
                ".*\\.backupbundle$",
                ".*\\.backupdb$"
            ],
            excludedPaths: [
                "/System",
                "/Library",
                "/private",
                "/usr",
                "/bin",
                "/sbin",
                "~/Library",
                "~/.Trash"
            ]
        )
        saveExclusions()
    }
    
    public func saveCategories() {
        queue.async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(self.categories)
                try data.write(to: self.categoriesFileURL, options: .atomic)
            } catch {
                print("Failed to save categories: \(error)")
            }
        }
    }
    
    public func saveExclusions() {
        queue.async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(self.exclusions)
                try data.write(to: self.exclusionsFileURL, options: .atomic)
            } catch {
                print("Failed to save exclusions: \(error)")
            }
        }
    }
    
    public func updateCategories(_ newCategories: [String: [String]]) {
        DispatchQueue.main.async {
            self.categories = newCategories
            self.saveCategories()
        }
    }
    
    public func updateExclusions(_ newExclusions: ExclusionsConfig) {
        DispatchQueue.main.async {
            self.exclusions = newExclusions
            self.saveExclusions()
        }
    }
    
    // Check if the URL should be excluded
    public func shouldExclude(url: URL) -> Bool {
        let path = url.path
        let name = url.lastPathComponent
        
        // 1. Check excluded paths
        for exp in exclusions.excludedPaths {
            let expanded = exp.hasPrefix("~") ? exp.replacingOccurrences(of: "~", with: NSHomeDirectory()) : exp
            if path.hasPrefix(expanded) {
                return true
            }
        }
        
        // 2. Check excluded names (exact or case-insensitive)
        if exclusions.excludedNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            return true
        }
        
        // Check if any component in the path is in the excluded names list
        for component in url.pathComponents {
            if exclusions.excludedNames.contains(where: { $0.caseInsensitiveCompare(component) == .orderedSame }) {
                return true
            }
        }
        
        // 3. Check regex patterns on each path component and filename
        for pattern in exclusions.regexPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: name.utf16.count)
                if regex.firstMatch(in: name, options: [], range: range) != nil {
                    return true
                }
                for component in url.pathComponents {
                    let compRange = NSRange(location: 0, length: component.utf16.count)
                    if regex.firstMatch(in: component, options: [], range: compRange) != nil {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // Classify a single file by extension
    public func getFileCategory(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        for (category, extensions) in categories {
            if extensions.contains(ext) {
                return category
            }
        }
        return "Інші файли"
    }
}
