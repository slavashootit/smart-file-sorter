import Foundation

public enum DuplicateSelectionPattern: String, Codable {
    case older
    case newer
    case size
    case none
}

public class SmartSelectionLearner {
    public static let shared = SmartSelectionLearner()
    
    private let defaultsKeyCount = "smart_selection_pattern_counts"
    private let defaultsKeyApproved = "smart_selection_approved"
    private let defaultsKeyPattern = "smart_selection_current_pattern"
    
    private init() {}
    
    public func logUserSelection(_ pattern: DuplicateSelectionPattern) {
        guard pattern != .none else { return }
        
        var counts = UserDefaults.standard.dictionary(forKey: defaultsKeyCount) as? [String: Int] ?? [:]
        counts[pattern.rawValue, default: 0] += 1
        UserDefaults.standard.set(counts, forKey: defaultsKeyCount)
        
        if let count = counts[pattern.rawValue], count >= 5 {
            let currentApproved = UserDefaults.standard.bool(forKey: defaultsKeyApproved)
            let activePattern = UserDefaults.standard.string(forKey: defaultsKeyPattern)
            
            if !currentApproved || activePattern != pattern.rawValue {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SmartSelectionSuggestion"),
                    object: pattern
                )
            }
        }
    }
    
    public func approvePattern(_ pattern: DuplicateSelectionPattern) {
        UserDefaults.standard.set(pattern.rawValue, forKey: defaultsKeyPattern)
        UserDefaults.standard.set(true, forKey: defaultsKeyApproved)
    }
    
    public func getSuggestedPattern() -> DuplicateSelectionPattern {
        guard UserDefaults.standard.bool(forKey: defaultsKeyApproved),
              let raw = UserDefaults.standard.string(forKey: defaultsKeyPattern),
              let pattern = DuplicateSelectionPattern(rawValue: raw) else {
            return .none
        }
        return pattern
    }
}
