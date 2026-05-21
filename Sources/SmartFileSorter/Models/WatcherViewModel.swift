import Foundation
import UserNotifications

public class WatcherViewModel: ObservableObject {
    @Published public var watchedFolders: [String] = []
    @Published public var isPaused: Bool = false
    

    
    public init() {
        FSEventsWatcher.shared.restoreAllWatchedFolders()
        self.watchedFolders = FSEventsWatcher.shared.getWatchedPaths()
        self.isPaused = !FSEventsWatcher.shared.isWatching() && !FSEventsWatcher.shared.getWatchedPaths().isEmpty
        
        FSEventsWatcher.shared.onEvents = { [weak self] paths in
            self?.handleFileEvents(paths)
        }
    }
    
    public func addFolder(path: String) {
        if FSEventsWatcher.shared.watchFolder(path: path) {
            watchedFolders = FSEventsWatcher.shared.getWatchedPaths()
            isPaused = false
        }
    }
    
    public func removeFolder(path: String) {
        FSEventsWatcher.shared.unwatchFolder(path: path)
        watchedFolders = FSEventsWatcher.shared.getWatchedPaths()
    }
    
    public func togglePause() {
        if isPaused {
            FSEventsWatcher.shared.resumeAll()
            isPaused = false
        } else {
            FSEventsWatcher.shared.pauseAll()
            isPaused = true
        }
    }
    
    private func handleFileEvents(_ paths: [String]) {
        let fileManager = FileManager.default
        let rules = RuleEngine.shared.rules
        
        var processedCount = 0
        var operations: [BatchOperation] = []
        
        for path in paths {
            let fileURL = URL(fileURLWithPath: path)
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }
            
            // Застосовуємо правила по черзі
            for rule in rules {
                if RuleEngine.shared.match(rule: rule, for: fileURL) {
                    let result = RuleEngine.shared.execute(rule: rule, for: fileURL)
                    if result.success {
                        processedCount += 1
                        let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
                        let op = BatchOperation(originalPath: fileURL.path, newPath: result.finalURL.path, fileSize: size)
                        operations.append(op)
                    }
                    break
                }
            }
        }
        
        if processedCount > 0 {
            let batch = BatchRecord(
                timestamp: Date(),
                operations: operations,
                createdDirs: [],
                profileName: "Watcher"
            )
            HistoryManager.shared.addBatch(batch)
            
            if processedCount > 20 {
                sendNotification(
                    title: "Розумний сортувальник",
                    body: "Автоматично впорядковано \(processedCount) нових файлів."
                )
            }
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request)
        }
    }
}
