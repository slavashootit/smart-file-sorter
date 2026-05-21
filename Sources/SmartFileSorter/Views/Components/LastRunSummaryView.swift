import SwiftUI

public struct LastRunSummaryView: View {
    @ObservedObject private var historyManager = HistoryManager.shared
    @Binding var selectedTab: String
    let onUndo: () -> Void
    
    public init(selectedTab: Binding<String>, onUndo: @escaping () -> Void) {
        self._selectedTab = selectedTab
        self.onUndo = onUndo
    }
    
    private var lastCompletedBatch: BatchRecord? {
        historyManager.getBatches().last { !$0.isCancelled }
    }
    
    private var folderName: String {
        guard let batch = lastCompletedBatch, let firstOp = batch.operations.first else { return "—" }
        let originalURL = URL(fileURLWithPath: firstOp.originalPath)
        return originalURL.deletingLastPathComponent().lastPathComponent
    }
    
    private var fileCount: Int {
        lastCompletedBatch?.operations.count ?? 0
    }
    
    private var relativeTimeStr: String {
        guard let batch = lastCompletedBatch else { return "" }
        return formatRelativeUkrainianDate(batch.timestamp)
    }
    
    public var body: some View {
        if lastCompletedBatch != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("ОСТАННІЙ ЗАПУСК")
                    .font(DT.Font.bodyWeight(10, weight: .bold))
                    .foregroundColor(DT.Color.textSecondary)
                
                HStack(spacing: 32) {
                    // Metric 1: Files
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Файли")
                            .font(DT.Font.body(11))
                            .foregroundColor(DT.Color.textTertiary)
                        Text(ukPluralFiles(fileCount))
                            .font(DT.Font.bodyWeight(13, weight: .semibold))
                            .foregroundColor(DT.Color.textPrimary)
                    }
                    
                    // Metric 2: Folder
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Папка")
                            .font(DT.Font.body(11))
                            .foregroundColor(DT.Color.textTertiary)
                        Text(folderName)
                            .font(DT.Font.bodyWeight(13, weight: .semibold))
                            .foregroundColor(DT.Color.textPrimary)
                            .lineLimit(1)
                    }
                    
                    // Metric 3: Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Час")
                            .font(DT.Font.body(11))
                            .foregroundColor(DT.Color.textTertiary)
                        Text(relativeTimeStr)
                            .font(DT.Font.bodyWeight(13, weight: .semibold))
                            .foregroundColor(DT.Color.textPrimary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                    .background(DT.Color.borderSubtle)
                    .padding(.vertical, 2)
                
                HStack {
                    Button(action: {
                        Haptics.alignment()
                        onUndo()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Скасувати ↩")
                        }
                        .font(DT.Font.bodyWeight(12, weight: .semibold))
                        .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .spotlightHover()
                    
                    Spacer()
                    
                    Button(action: {
                        Haptics.alignment()
                        selectedTab = "analytics"
                    }) {
                        HStack(spacing: 4) {
                            Text("Деталі")
                            Image(systemName: "arrow.right")
                        }
                        .font(DT.Font.bodyWeight(12, weight: .semibold))
                        .foregroundColor(DT.Color.accentStrong)
                    }
                    .buttonStyle(.plain)
                    .spotlightHover()
                }
            }
            .padding(16)
            .background(DT.Color.elevated)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(DT.Color.borderDefault, lineWidth: 1)
            )
        } else {
            VStack {
                Text("Історія операцій порожня")
                    .font(DT.Font.body(12))
                    .foregroundColor(DT.Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DT.Color.glass)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(DT.Color.borderSubtle, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
    }
    
    private func ukPluralFiles(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 {
            return "\(count) файлів"
        } else if mod10 == 1 {
            return "\(count) файл"
        } else if mod10 >= 2 && mod10 <= 4 {
            return "\(count) файли"
        } else {
            return "\(count) файлів"
        }
    }
    
    private func formatRelativeUkrainianDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: date)
        
        if calendar.isDateInToday(date) {
            return "сьогодні \(timeStr)"
        } else if calendar.isDateInYesterday(date) {
            return "вчора \(timeStr)"
        } else {
            formatter.dateFormat = "d LLL"
            let dateStr = formatter.string(from: date).replacingOccurrences(of: ".", with: "")
            return "\(dateStr) \(timeStr)"
        }
    }
}
