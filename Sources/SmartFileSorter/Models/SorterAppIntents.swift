import AppIntents
import Foundation

@available(macOS 13.0, *)
public struct SortFolderIntent: AppIntent {
    public static var title: LocalizedStringResource = "Sort Folder"
    public static var description = IntentDescription("Sorts files in the specified folder using type or date mode.")

    @Parameter(title: "Folder URL")
    public var folder: URL

    @Parameter(title: "Sort Mode", default: "type")
    public var sortMode: String // "type" or "date"

    public static var parameterSummary: some ParameterSummary {
        Summary("Sort \(\.$folder) by \(\.$sortMode)")
    }

    public init() {}

    public init(folder: URL, sortMode: String) {
        self.folder = folder
        self.sortMode = sortMode
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let mode: SortMode = (sortMode.lowercased() == "date") ? .date : .type
        
        let categories: [String: Bool] = [
            "Зображення": true,
            "Відео": true,
            "Документи": true,
            "Аудіо": true,
            "Архіви": true,
            "Інші файли": true
        ]
        
        let logs = SorterEngine.shared.sortFiles(
            folderPath: folder.path,
            sortMode: mode,
            categories: categories,
            dryRun: false,
            detectDuplicates: true
        )
        
        let resultSummary = logs.joined(separator: "\n")
        return .result(value: resultSummary)
    }
}

@available(macOS 13.0, *)
public struct ApplyRuleIntent: AppIntent {
    public static var title: LocalizedStringResource = "Apply Rule"
    public static var description = IntentDescription("Applies a specific rule by name to files in a folder.")

    @Parameter(title: "Rule Name")
    public var ruleName: String

    @Parameter(title: "Folder URL")
    public var folder: URL

    public static var parameterSummary: some ParameterSummary {
        Summary("Apply rule \(\.$ruleName) on folder \(\.$folder)")
    }

    public init() {}

    public init(ruleName: String, folder: URL) {
        self.ruleName = ruleName
        self.folder = folder
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        RuleEngine.shared.loadRules()
        guard let rule = RuleEngine.shared.rules.first(where: { $0.name.lowercased() == ruleName.lowercased() }) else {
            return .result(value: "Rule '\(ruleName)' not found.")
        }
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return .result(value: "Failed to read folder.")
        }
        
        var matchCount = 0
        var successCount = 0
        var allLogs: [String] = []
        
        for case let fileURL as URL in enumerator {
            if RuleEngine.shared.match(rule: rule, for: fileURL) {
                matchCount += 1
                let res = RuleEngine.shared.execute(rule: rule, for: fileURL)
                if res.success {
                    successCount += 1
                }
                allLogs.append(contentsOf: res.logs)
            }
        }
        
        let summary = "Applied '\(ruleName)': found \(matchCount) matches, processed \(successCount) successfully.\n" + allLogs.joined(separator: "\n")
        return .result(value: summary)
    }
}

@available(macOS 13.0, *)
public struct FindDuplicatesIntent: AppIntent {
    public static var title: LocalizedStringResource = "Find Duplicates"
    public static var description = IntentDescription("Finds duplicate files in a folder.")

    @Parameter(title: "Folder URL")
    public var folder: URL

    public static var parameterSummary: some ParameterSummary {
        Summary("Find duplicates in \(\.$folder)")
    }

    public init() {}

    public init(folder: URL) {
        self.folder = folder
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let finder = DuplicateFinder()
        
        let groups: [DuplicateGroup] = await withCheckedContinuation { continuation in
            finder.scan(at: folder.path) {
                continuation.resume(returning: finder.duplicateGroups)
            }
        }
        
        if groups.isEmpty {
            return .result(value: "No duplicates found.")
        }
        
        var summary = "Found \(groups.count) groups of duplicates:\n"
        for group in groups {
            if let firstFile = group.files.first {
                let sizeStr = ByteCountFormatter.string(fromByteCount: group.fileSize, countStyle: .file)
                summary += "- \(firstFile.lastPathComponent): \(group.files.count) copies, \(sizeStr) each\n"
                for file in group.files {
                    summary += "  Path: \(file.path)\n"
                }
            }
        }
        return .result(value: summary)
    }
}

@available(macOS 13.0, *)
public struct GetSorterStatisticsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Get Sorter Statistics"
    public static var description = IntentDescription("Returns sorting statistics as a JSON string.")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let manualFreed = UserDefaults.standard.double(forKey: "FreedBytesTotal")
        let manualDuplicates = UserDefaults.standard.integer(forKey: "FreedDuplicatesCount")
        
        let batches = HistoryManager.shared.getBatches()
        let totalSpaceOrganized = batches.reduce(0) { sum, batch in
            sum + batch.operations.reduce(0) { $0 + $1.fileSize }
        }
        let sortingFreed = batches.reduce(0) { sum, batch in
            sum + batch.operations.filter { $0.isTrashed }.reduce(0) { $0 + $1.fileSize }
        }
        let totalSpaceFreed = sortingFreed + Int64(manualFreed)
        
        let sortingDuplicates = batches.reduce(0) { sum, batch in
            sum + batch.operations.filter { $0.isTrashed }.count
        }
        let totalDuplicatesRemoved = sortingDuplicates + manualDuplicates
        let totalFilesSorted = batches.reduce(0) { $0 + $1.operations.count }
        
        let stats: [String: Any] = [
            "totalFilesSorted": totalFilesSorted,
            "totalSpaceOrganizedBytes": totalSpaceOrganized,
            "totalSpaceFreedBytes": totalSpaceFreed,
            "totalDuplicatesRemovedCount": totalDuplicatesRemoved
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: stats, options: .prettyPrinted),
           let jsonString = String(data: data, encoding: .utf8) {
            return .result(value: jsonString)
        }
        
        return .result(value: "Failed to serialize statistics.")
    }
}

@available(macOS 13.0, *)
public struct SorterShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: SortFolderIntent(),
                phrases: [
                    "Sort folder \(\.$folder) in \(.applicationName)",
                    "Сортувати \(\.$folder) в \(.applicationName)"
                ],
                shortTitle: "Sort Folder",
                systemImageName: "folder.badge.gearshape"
            ),
            AppShortcut(
                intent: ApplyRuleIntent(),
                phrases: [
                    "Apply rule \(\.$ruleName) in \(.applicationName)",
                    "Застосувати правило \(\.$ruleName) в \(.applicationName)"
                ],
                shortTitle: "Apply Rule",
                systemImageName: "rule"
            ),
            AppShortcut(
                intent: FindDuplicatesIntent(),
                phrases: [
                    "Find duplicates in \(\.$folder) in \(.applicationName)",
                    "Знайти дублікати в \(\.$folder) в \(.applicationName)"
                ],
                shortTitle: "Find Duplicates",
                systemImageName: "doc.on.doc"
            ),
            AppShortcut(
                intent: GetSorterStatisticsIntent(),
                phrases: [
                    "Get statistics from \(.applicationName)",
                    "Отримати статистику з \(.applicationName)"
                ],
                shortTitle: "Get Statistics",
                systemImageName: "chart.bar"
            )
        ]
    }
}
