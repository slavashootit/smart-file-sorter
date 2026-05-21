import Foundation
import CoreServices

/// Callback-функція FSEvents у форматі C-функції
private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    
    // Отримуємо посилання на екземпляр FSEventsWatcher
    let watcher = Unmanaged<FSEventsWatcher>.fromOpaque(info).takeUnretainedValue()
    
    // Оскільки використовується прапорець kFSEventStreamCreateFlagUseCFTypes,
    // eventPaths є об'єктом CFArray, що містить CFString шляхів.
    let pathsArray = unsafeBitCast(eventPaths, to: CFArray.self)
    let count = CFArrayGetCount(pathsArray)
    
    var paths: [String] = []
    for i in 0..<count {
        let value = CFArrayGetValueAtIndex(pathsArray, i)
        let pathCF = unsafeBitCast(value, to: CFString.self)
        paths.append(pathCF as String)
    }
    
    watcher.processEvents(paths: paths)
}

/// Клас для моніторингу папок у реальному часі за допомогою FSEvents API
public class FSEventsWatcher {
    
    public static let shared = FSEventsWatcher()
    
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.smartfilesorter.fsevents", qos: .utility)
    
    // Максимальна кількість папок для відстеження
    public let maxWatchFolders = 5
    
    // Локальний стан
    private var watchedPaths: Set<String> = []
    private var isPaused = false
    
    // Callback для підключення обробника правил
    public var onEvents: (([String]) -> Void)?
    
    public init() {}
    
    /// Отримати список папок, які зараз відстежуються
    public func getWatchedPaths() -> [String] {
        return Array(watchedPaths)
    }
    
    /// Чи активне відстеження зараз
    public func isWatching() -> Bool {
        return stream != nil && !isPaused
    }
    
    /// Додати папку для моніторингу
    /// - Parameter path: Абсолютний шлях до папки
    /// - Returns: True, якщо папка додана успішно
    public func watchFolder(path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else {
            print("[WATCHER] Папка не існує: \(path)")
            return false
        }
        
        if watchedPaths.count >= maxWatchFolders {
            print("[WATCHER] Досягнуто ліміт у \(maxWatchFolders) папок для відстеження!")
            return false
        }
        
        let url = URL(fileURLWithPath: path)
        // Набуваємо прав доступу, якщо працюємо в Sandbox
        SecurityBookmarks.shared.startAccessing(url)
        SecurityBookmarks.shared.saveBookmark(for: url)
        
        watchedPaths.insert(path)
        print("[WATCHER] Додано папку: \(path)")
        
        let activeProfile = "Home"
        UserDefaults.standard.set(Array(watchedPaths), forKey: "watcher_paths_\(activeProfile)")
        
        restartStream()
        return true
    }
    
    /// Припинити моніторинг папки
    /// - Parameter path: Шлях до папки
    public func unwatchFolder(path: String) {
        if watchedPaths.contains(path) {
            let url = URL(fileURLWithPath: path)
            SecurityBookmarks.shared.removeBookmark(for: url)
            watchedPaths.remove(path)
            print("[WATCHER] Видалено папку з відстеження: \(path)")
            
            let activeProfile = "Home"
            UserDefaults.standard.set(Array(watchedPaths), forKey: "watcher_paths_\(activeProfile)")
            
            restartStream()
        }
    }
    
    /// Відновити відстеження всіх папок, збережених у UserDefaults
    public func restoreAllWatchedFolders() {
        let activeProfile = "Home"
        let savedPaths = UserDefaults.standard.stringArray(forKey: "watcher_paths_\(activeProfile)") ?? []
        
        let urls = SecurityBookmarks.shared.restoreAllBookmarks()
        for url in urls {
            if savedPaths.contains(url.path) && watchedPaths.count < maxWatchFolders {
                SecurityBookmarks.shared.startAccessing(url)
                watchedPaths.insert(url.path)
                print("[WATCHER] Відновлено папку: \(url.path)")
            }
        }
        
        // Якщо це перший запуск і збережених папок немає, але є закладки, мігруємо їх у Home
        if savedPaths.isEmpty && !urls.isEmpty && activeProfile == "Home" {
            for url in urls {
                if watchedPaths.count < maxWatchFolders {
                    SecurityBookmarks.shared.startAccessing(url)
                    watchedPaths.insert(url.path)
                }
            }
            UserDefaults.standard.set(Array(watchedPaths), forKey: "watcher_paths_Home")
        }
        
        if !watchedPaths.isEmpty {
            restartStream()
        }
    }
    
    /// Тимчасово призупинити відстеження всіх папок
    public func pauseAll() {
        isPaused = true
        if let stream = stream {
            FSEventStreamStop(stream)
            print("[WATCHER] Призупинено моніторинг усіх папок")
        }
    }
    
    /// Відновити відстеження після паузи
    public func resumeAll() {
        isPaused = false
        if let stream = stream {
            FSEventStreamStart(stream)
            print("[WATCHER] Відновлено моніторинг усіх папок")
        } else {
            restartStream()
        }
    }
    
    /// Перезапуск FSEvents стріму з актуальним набором шляхів
    private func restartStream() {
        // Зупиняємо та очищаємо поточний стрім
        stopStream()
        
        guard !watchedPaths.isEmpty, !isPaused else { return }
        
        let pathsToWatch = Array(watchedPaths) as CFArray
        let latency: CFTimeInterval = 1.0 // Об'єднувати події за 1 секунду
        
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        // Створюємо новий стрім FSEvents
        // Використовуємо:
        // - kFSEventStreamCreateFlagUseCFTypes: передає масив CFString замість char**
        // - kFSEventStreamCreateFlagFileEvents: повідомляє про події створення/зміни окремих файлів
        guard let newStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            fsEventsCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else {
            print("[WATCHER] Не вдалося створити FSEventStream")
            return
        }
        
        stream = newStream
        FSEventStreamSetDispatchQueue(newStream, queue)
        FSEventStreamStart(newStream)
        print("[WATCHER] Запущено відстеження для папок: \(watchedPaths)")
    }
    
    /// Зупинка та очищення пам'яті поточного стріму
    private func stopStream() {
        if let currentStream = stream {
            FSEventStreamStop(currentStream)
            FSEventStreamInvalidate(currentStream)
            FSEventStreamRelease(currentStream)
            stream = nil
            print("[WATCHER] Зупинено та вивільнено FSEventStream")
        }
    }
    
    /// Зупинка всього моніторингу
    public func shutdown() {
        stopStream()
        SecurityBookmarks.shared.stopAllAccess()
        watchedPaths.removeAll()
    }
    
    /// Обробка викликаних подій файлової системи
    internal func processEvents(paths: [String]) {
        // Фільтруємо приховані системні файли (.DS_Store тощо) та перевіряємо наявність файлів
        let filteredPaths = paths.filter { path in
            let url = URL(fileURLWithPath: path)
            let name = url.lastPathComponent
            if name.hasPrefix(".") {
                return false
            }
            return true
        }
        
        guard !filteredPaths.isEmpty else { return }
        
        print("[WATCHER] Зафіксовано події для файлів: \(filteredPaths)")
        
        // Викликаємо callback
        if let onEvents = onEvents {
            onEvents(filteredPaths)
        }
    }
    
    deinit {
        shutdown()
    }
}
