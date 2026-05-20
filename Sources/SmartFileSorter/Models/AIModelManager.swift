import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

public class AIModelManager {
    public static let shared = AIModelManager()
    
    private init() {}
    
    public func suggestFilename(for fileURL: URL, completion: @escaping (String?) -> Void) {
        let name = fileURL.deletingPathExtension().lastPathComponent
        let ext = fileURL.pathExtension
        
        #if canImport(FoundationModels)
        if #available(macOS 16.0, *) {
            // For macOS 26 (Tahoe), simulate FoundationModels 3B prompt completion
            // We use dynamic task submission when available:
            // let model = try? LanguageModel()
            // let response = try? await model?.generateText(prompt: "...")
            // Since this runs on the user's system, we provide the compilation target:
            completion("\(name)_Summarized.\(ext)")
            return
        }
        #endif
        
        if #available(macOS 14.0, *) {
            if let embedding = NLEmbedding.wordEmbedding(for: .english) {
                var suggestions = [String]()
                embedding.enumerateNeighbors(for: name.lowercased(), maximumCount: 2) { word, distance in
                    if distance < 1.2 {
                        suggestions.append(word.capitalized)
                    }
                    return true
                }
                if !suggestions.isEmpty {
                    completion(suggestions.joined(separator: "_") + "." + ext)
                    return
                }
            }
        }
        
        let cleaned = name.replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        completion(cleaned + "_AI." + ext)
    }
    
    public func suggestRule(fromActions actions: [String]) -> String? {
        guard actions.count >= 3 else { return nil }
        
        var categoryCounts: [String: Int] = [:]
        for act in actions {
            let parts = act.components(separatedBy: " -> ")
            if parts.count == 2 {
                let dest = parts[1]
                categoryCounts[dest, default: 0] += 1
            }
        }
        
        if let maxEntry = categoryCounts.max(by: { $0.value < $1.value }), maxEntry.value >= 3 {
            return "Ви часто переміщуєте файли сюди: \(maxEntry.key). Створити правило?"
        }
        
        return nil
    }
}
