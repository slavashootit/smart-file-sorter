import Foundation

/// Менеджер закладок безпеки (Security-Scoped Bookmarks) для доступу до папок
/// поза межами пісочниці (Sandbox) після перезапуску додатку.
public class SecurityBookmarks {
    
    public static let shared = SecurityBookmarks()
    
    private let defaultsKey = "smart_file_sorter_bookmarks"
    private var activeAccessURLs: [String: URL] = [:]
    
    public init() {}
    
    /// Збереження закладки безпеки для конкретної папки
    /// - Parameter url: URL папки, отриманої через NSOpenPanel
    /// - Returns: True, якщо збережено успішно
    @discardableResult
    public func saveBookmark(for url: URL) -> Bool {
        do {
            var data: Data
            do {
                data = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                // Відкат для не-Sandbox оточення
                data = try url.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }
            var bookmarks = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data] ?? [:]
            bookmarks[url.path] = data
            UserDefaults.standard.set(bookmarks, forKey: defaultsKey)
            return true
        } catch {
            print("[SECURITY] Помилка створення закладки для \(url.path): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Видалення збереженої закладки папки
    /// - Parameter url: URL папки
    public func removeBookmark(for url: URL) {
        stopAccessing(url)
        var bookmarks = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data] ?? [:]
        bookmarks.removeValue(forKey: url.path)
        UserDefaults.standard.set(bookmarks, forKey: defaultsKey)
    }
    
    /// Отримання списку всіх збережених папок
    /// - Returns: Масив URL
    public func restoreAllBookmarks() -> [URL] {
        guard let bookmarks = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data] else {
            return []
        }
        
        var restoredURLs: [URL] = []
        for (path, data) in bookmarks {
            do {
                var isStale = false
                var url: URL
                do {
                    url = try URL(
                        resolvingBookmarkData: data,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                } catch {
                    // Відкат для не-Sandbox оточення
                    url = try URL(
                        resolvingBookmarkData: data,
                        options: [],
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                }
                if isStale {
                    print("[SECURITY] Оновлення застарілої закладки для \(path)")
                    saveBookmark(for: url)
                }
                restoredURLs.append(url)
            } catch {
                print("[SECURITY] Не вдалося відновити закладку для \(path): \(error.localizedDescription)")
            }
        }
        return restoredURLs
    }
    
    /// Початок використання прав доступу до папки
    /// - Parameter url: URL папки
    /// - Returns: True, якщо права отримано успішно
    @discardableResult
    public func startAccessing(_ url: URL) -> Bool {
        // Якщо це звичайне оточення без пісочниці, startAccessingSecurityScopedResource може повернути false,
        // але доступ все одно буде через звичайні права ФС. Тому ми завжди реєструємо у списку активних.
        let success = url.startAccessingSecurityScopedResource()
        activeAccessURLs[url.path] = url
        print("[SECURITY] Запущено доступ до ресурсу: \(url.path) (Результат: \(success))")
        return success
    }
    
    /// Припинення використання прав доступу до папки
    /// - Parameter url: URL папки
    public func stopAccessing(_ url: URL) {
        if let activeURL = activeAccessURLs[url.path] {
            activeURL.stopAccessingSecurityScopedResource()
            activeAccessURLs.removeValue(forKey: url.path)
            print("[SECURITY] Зупинено доступ до ресурсу: \(url.path)")
        }
    }
    
    /// Припинення доступу до всіх відкритих папок
    public func stopAllAccess() {
        for (_, url) in activeAccessURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeAccessURLs.removeAll()
        print("[SECURITY] Закрито всі активні сесії доступу")
    }
}
