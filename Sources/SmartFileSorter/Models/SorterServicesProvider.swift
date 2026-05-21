import AppKit
import Foundation

@objc public final class SorterServicesProvider: NSObject {
    @objc public func applySorterRuleService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let types = pboard.types, types.contains(.fileURL) else { return }
        
        var urls: [URL] = []
        if let items = pboard.pasteboardItems {
            for item in items {
                if let urlString = item.string(forType: .fileURL), let url = URL(string: urlString) {
                    urls.append(url)
                }
            }
        }
        
        guard !urls.isEmpty else { return }
        
        Task {
            let categories: [String: Bool] = [
                "Зображення": true,
                "Відео": true,
                "Документи": true,
                "Аудіо": true,
                "Архіви": true,
                "Інші файли": true
            ]
            
            for url in urls {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        let stream = SorterEngine.shared.sortFiles(
                            folderPath: url.path,
                            sortMode: .type,
                            categories: categories,
                            dryRun: false,
                            detectDuplicates: true
                        )
                        for await _ in stream {}
                    } else {
                        RuleEngine.shared.loadRules()
                        for rule in RuleEngine.shared.rules {
                            if rule.enabled && RuleEngine.shared.match(rule: rule, for: url) {
                                _ = RuleEngine.shared.execute(rule: rule, for: url)
                            }
                        }
                    }
                }
            }
        }
    }
}
