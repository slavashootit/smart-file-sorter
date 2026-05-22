import SwiftUI

public struct SortingView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    @Binding var folderPath: String
    @Binding var sortMode: SortMode
    @Binding var enabledCategories: [String: Bool]
    @Binding var detectDuplicates: Bool
    
    let isSorting: Bool
    let processedCount: Int
    let totalCount: Int
    let currentItem: String
    let logs: [String]
    let currentStatus: AppStatus
    
    @Binding var selectedTab: String
    
    let runSorting: (Bool) -> Void
    let cancelSorting: () -> Void
    let undoSorting: () -> Void
    
    public init(
        folderPath: Binding<String>,
        sortMode: Binding<SortMode>,
        enabledCategories: Binding<[String: Bool]>,
        detectDuplicates: Binding<Bool>,
        isSorting: Bool,
        processedCount: Int,
        totalCount: Int,
        currentItem: String,
        logs: [String],
        currentStatus: AppStatus,
        selectedTab: Binding<String>,
        runSorting: @escaping (Bool) -> Void,
        cancelSorting: @escaping () -> Void,
        undoSorting: @escaping () -> Void
    ) {
        self._folderPath = folderPath
        self._sortMode = sortMode
        self._enabledCategories = enabledCategories
        self._detectDuplicates = detectDuplicates
        self.isSorting = isSorting
        self.processedCount = processedCount
        self.totalCount = totalCount
        self.currentItem = currentItem
        self.logs = logs
        self.currentStatus = currentStatus
        self._selectedTab = selectedTab
        self.runSorting = runSorting
        self.cancelSorting = cancelSorting
        self.undoSorting = undoSorting
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with StatusPill
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Автоматичне впорядкування")
                            .font(DT.Font.geistMedium(13))
                        Text("Оберіть папку та параметри для початку")
                            .font(DT.Font.body(13))
                            .foregroundColor(DT.Color.textSecondary)
                    }
                    Spacer()
                    StatusPill(status: currentStatus)
                }
                .padding(.bottom, 10)
                
                // Rule Conflicts Block
                let conflicts = RuleEngine.shared.detectConflicts()
                if !conflicts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Виявлено конфлікти у правилах:")
                                .font(DT.Font.geistMedium(13))
                                .foregroundColor(.orange)
                        }
                        ForEach(conflicts, id: \.self) { conflict in
                            Text("• \(conflict)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Zone A: DropZoneView
                DropZoneView(folderPath: $folderPath, isSorting: isSorting)
                
                // Zone B: FilterBarView
                FilterBarView(
                    sortMode: $sortMode,
                    enabledCategories: $enabledCategories,
                    detectDuplicates: $detectDuplicates
                )
                
                // Zone C: Action Buttons / Progress
                if isSorting {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Впорядкування файлів...")
                                .font(DT.Font.bodyWeight(14, weight: .semibold))
                            Spacer()
                            Text("\(processedCount) з \(totalCount)")
                                .font(DT.Font.mono(13))
                                .foregroundColor(.secondary)
                        }
                        if !currentItem.isEmpty {
                            Text(currentItem)
                                .font(DT.Font.mono(11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        ProgressView(value: Double(processedCount), total: Double(max(1, totalCount)))
                            .progressViewStyle(.linear)
                            .shimmer()
                        
                        Button(action: cancelSorting) {
                            Label("Скасувати сортування", systemImage: "xmark.circle")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding()
                    .liquidGlass(radius: DT.Radius.lg)
                } else {
                    HStack(spacing: 15) {
                        Button(action: { runSorting(true) }) {
                            HStack(spacing: 8) {
                                Label("previewSorting", systemImage: "eye")
                                ShortcutHint("⌘P")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .keyboardShortcut("p", modifiers: .command)
                        
                        MagneticButton(action: { runSorting(false) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("startSorting")
                                ShortcutHint("⌘⏎")
                            }
                        }
                        .keyboardShortcut(.return, modifiers: .command)
                    }
                }
                
                // Zone D: LastRunSummaryView
                LastRunSummaryView(selectedTab: $selectedTab, onUndo: undoSorting)
                    .disabled(isSorting)
                
                // Neon Logs Console
                if !logs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Журнал операцій")
                            .font(DT.Font.geistMedium(13))
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(logs, id: \.self) { log in
                                    Text(log)
                                        .font(DT.Font.mono(12))
                                        .foregroundColor(getLogColor(log))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                                }
                            }
                            .padding(10)
                        }
                        .frame(height: 180)
                        .liquidGlass(radius: DT.Radius.md)
                    }
                }
            }
            .padding()
        }
    }
    
    private func getLogColor(_ log: String) -> Color {
        if log.contains("[УСПІШНО]") {
            return DT.Color.success
        } else if log.contains("[ПЛАНУЄТЬСЯ]") {
            return DT.Color.accentStrong
        } else if log.contains("[ДУБЛІКАТ]") {
            return .cyan
        } else if log.contains("[ПОМИЛКА]") {
            return DT.Color.danger
        } else if log.contains("[ПРОПУЩЕНО]") {
            return .gray
        } else if log.contains("[ВІДНОВЛЕНО]") {
            return .orange
        }
        return DT.Color.textPrimary
    }
}
