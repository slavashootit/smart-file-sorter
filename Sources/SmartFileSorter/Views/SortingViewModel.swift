import Foundation
import SwiftUI

@MainActor
public final class SortingViewModel: ObservableObject {
    @Published public var state: SortingViewState = .idle
    @Published public var folderPath: String = ""
    @Published public var selectedCategories: Set<String> = ["photos", "video", "audio", "documents"]
    
    public init() {}
    
    public func analyse(url: URL, categories: Set<String>) async {
        self.folderPath = url.path
        self.state = .analysing
        
        let groups = await SorterEngine.shared.preview(url: url, categories: categories)
        self.state = .preview(groups: groups)
    }
    
    public func sort() async {
        guard case .preview(let groups) = state, !folderPath.isEmpty else { return }
        
        self.state = .sorting
        
        let url = URL(fileURLWithPath: folderPath)
        let fileManager = FileManager.default
        var moves: [MoveRecord] = []
        var createdDirs: [String] = []
        var totalMoved = 0
        
        let enabledGroups = groups.filter(\.isEnabled)
        
        for group in enabledGroups {
            let destFolder = group.destination
            
            // Record directory creation hierarchy
            var p = destFolder
            var parentsToCreate: [URL] = []
            while p.path != url.path && p.path != p.deletingLastPathComponent().path {
                if !fileManager.fileExists(atPath: p.path) {
                    parentsToCreate.append(p)
                }
                p = p.deletingLastPathComponent()
            }
            for parent in parentsToCreate.reversed() {
                if !createdDirs.contains(parent.path) {
                    createdDirs.append(parent.path)
                }
            }
            
            // Create target folder
            if !fileManager.fileExists(atPath: destFolder.path) {
                try? fileManager.createDirectory(at: destFolder, withIntermediateDirectories: true, attributes: nil)
            }
            
            for fileURL in group.files {
                let uniqueDest = SorterEngine.shared.uniqueDestPath(baseFolder: destFolder, source: fileURL)
                do {
                    try fileManager.moveItem(at: fileURL, to: uniqueDest)
                    moves.append(MoveRecord(original: fileURL.path, new: uniqueDest.path))
                    totalMoved += 1
                } catch {
                    print("Failed to move \(fileURL.lastPathComponent): \(error)")
                }
            }
        }
        
        // Save to History for Undo functionality
        if !moves.isEmpty {
            let batchOps = moves.map { move -> BatchOperation in
                let size = (try? fileManager.attributesOfItem(atPath: move.new)[.size] as? Int64) ?? 0
                let isTrash = move.new.contains("/.Trash/") || move.new.contains("/Trash/")
                return BatchOperation(originalPath: move.original, newPath: move.new, isTrashed: isTrash, fileSize: size)
            }
            let batch = BatchRecord(
                timestamp: Date(),
                operations: batchOps,
                createdDirs: createdDirs,
                isCancelled: false
            )
            HistoryManager.shared.addBatch(batch)
        }
        
        self.state = .done(moved: totalMoved)
    }
    
    public func reset() {
        self.state = .idle
    }
}
