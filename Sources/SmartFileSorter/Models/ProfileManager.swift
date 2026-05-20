import Foundation

public struct Profile: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    
    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

public class ProfileManager: ObservableObject {
    public static let shared = ProfileManager()
    
    @Published public var profiles: [Profile] = []
    @Published public var activeProfile: Profile
    
    private let profilesKey = "sf_profiles"
    private let activeProfileIdKey = "sf_active_profile_id"
    
    public init() {
        // Спочатку ініціалізуємо поля тимчасовими значеннями для дотримання черговості ініціалізації
        let defaultProfiles = [
            Profile(name: "Home"),
            Profile(name: "Work"),
            Profile(name: "Photography")
        ]
        self.profiles = defaultProfiles
        self.activeProfile = defaultProfiles[0]
        
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let loaded = try? decoder.decode([Profile].self, from: data) {
            self.profiles = loaded
        } else {
            saveProfiles()
        }
        
        if let activeIdString = UserDefaults.standard.string(forKey: activeProfileIdKey),
           let activeId = UUID(uuidString: activeIdString),
           let found = self.profiles.first(where: { $0.id == activeId }) {
            self.activeProfile = found
        } else {
            self.activeProfile = self.profiles.first ?? defaultProfiles[0]
            UserDefaults.standard.set(self.activeProfile.id.uuidString, forKey: activeProfileIdKey)
        }
        
        // Встановлюємо в UserDefaults ім'я активного профілю для RuleEngine
        UserDefaults.standard.set(activeProfile.name, forKey: "active_profile")
    }
    
    public func saveProfiles() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
    }
    
    public func addProfile(name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        guard !profiles.contains(where: { $0.name.lowercased() == cleaned.lowercased() }) else { return }
        
        let newProfile = Profile(name: cleaned)
        profiles.append(newProfile)
        saveProfiles()
    }
    
    public func deleteProfile(_ profile: Profile) {
        // Не можна видалити останній профіль
        guard profiles.count > 1 else { return }
        guard let index = profiles.firstIndex(of: profile) else { return }
        
        profiles.remove(at: index)
        saveProfiles()
        
        if activeProfile == profile {
            switchProfile(to: profiles[0])
        }
    }
    
    public func switchProfile(to profile: Profile) {
        guard profiles.contains(profile) else { return }
        
        // 1. Зберігаємо поточний стан (активні папки) старого профілю
        let oldProfileName = activeProfile.name
        let currentWatcherPaths = FSEventsWatcher.shared.getWatchedPaths()
        UserDefaults.standard.set(currentWatcherPaths, forKey: "watcher_paths_\(oldProfileName)")
        
        // 2. Зупиняємо моніторинг старих папок
        for path in currentWatcherPaths {
            FSEventsWatcher.shared.unwatchFolder(path: path)
        }
        
        // 3. Змінюємо активний профіль
        activeProfile = profile
        UserDefaults.standard.set(profile.id.uuidString, forKey: activeProfileIdKey)
        UserDefaults.standard.set(profile.name, forKey: "active_profile")
        
        // 4. Оновлюємо правила в RuleEngine
        RuleEngine.shared.loadRules()
        
        // 5. Відновлюємо та запускаємо моніторинг папок нового профілю
        let newProfilePaths = UserDefaults.standard.stringArray(forKey: "watcher_paths_\(profile.name)") ?? []
        for path in newProfilePaths {
            _ = FSEventsWatcher.shared.watchFolder(path: path)
        }
        
        print("[PROFILES] Переключено на профіль: \(profile.name)")
    }
}
