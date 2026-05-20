import Foundation

public struct DiskNode: Identifiable, Hashable {
    public let id = UUID()
    public let url: URL
    public let name: String
    public let size: Int64
    public let isDirectory: Bool
    public var children: [DiskNode]
    
    public init(url: URL, name: String, size: Int64, isDirectory: Bool, children: [DiskNode] = []) {
        self.url = url
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.children = children
    }
}

public class DiskAnalyzer: ObservableObject {
    @Published public var rootNode: DiskNode? = nil
    @Published public var currentNode: DiskNode? = nil
    @Published public var isScanning = false
    @Published public var scanProgress: Double = 0.0
    @Published public var history: [DiskNode] = []
    
    private var isCancelled = false
    
    public init() {}
    
    public func cancel() {
        isCancelled = true
        isScanning = false
    }
    
    public func analyze(directoryPath: String) {
        isCancelled = false
        isScanning = true
        scanProgress = 0.0
        
        let url = URL(fileURLWithPath: directoryPath)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let root = self.buildTree(for: url)
            
            DispatchQueue.main.async {
                if !self.isCancelled {
                    self.rootNode = root
                    self.currentNode = root
                    self.history = []
                }
                self.isScanning = false
            }
        }
    }
    
    private func buildTree(for url: URL) -> DiskNode {
        if isCancelled {
            return DiskNode(url: url, name: url.lastPathComponent, size: 0, isDirectory: false)
        }
        
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return DiskNode(url: url, name: url.lastPathComponent, size: 0, isDirectory: false)
        }
        
        if !isDir.boolValue {
            let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            return DiskNode(url: url, name: url.lastPathComponent, size: size, isDirectory: false)
        }
        
        var childNodes: [DiskNode] = []
        var totalSize: Int64 = 0
        
        if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for childURL in contents {
                if isCancelled { break }
                let childNode = buildTree(for: childURL)
                if childNode.size > 0 {
                    childNodes.append(childNode)
                    totalSize += childNode.size
                }
            }
        }
        
        childNodes.sort { $0.size > $1.size }
        
        return DiskNode(url: url, name: url.lastPathComponent, size: totalSize, isDirectory: true, children: childNodes)
    }
    
    public func selectNode(_ node: DiskNode) {
        if node.isDirectory {
            if let current = currentNode {
                history.append(current)
            }
            currentNode = node
        }
    }
    
    public func navigateBack() {
        if !history.isEmpty {
            currentNode = history.removeLast()
        }
    }
}
