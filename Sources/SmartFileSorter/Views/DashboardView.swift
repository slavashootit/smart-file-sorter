import SwiftUI
import Charts

struct CategoryStat: Identifiable, Equatable {
    let id = UUID()
    let category: String
    let count: Int
    
    static func == (lhs: CategoryStat, rhs: CategoryStat) -> Bool {
        lhs.category == rhs.category && lhs.count == rhs.count
    }
}

struct DateStat: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let count: Int
    
    static func == (lhs: DateStat, rhs: DateStat) -> Bool {
        lhs.date == rhs.date && lhs.count == rhs.count
    }
}

struct DestinationStat: Identifiable, Equatable {
    let id = UUID()
    let folder: String
    let count: Int
    
    static func == (lhs: DestinationStat, rhs: DestinationStat) -> Bool {
        lhs.folder == rhs.folder && lhs.count == rhs.count
    }
}

struct FreedHistoryItem: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let amount: Double
    
    static func == (lhs: FreedHistoryItem, rhs: FreedHistoryItem) -> Bool {
        lhs.date == rhs.date && lhs.amount == rhs.amount
    }
}

struct DashboardStats: Equatable {
    var totalSorted: Int = 0
    var totalSpaceOrganized: Int64 = 0
    var totalSpaceFreed: Int64 = 0
    var totalDuplicatesRemoved: Int = 0
    var categoryStats: [CategoryStat] = []
    var dateStats: [DateStat] = []
    var destinationStats: [DestinationStat] = []
    var spaceFreedHistory: [FreedHistoryItem] = []
}

public struct DashboardView: View {
    @ObservedObject var historyManager = HistoryManager.shared
    
    @State private var showingExportSuccess = false
    @State private var exportPath = ""
    @State private var stats = DashboardStats()
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Заголовок та Експорт
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Аналітика сортування")
                            .font(DT.Font.bodyWeight(24, weight: .bold))
                        Text("Статистика роботи Розумного сортувальника файлів")
                            .font(DT.Font.body(13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: exportToCSV) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Експорт звіту (CSV)")
                        }
                        .font(DT.Font.body(13))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
                
                // Метрики
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    BentoStat(
                        label: "Впорядковано",
                        value: stats.totalSorted,
                        delta: stats.totalSorted > 0 ? "↑ \(stats.dateStats.last?.count ?? 0)" : nil,
                        trend: stats.dateStats.suffix(7).map { Double($0.count) },
                        tint: DT.Color.accent
                    )
                    
                    BentoStat(
                        label: "Організовано",
                        value: Int(stats.totalSpaceOrganized),
                        formattedValue: formatBytes(stats.totalSpaceOrganized),
                        trend: stats.dateStats.suffix(7).map { Double($0.count) },
                        tint: DT.Color.accentStrong
                    )
                    
                    BentoStat(
                        label: "Звільнено простору",
                        value: Int(stats.totalSpaceFreed),
                        formattedValue: formatBytes(stats.totalSpaceFreed),
                        delta: stats.totalSpaceFreed > 0 ? "↑" : nil,
                        trend: stats.spaceFreedHistory.suffix(7).map { $0.amount },
                        tint: DT.Color.success
                    )
                    
