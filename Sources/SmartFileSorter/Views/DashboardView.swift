import SwiftUI
import Charts

struct CategoryStat: Identifiable {
    let id = UUID()
    let category: String
    let count: Int
}

struct DateStat: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct DestinationStat: Identifiable {
    let id = UUID()
    let folder: String
    let count: Int
}

public struct DashboardView: View {
    @ObservedObject var historyManager = HistoryManager.shared
    
    @State private var showingExportSuccess = false
    @State private var exportPath = ""
    
    public init() {}
    
    // Метрики
    private var totalSorted: Int {
        historyManager.getBatches().reduce(0) { $0 + $1.operations.count }
    }
    
    private var totalSpaceOrganized: Int64 {
        historyManager.getBatches().reduce(0) { sum, batch in
            sum + batch.operations.reduce(0) { $0 + $1.fileSize }
        }
    }
    
    private var totalSpaceFreed: Int64 {
        let sortingFreed = historyManager.getBatches().reduce(0) { sum, batch in
            sum + batch.operations.filter { $0.isTrashed }.reduce(0) { $0 + $1.fileSize }
        }
        let manualFreed = UserDefaults.standard.double(forKey: "FreedBytesTotal")
        return sortingFreed + Int64(manualFreed)
    }
    
    private var totalDuplicatesRemoved: Int {
        let sortingDuplicates = historyManager.getBatches().reduce(0) { sum, batch in
            sum + batch.operations.filter { $0.isTrashed }.count
        }
        let manualDuplicates = UserDefaults.standard.integer(forKey: "FreedDuplicatesCount")
        return sortingDuplicates + manualDuplicates
    }
    
    // Статистика очищення пам'яті за днями
    struct FreedHistoryItem: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Double
    }
    
    private var spaceFreedHistory: [FreedHistoryItem] {
        let dict = UserDefaults.standard.dictionary(forKey: "freed_history") as? [String: Double] ?? [:]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        
        var items: [FreedHistoryItem] = []
        for (dateStr, val) in dict {
            if let date = df.date(from: dateStr) {
                items.append(FreedHistoryItem(date: date, amount: val))
            }
        }
        items.sort { $0.date < $1.date }
        return items
    }
    
    // Статистика за категоріями
    private var categoryStats: [CategoryStat] {
        var counts: [String: Int] = [:]
        for batch in historyManager.getBatches() {
            for op in batch.operations {
                let category = getCategoryFromPath(op.newPath)
                counts[category, default: 0] += 1
            }
        }
        return counts.map { CategoryStat(category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    // Статистика за датами (останні 7 днів з сортуванням)
    private var dateStats: [DateStat] {
        var counts: [Date: Int] = [:]
        let calendar = Calendar.current
        for batch in historyManager.getBatches() {
            let day = calendar.startOfDay(for: batch.timestamp)
            counts[day, default: 0] += batch.operations.count
        }
        return Array(counts.map { DateStat(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
            .suffix(7))
    }
    
    // Топ-5 папок призначення
    private var destinationStats: [DestinationStat] {
        var counts: [String: Int] = [:]
        for batch in historyManager.getBatches() {
            for op in batch.operations {
                if !op.isTrashed {
                    let folderURL = URL(fileURLWithPath: op.newPath).deletingLastPathComponent()
                    let folderName = folderURL.lastPathComponent
                    if !folderName.isEmpty {
                        counts[folderName, default: 0] += 1
                    }
                }
            }
        }
        return Array(counts.map { DestinationStat(folder: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5))
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Заголовок та Експорт
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Аналітика сортування")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("Статистика роботи Розумного сортувальника файлів")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: exportToCSV) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Експорт звіту (CSV)")
                        }
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
                    MetricCard(
                        title: "Впорядковано",
                        value: "\(totalSorted)",
                        icon: "doc.text.fill",
                        gradient: Gradient(colors: [Color.blue, Color.cyan])
                    )
                    
                    MetricCard(
                        title: "Організовано",
                        value: formatBytes(totalSpaceOrganized),
                        icon: "internaldrive.fill",
                        gradient: Gradient(colors: [Color.purple, Color.pink])
                    )
                    
                    MetricCard(
                        title: "Звільнено простору",
                        value: formatBytes(totalSpaceFreed),
                        icon: "arrow.down.to.line.circle.fill",
                        gradient: Gradient(colors: [Color.green, Color.teal])
                    )
                    
                    MetricCard(
                        title: "Видалено копій",
                        value: "\(totalDuplicatesRemoved)",
                        icon: "trash.fill",
                        gradient: Gradient(colors: [Color.orange, Color.red])
                    )
                }
                
                if totalSorted == 0 && totalSpaceFreed == 0 {
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
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                } else {
                    // Сітка графіків
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        // Графік типів
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Розподіл за категоріями")
                                .font(.headline)
                            
                            Chart(categoryStats) { item in
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
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        
                        // Топ папок
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Топ-5 папок призначення")
                                .font(.headline)
                            
                            Chart(destinationStats) { item in
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
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        
                        // Графік динаміки сортування
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Динаміка сортування (останні дні)")
                                .font(.headline)
                            
                            Chart(dateStats) { item in
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
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        
                        // Графік динаміки очищення
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Звільнення простору (за днями)")
                                .font(.headline)
                            
                            if spaceFreedHistory.isEmpty {
                                Text("Немає даних для побудови графіка")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            } else {
                                Chart(spaceFreedHistory) { item in
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
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .alert("Звіт успішно збережено", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("CSV файл збережено у:\n\(exportPath)")
        }
    }
    
    private func getCategoryFromPath(_ path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        let kindExtensions: [String: Set<String>] = [
            "Зображення": ["jpg", "jpeg", "png", "gif", "bmp", "heic", "tiff", "svg", "webp"],
            "Відео": ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"],
            "Документи": ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "key"],
            "Аудіо": ["mp3", "wav", "m4a", "flac", "aac", "ogg", "wma"],
            "Архіви": ["zip", "rar", "7z", "tar", "gz", "bz2", "dmg", "iso"]
        ]
        for (category, extensions) in kindExtensions {
            if extensions.contains(ext) {
                return category
            }
        }
        return "Інші"
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
                csvText += "Час,Профіль,Оригінальний шлях,Новий шлях,Розмір (Байт),Статус\n"
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                for batch in historyManager.getBatches() {
                    let time = formatter.string(from: batch.timestamp)
                    let profile = batch.profileName ?? "Home"
                    
                    for op in batch.operations {
                        let original = op.originalPath.replacingOccurrences(of: "\"", with: "\"\"")
                        let newPath = op.newPath.replacingOccurrences(of: "\"", with: "\"\"")
                        let status = op.isTrashed ? "Видалено дублікат" : "Впорядковано"
                        
                        csvText += "\"\(time)\",\"\(profile)\",\"\(original)\",\"\(newPath)\",\(op.fileSize),\"\(status)\"\n"
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
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
