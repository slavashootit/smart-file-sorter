import Foundation
import AppKit
import CoreSpotlight
import ImageIO
import Vision
import PDFKit

public enum ConditionType: String, Codable, CaseIterable {
    case nameMatches
    case extensionIs
    case kindIs
    case sizeGreaterThan
    case sizeLessThan
    case sizeEquals
    case dateAddedWithinDays
    case dateModifiedWithinDays
    // Нові умови v1.5:
    case sourceURLMatches
    case filenameMatchesRegex
    case lastOpenedWithinDays
    case hasTag
    case doesNotHaveTag
    case parentFolderIs
    case ocrTextContains
}

public enum LogicalOperator: String, Codable {
    case and
    case or
}

public enum FileKind: String, Codable, CaseIterable {
    case image
    case video
    case doc
    case audio
    case archive
    case other
}

public struct RuleCondition: Codable, Equatable {
    // Для звичайних умов
    public var type: ConditionType?
    public var value: String?
    
    // Для груп (nested AND/OR)
    public var logicalOperator: LogicalOperator?
    public var subconditions: [RuleCondition]?
    
    public init(type: ConditionType, value: String) {
        self.type = type
        self.value = value
        self.logicalOperator = nil
        self.subconditions = nil
    }
    
    public init(logicalOperator: LogicalOperator, subconditions: [RuleCondition]) {
        self.type = nil
        self.value = nil
        self.logicalOperator = logicalOperator
        self.subconditions = subconditions
    }
}

public enum ActionType: String, Codable, CaseIterable {
    case moveTo
    case copyTo
    case rename
    // Нові дії v1.5:
    case addTag
    case removeTag
    case archiveToZIP
    case openWith
    case moveToTrash
    case runAppleScript
}

public struct RuleAction: Codable, Equatable {
    public var type: ActionType
    public var value: String
    
    public init(type: ActionType, value: String) {
        self.type = type
        self.value = value
    }
}

public struct Rule: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var enabled: Bool
    public var conditions: [RuleCondition]
    public var actions: [RuleAction]
    
    public init(id: UUID = UUID(), name: String, enabled: Bool = true, conditions: [RuleCondition] = [], actions: [RuleAction] = []) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.conditions = conditions
        self.actions = actions
    }
}

/// Ядро обробки та виконання правил сортування файлів
public class RuleEngine {
    
    public static let shared = RuleEngine()
    
    public var rules: [Rule] = []
    