                    BentoStat(
                        label: "Видалено копій",
                        value: stats.totalDuplicatesRemoved,
                        trend: stats.spaceFreedHistory.suffix(7).map { $0.amount },
                        tint: DT.Color.warning
                    )
                }
                
                if stats.totalSorted == 0 && stats.totalSpaceFreed == 0 {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Історія операцій відсутня")
                            .font(.headline)
                        Text("Аналітика з'явиться, коли додаток автоматично впорядкує або очистить перші файли.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .liquidGlass(radius: DT.Radius.lg)
                } else {
                    // Сітка графіків
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        // Графік типів
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Розподіл за категоріями")
                                .font(.headline)
                            
                            Chart(stats.categoryStats) { item in
                                BarMark(
                                    x: .value("Кількість", item.count),
                                    y: .value("Категорія", item.category)
                                )
                                .foregroundStyle(by: .value("Категорія", item.category))
                                .cornerRadius(4)
                            }
                            .frame(height: 200)
                        }
                        .padding()
                        .liquidGlass(radius: DT.Radius.lg)
                        
                        // Топ папок
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Топ-5 папок призначення")
                                .font(.headline)
                            
                            Chart(stats.destinationStats) { item in
                                BarMark(
                                    x: .value("Папка", item.folder),
                                    y: .value("Кількість", item.count)
                                )
                                .foregroundStyle(Color.purple)
                                .cornerRadius(4)
                            }
                            .frame(height: 200)
                        }
                        .padding()
                        .liquidGlass(radius: DT.Radius.lg)
                        
                        // Графік динаміки сортування
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Динаміка сортування (останні дні)")
                                .font(.headline)
                            
                            Chart(stats.dateStats) { item in
                                LineMark(
                                    x: .value("Дата", item.date, unit: .day),
                                    y: .value("Файлів", item.count)
                                )
                                .lineStyle(StrokeStyle(lineWidth: 3))
                                .foregroundStyle(Color.blue)
                                
                                AreaMark(
                                    x: .value("Дата", item.date, unit: .day),
                                    y: .value("Файлів", item.count)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.0)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                            .frame(height: 200)
                        }
                        .padding()
                        .liquidGlass(radius: DT.Radius.lg)
                        
                        // Графік динаміки очищення
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Звільнення простору (за днями)")
                                .font(.headline)
                            
                            if stats.spaceFreedHistory.isEmpty {
                                Text("Немає даних для побудови графіка")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            } else {
                                Chart(stats.spaceFreedHistory) { item in
                                    LineMark(
                                        x: .value("Дата", item.date, unit: .day),
                                        y: .value("Звільнено (МБ)", item.amount / (1024 * 1024))
                                    )
                                    .lineStyle(StrokeStyle(lineWidth: 3))
                                    .foregroundStyle(Color.green)
                                    
                                    AreaMark(
                                        x: .value("Дата", item.date, unit: .day),
                                        y: .value("Звільнено (МБ)", item.amount / (1024 * 1024))
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.green.opacity(0.3), Color.green.opacity(0.0)]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                }
                                .frame(height: 200)
                            }
                        }
                        .padding()
                        .liquidGlass(radius: DT.Radius.lg)
                    }
                }
            }
            .padding()
        }
        .task(id: historyManager.getBatches()) {
            await recalculateStats()
        }
        .alert("Звіт успішно збережено", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("CSV файл збережено у:\n\(exportPath)")
        }
    }
    
    private func recalculateStats() async {
        let batches = historyManager.getBatches()
        
        let newStats = await Task.detached(priority: .userInitiated) { () -> DashboardStats in
            let totalSorted = batches.reduce(0) { $0 + $1.operations.count }
            
            let totalSpaceOrganized = batches.reduce(0) { sum, batch in
                sum + batch.operations.reduce(0) { $0 + $1.fileSize }
            }
            
            let sortingFreed = batches.reduce(0) { sum, batch in
                sum + batch.operations.filter { $0.isTrashed }.reduce(0) { $0 + $1.fileSize }
            }
            let manualFreed = UserDefaults.standard.double(forKey: "FreedBytesTotal")
            let totalSpaceFreed = sortingFreed + Int64(manualFreed)
            
            let sortingDuplicates = batches.reduce(0) { sum, batch in
                sum + batch.operations.filter { $0.isTrashed }.count
            }
            let manualDuplicates = UserDefaults.standard.integer(forKey: "FreedDuplicatesCount")
            let totalDuplicatesRemoved = sortingDuplicates + manualDuplicates
            
            // spaceFreedHistory
            let dict = UserDefaults.standard.dictionary(forKey: "freed_history") as? [String: Double] ?? [:]
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            var historyItems: [FreedHistoryItem] = []
            for (dateStr, val) in dict {
                if let date = df.date(from: dateStr) {
                    historyItems.append(FreedHistoryItem(date: date, amount: val))
                }
            }
            historyItems.sort { $0.date < $1.date }
            
            // categoryStats
            var categoryCounts: [String: Int] = [:]
            for batch in batches {
                for op in batch.operations {
                    let category = Self.getCategoryFromPath(op.newPath)
                    categoryCounts[category, default: 0] += 1
                }
            }
            let categoryStats = categoryCounts.map { CategoryStat(category: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
                
            // dateStats
            var dateCounts: [Date: Int] = [:]
            let calendar = Calendar.current
            for batch in batches {
                let day = calendar.startOfDay(for: batch.timestamp)
                dateCounts[day, default: 0] += batch.operations.count
            }
            let dateStats = Array(dateCounts.map { DateStat(date: $0.key, count: $0.value) }
                .sorted { $0.date < $1.date }
                .suffix(7))
                
            // destinationStats
            var destCounts: [String: Int] = [:]
            for batch in batches {
                for op in batch.operations {
                    if !op.isTrashed {
                        let folderURL = URL(fileURLWithPath: op.newPath).deletingLastPathComponent()
                        let folderName = folderURL.lastPathComponent
                        if !folderName.isEmpty {
                            destCounts[folderName, default: 0] += 1
                        }
                    }
                }
            }
            let destinationStats = Array(destCounts.map { DestinationStat(folder: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
                .prefix(5))
                
            return DashboardStats(
                totalSorted: totalSorted,
                totalSpaceOrganized: totalSpaceOrganized,
                totalSpaceFreed: totalSpaceFreed,
                totalDuplicatesRemoved: totalDuplicatesRemoved,
                categoryStats: categoryStats,
                dateStats: dateStats,
                destinationStats: destinationStats,
                spaceFreedHistory: historyItems
            )
        }.value
        
        await MainActor.run {
            self.stats = newStats
        }
    }
    
    nonisolated private static func getCategoryFromPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let category = ConfigManager.shared.getFileCategory(url)
        return category == "Інші файли" ? "Інші" : category
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func exportToCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "smart_sorter_report.csv"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                var csvText = "\u{FEFF}" // Додаємо UTF-8 BOM для Microsoft Excel!
                csvText += "Час,Оригінальний шлях,Новий шлях,Розмір (Байт),Статус\n"
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                for batch in historyManager.getBatches() {
                    let time = formatter.string(from: batch.timestamp)
                    
                    for op in batch.operations {
                        let original = op.originalPath.replacingOccurrences(of: "\"", with: "\"\"")
                        let newPath = op.newPath.replacingOccurrences(of: "\"", with: "\"\"")
                        let status = op.isTrashed ? "Видалено дублікат" : "Впорядковано"
                        
                        csvText += "\"\(time)\",\"\(original)\",\"\(newPath)\",\(op.fileSize),\"\(status)\"\n"
                    }
                }
                
                do {
                    try csvText.write(to: url, atomically: true, encoding: .utf8)
                    self.exportPath = url.path
                    self.showingExportSuccess = true
                } catch {
                    print("[DASHBOARD] Помилка запису CSV: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: Gradient
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            Spacer()
        }
        .padding()
        .liquidGlass(radius: DT.Radius.lg)
    }
}
