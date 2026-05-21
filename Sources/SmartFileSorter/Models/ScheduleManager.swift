import Foundation

public class ScheduleManager {
    public static let shared = ScheduleManager()
    
    private let queue = DispatchQueue(label: "com.smartfilesorter.scheduleQueue")
    private var scheduler: NSBackgroundActivityScheduler?
    
    public init() {
        setupScheduler()
    }
    
    public func setupScheduler() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Зупиняємо попередній планувальник якщо він був запущений
            self.scheduler?.invalidate()
            
            let intervalString = UserDefaults.standard.string(forKey: "schedule_interval") ?? "daily"
            if intervalString == "none" {
                print("[SCHEDULER] Фоновий запуск відключено")
                self.scheduler = nil
                return
            }
            
            let activity = NSBackgroundActivityScheduler(identifier: "com.smartfilesorter.scheduler")
            activity.repeats = true
            
            // Конвертуємо інтервал у секунди
            var interval: TimeInterval = 24 * 60 * 60 // daily
            if intervalString == "hourly" {
                interval = 60 * 60
            } else if intervalString == "weekly" {
                interval = 7 * 24 * 60 * 60
            }
            
            activity.interval = interval
            activity.tolerance = interval * 0.1 // 10% допуск для оптимізації ОС
            
            activity.schedule { completion in
                print("[SCHEDULER] Запуск фонового сканування за розкладом...")
                self.runScheduledSorting {
                    completion(.finished)
                }
            }
            
            self.scheduler = activity
            print("[SCHEDULER] Налаштовано розклад: \(intervalString) (інтервал: \(interval) сек)")
        }
    }
    
    public func runScheduledSorting(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let fileManager = FileManager.default
            let watchedPaths = UserDefaults.standard.stringArray(forKey: "watcher_paths") ?? []
            
            // Завантажуємо актуальні правила
            RuleEngine.shared.loadRules()
            let rules = RuleEngine.shared.rules
            
            guard !watchedPaths.isEmpty && !rules.isEmpty else {
                completion()
                return
            }
            
            var sortedCount = 0
            var operations: [BatchOperation] = []
            
            for path in watchedPaths {
                let folderURL = URL(fileURLWithPath: path)
                guard fileManager.fileExists(atPath: folderURL.path) else { continue }
                
                // Зчитуємо плоский список файлів у папці
                guard let enumerator = fileManager.enumerator(
                    at: folderURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                ) else { continue }
                
                for case let fileURL as URL in enumerator {
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                          resourceValues.isRegularFile ?? false else { continue }
                    
                    // Перевіряємо правила
                    for rule in rules {
                        if RuleEngine.shared.match(rule: rule, for: fileURL) {
                            let result = RuleEngine.shared.execute(rule: rule, for: fileURL)
                            if result.success {
                                sortedCount += 1
                                let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
                                operations.append(BatchOperation(originalPath: fileURL.path, newPath: result.finalURL.path, fileSize: size))
                            }
                            break // Правило спрацювало, переходимо до наступного файлу
                        }
                    }
                }
            }
            
            if sortedCount > 0 {
                let batch = BatchRecord(
                    timestamp: Date(),
                    operations: operations,
                    createdDirs: []
                )
                HistoryManager.shared.addBatch(batch)
                print("[SCHEDULER] Автоматично впорядковано за розкладом: \(sortedCount)")
            }
            
            completion()
        }
    }
}