    // Словник розширень за типами
    private let kindExtensions: [FileKind: Set<String>] = [
        .image: ["jpg", "jpeg", "png", "gif", "bmp", "heic", "tiff", "svg", "webp"],
        .video: ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"],
        .doc: ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "key"],
        .audio: ["mp3", "wav", "m4a", "flac", "aac", "ogg", "wma"],
        .archive: ["zip", "rar", "7z", "tar", "gz", "bz2", "dmg", "iso"]
    ]
    
    public var rulesDirectoryURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SmartSorter")
    }
    
    public var rulesFileURL: URL {
        let fileManager = FileManager.default
        let url = rulesDirectoryURL.appendingPathComponent("rules.json")
        
        // v1.5.1 migration: rules_Home.json → rules.json
        if !fileManager.fileExists(atPath: url.path) {
            let legacyURL = rulesDirectoryURL.appendingPathComponent("rules_Home.json")
            if fileManager.fileExists(atPath: legacyURL.path) {
                try? fileManager.moveItem(at: legacyURL, to: url)
                print("[RULES] Мігровано rules_Home.json → rules.json")
            }
        }
        return url
    }
    
    public init() {
        loadRules()
    }
    
    /// Завантаження правил з rules.json
    public func loadRules() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: rulesFileURL.path) {
            self.rules = []
            return
        }
        do {
            let data = try Data(contentsOf: rulesFileURL)
            self.rules = try JSONDecoder().decode([Rule].self, from: data)
            print("[RULES] Завантажено \(rules.count) правил")
            indexRulesInSpotlight()
        } catch {
            print("[RULES] Помилка завантаження правил: \(error.localizedDescription)")
            self.rules = []
        }
    }
    
    /// Збереження правил в rules.json
    public func saveRules() {
        let fileManager = FileManager.default
        do {
            if !fileManager.fileExists(atPath: rulesDirectoryURL.path) {
                try fileManager.createDirectory(at: rulesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(rules)
            try data.write(to: rulesFileURL, options: .atomic)
            print("[RULES] Правила успішно збережено в rules.json")
            indexRulesInSpotlight()
        } catch {
            print("[RULES] Помилка збереження правил: \(error.localizedDescription)")
        }
    }
    
    /// Spotlight Indexing
    public func indexRulesInSpotlight() {
        var searchableItems: [CSSearchableItem] = []
        
        for rule in rules {
            let attributeSet = CSSearchableItemAttributeSet(itemContentType: "text")
            attributeSet.title = rule.name
            let enabledStr = rule.enabled ? "увімкнено" : "вимкнено"
            attributeSet.contentDescription = "Правило сортування (\(enabledStr)): \(rule.conditions.count) умов, \(rule.actions.count) дій"
            
            let item = CSSearchableItem(
                uniqueIdentifier: "rule_\(rule.id.uuidString)",
                domainIdentifier: "com.slavashootit.smart-file-sorter.rules",
                attributeSet: attributeSet
            )
            searchableItems.append(item)
        }
        
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("[SPOTLIGHT] Помилка індексування: \(error.localizedDescription)")
            } else {
                print("[SPOTLIGHT] Успішно проіндексовано \(searchableItems.count) правил")
            }
        }
    }
    
    /// Отримання першоджерела завантаження файлу (Source URL) з метаданих
    private func getSourceURL(for fileURL: URL) -> String? {
        let path = fileURL.path as CFString
        guard let item = MDItemCreate(kCFAllocatorDefault, path) else { return nil }
        let kMDItemWhereFroms = "kMDItemWhereFroms" as CFString
        guard let attributes = MDItemCopyAttribute(item, kMDItemWhereFroms) as? [String] else { return nil }
        return attributes.joined(separator: " ")
    }
    
    /// Отримання дати останнього відкриття файлу
    private func getLastUsedDate(for fileURL: URL) -> Date? {
        if let values = try? fileURL.resourceValues(forKeys: [.contentAccessDateKey]), let date = values.contentAccessDate {
            return date
        }
        let path = fileURL.path as CFString
        let kMDItemLastUsedDate = "kMDItemLastUsedDate" as CFString
        if let item = MDItemCreate(kCFAllocatorDefault, path),
           let date = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date {
            return date
        }
        return nil
    }
    
    /// Оцінка окремої умови для файлу
    public func evaluate(condition: RuleCondition, for fileURL: URL) -> Bool {
        // Оцінка вкладених логічних груп (AND/OR)
        if let op = condition.logicalOperator, let subs = condition.subconditions {
            if subs.isEmpty { return true }
            if op == .and {
                return subs.allSatisfy { evaluate(condition: $0, for: fileURL) }
            } else {
                return subs.contains { evaluate(condition: $0, for: fileURL) }
            }
        }
        
        guard let type = condition.type, let value = condition.value else { return false }
        let fileManager = FileManager.default
        
        switch type {
        case .nameMatches:
            let filename = fileURL.lastPathComponent
            return filename.localizedCaseInsensitiveContains(value)
            
        case .extensionIs:
            let ext = fileURL.pathExtension.lowercased()
            return ext == value.lowercased()
            
        case .kindIs:
            guard let kind = FileKind(rawValue: value) else { return false }
            let ext = fileURL.pathExtension.lowercased()
            if kind == .other {
                for extensions in kindExtensions.values {
                    if extensions.contains(ext) {
                        return false
                    }
                }
                return true
            } else {
                return kindExtensions[kind]?.contains(ext) ?? false
            }
            
        case .sizeGreaterThan, .sizeLessThan, .sizeEquals:
            guard let expectedSize = Int64(value),
                  let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let size = attrs[.size] as? Int64 else {
                return false
            }
            if type == .sizeGreaterThan {
                return size > expectedSize
            } else if type == .sizeLessThan {
                return size < expectedSize
            } else {
                return size == expectedSize
            }
            
        case .dateAddedWithinDays, .dateModifiedWithinDays:
            guard let days = Int(value),
                  let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path) else {
                return false
            }
            let key: FileAttributeKey = (type == .dateAddedWithinDays) ? .creationDate : .modificationDate
            guard let date = attrs[key] as? Date else { return false }
            
            let daysDifference = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 999
            return daysDifference <= days
            
        case .sourceURLMatches:
            guard let sourceURLStr = getSourceURL(for: fileURL) else { return false }
            return sourceURLStr.localizedCaseInsensitiveContains(value)
            
        case .filenameMatchesRegex:
            guard let regex = try? NSRegularExpression(pattern: value, options: [.caseInsensitive]) else {
                return false
            }
            let filename = fileURL.lastPathComponent
            let range = NSRange(location: 0, length: filename.utf16.count)
            return regex.firstMatch(in: filename, options: [], range: range) != nil
            
        case .lastOpenedWithinDays:
            guard let days = Int(value),
                  let accessDate = getLastUsedDate(for: fileURL) else {
                return false
            }
            let daysDifference = Calendar.current.dateComponents([.day], from: accessDate, to: Date()).day ?? 999
            return daysDifference <= days
            
        case .hasTag:
            let values = try? fileURL.resourceValues(forKeys: [.tagNamesKey])
            let tags = values?.tagNames ?? []
            return tags.contains { $0.localizedCaseInsensitiveContains(value) }
            
        case .doesNotHaveTag:
            let values = try? fileURL.resourceValues(forKeys: [.tagNamesKey])
            let tags = values?.tagNames ?? []
            return !tags.contains { $0.localizedCaseInsensitiveContains(value) }
            
        case .parentFolderIs:
            let parentName = fileURL.deletingLastPathComponent().lastPathComponent
            return parentName.localizedCaseInsensitiveContains(value)
            
        case .ocrTextContains:
            let text = performOCR(for: fileURL)
            return text.localizedCaseInsensitiveContains(value)
        }
    }
    
    /// Виконання OCR для файлу (збереження у SQLite кеш)
    private func performOCR(for fileURL: URL) -> String {
        if let cachedText = OCRDatabase.shared.getCachedText(for: fileURL) {
            return cachedText
        }
        
        let ext = fileURL.pathExtension.lowercased()
        let supportedExtensions = ["png", "jpg", "jpeg", "tiff", "pdf", "heic"]
        guard supportedExtensions.contains(ext) else { return "" }
        
        var recognizedText = ""
        
        if ext == "pdf" {
            if let document = PDFDocument(url: fileURL) {
                var pdfText = ""
                for i in 0..<document.pageCount {
                    if let page = document.page(at: i), let text = page.string {
                        pdfText += text + "\n"
                    }
                }
                recognizedText = pdfText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if recognizedText.isEmpty {
            let requestHandler = VNImageRequestHandler(url: fileURL, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                recognizedText += text
            }
            request.recognitionLevel = .accurate
            try? requestHandler.perform([request])
        }
        
        OCRDatabase.shared.cacheText(recognizedText, for: fileURL)
        return recognizedText
    }
    
    /// Перевірка чи файл відповідає ВСІМ умовам правила
    public func match(rule: Rule, for fileURL: URL) -> Bool {
        guard rule.enabled, !rule.conditions.isEmpty else { return false }
        for cond in rule.conditions {
            if !evaluate(condition: cond, for: fileURL) {
                return false
            }
        }
        return true
    }
    
    /// Заміна токенів у шаблоні перейменування
    public func replaceTokens(in template: String, for fileURL: URL) -> String {
        let fileManager = FileManager.default
        let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path)
        let modDate = (attrs?[.modificationDate] as? Date) ?? Date()
        
        let calendar = Calendar.current
        let year = String(format: "%04d", calendar.component(.year, from: modDate))
        let month = String(format: "%02d", calendar.component(.month, from: modDate))
        let day = String(format: "%02d", calendar.component(.day, from: modDate))
        
        let ext = fileURL.pathExtension
        let filename = fileURL.deletingPathExtension().lastPathComponent
        
        var cameraModel = "Unknown_Camera"
        if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
           let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
           let tiffProperties = imageProperties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let model = tiffProperties[kCGImagePropertyTIFFModel] as? String {
            cameraModel = model.replacingOccurrences(of: " ", with: "_")
        }
        
        var result = template
        result = result.replacingOccurrences(of: "%filename%", with: filename)
        result = result.replacingOccurrences(of: "%ext%", with: ext)
        result = result.replacingOccurrences(of: "%YYYY%", with: year)
        result = result.replacingOccurrences(of: "%MM%", with: month)
        result = result.replacingOccurrences(of: "%DD%", with: day)
        result = result.replacingOccurrences(of: "%camera%", with: cameraModel)
        return result
    }
    
    /// Виконання дій правила для файлу
    public func execute(rule: Rule, for fileURL: URL) -> (success: Bool, finalURL: URL, logs: [String]) {
        var currentURL = fileURL
        var logs: [String] = []
        let fileManager = FileManager.default
        
        for action in rule.actions {
            switch action.type {
            case .moveTo, .copyTo:
                let destDir = URL(fileURLWithPath: action.value)
                let destFile = destDir.appendingPathComponent(currentURL.lastPathComponent)
                let finalDest = uniquePath(for: destFile)
                
                do {
                    if !fileManager.fileExists(atPath: destDir.path) {
                        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)
                    }
                    if action.type == .moveTo {
                        try fileManager.moveItem(at: currentURL, to: finalDest)
                        logs.append("[ПРАВИЛО: \(rule.name)] Переміщено '\(currentURL.lastPathComponent)' -> '\(finalDest.path)'")
                        currentURL = finalDest
                    } else {
                        try fileManager.copyItem(at: currentURL, to: finalDest)
                        logs.append("[ПРАВИЛО: \(rule.name)] Скопійовано '\(currentURL.lastPathComponent)' -> '\(finalDest.path)'")
                    }
                } catch {
                    logs.append("[ПРАВИЛО: \(rule.name)] Помилка виконання \(action.type.rawValue) для '\(currentURL.lastPathComponent)': \(error.localizedDescription)")
                    return (false, currentURL, logs)
                }
                
            case .rename:
                let newName = replaceTokens(in: action.value, for: currentURL)
                let destURL = currentURL.deletingLastPathComponent().appendingPathComponent(newName)
                let finalDest = uniquePath(for: destURL)
                
                do {
                    try fileManager.moveItem(at: currentURL, to: finalDest)
                    logs.append("[ПРАВИЛО: \(rule.name)] Перейменовано '\(currentURL.lastPathComponent)' -> '\(finalDest.lastPathComponent)'")
                    currentURL = finalDest
                } catch {
                    logs.append("[ПРАВИЛО: \(rule.name)] Помилка перейменування для '\(currentURL.lastPathComponent)': \(error.localizedDescription)")
                    return (false, currentURL, logs)
                }
                
            case .addTag, .removeTag:
                do {
                    let resourceValues = try currentURL.resourceValues(forKeys: [.tagNamesKey])
                    var tags = resourceValues.tagNames ?? []
                    if action.type == .addTag {
                        if !tags.contains(action.value) {
                            tags.append(action.value)
                        }
                    } else {
                        tags.removeAll { $0.lowercased() == action.value.lowercased() }
                    }
                    try (currentURL as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
                    logs.append("[ПРАВИЛО: \(rule.name)] Оновлено теги для '\(currentURL.lastPathComponent)': \(tags)")
                } catch {
                    logs.append("[ПРАВИЛО: \(rule.name)] Помилка оновлення тегів для '\(currentURL.lastPathComponent)': \(error.localizedDescription)")
                }
                
            case .archiveToZIP:
                let zipURL = currentURL.deletingPathExtension().appendingPathExtension("zip")
                let uniqueZip = uniquePath(for: zipURL)
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-c", "-k", "--sequesterRsrc", currentURL.path, uniqueZip.path]
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        // Видаляємо оригінал після успішної архівації
                        try fileManager.removeItem(at: currentURL)
                        logs.append("[ПРАВИЛО: \(rule.name)] Архівовано '\(currentURL.lastPathComponent)' -> '\(uniqueZip.path)'")
                        currentURL = uniqueZip
                    } else {
                        logs.append("[ПРАВИЛО: \(rule.name)] Помилка архівації (ditto exit code: \(process.terminationStatus))")
                    }
                } catch {
                    logs.append("[ПРАВИЛО: \(rule.name)] Помилка запуску ditto для архівації: \(error.localizedDescription)")
                }
                
            case .openWith:
                let appURL = URL(fileURLWithPath: action.value)
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([currentURL], withApplicationAt: appURL, configuration: config, completionHandler: nil)
                logs.append("[ПРАВИЛО: \(rule.name)] Відкрито '\(currentURL.lastPathComponent)' за допомогою \(action.value)")
                
            case .moveToTrash:
                do {
                    var trashURL: NSURL?
                    try fileManager.trashItem(at: currentURL, resultingItemURL: &trashURL)
                    if let res = trashURL as URL? {
                        logs.append("[ПРАВИЛО: \(rule.name)] Перенесено в Кошик '\(currentURL.lastPathComponent)' -> '\(res.path)'")
                        currentURL = res
                    } else {
                        logs.append("[ПРАВИЛО: \(rule.name)] Перенесено в Кошик '\(currentURL.lastPathComponent)'")
                    }
                } catch {
                    logs.append("[ПРАВИЛО: \(rule.name)] Помилка перенесення в Кошик '\(currentURL.lastPathComponent)': \(error.localizedDescription)")
                }
                
            case .runAppleScript:
                if let script = NSAppleScript(source: action.value) {
                    var errorInfo: NSDictionary?
                    script.executeAndReturnError(&errorInfo)
                    if let err = errorInfo {
                        logs.append("[ПРАВИЛО: \(rule.name)] Помилка AppleScript: \(err)")
                    } else {
                        logs.append("[ПРАВИЛО: \(rule.name)] Успішно запущено AppleScript")
                    }
                } else {
                    logs.append("[ПРАВИЛО: \(rule.name)] Не вдалося ініціалізувати AppleScript")
                }
            }
        }
        
        return (true, currentURL, logs)
    }
    
    /// Допоміжний метод для уникнення перезапису файлів
    private func uniquePath(for url: URL) -> URL {
        let fileManager = FileManager.default
        var newURL = url
        var count = 1
        let ext = url.pathExtension
        let baseName = url.deletingPathExtension().lastPathComponent
        let dir = url.deletingLastPathComponent()
        
        while fileManager.fileExists(atPath: newURL.path) {
            let name = ext.isEmpty ? "\(baseName)_\(count)" : "\(baseName)_\(count).\(ext)"
            newURL = dir.appendingPathComponent(name)
            count += 1
        }
        return newURL
    }
    
    /// Детектор конфліктів правил
    public func detectConflicts() -> [String] {
        var warnings: [String] = []
        
        // 1. Пошук правил, які мають однакові умови, але різні дії moveTo/copyTo
        for i in 0..<rules.count {
            for j in (i+1)..<rules.count {
                let ruleA = rules[i]
                let ruleB = rules[j]
                
                guard ruleA.enabled && ruleB.enabled else { continue }
                
                // Перевіряємо умови на ідентичність
                if ruleA.conditions == ruleB.conditions {
                    let moveActionsA = ruleA.actions.filter { $0.type == .moveTo || $0.type == .copyTo }
                    let moveActionsB = ruleB.actions.filter { $0.type == .moveTo || $0.type == .copyTo }
                    
                    for actA in moveActionsA {
                        for actB in moveActionsB {
                            if actA.value != actB.value {
                                warnings.append("Правило '\(ruleA.name)' та '\(ruleB.name)' мають однакові умови, але переміщують файли в різні папки: '\(actA.value)' та '\(actB.value)'.")
                            }
                        }
                    }
                }
            }
        }
        
        return warnings
    }
}
