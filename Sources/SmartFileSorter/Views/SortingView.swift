import SwiftUI

public struct SortingView: View {
    @StateObject private var viewModel = SortingViewModel()
    
    @Binding var folderPath: String
    @Binding var selectedTab: String
    
    @State private var expandedGroups: Set<UUID> = []
    @State private var undoLogs: [String] = []
    @State private var showUndoLogs = false
    
    public init(folderPath: Binding<String>, selectedTab: Binding<String>) {
        self._folderPath = folderPath
        self._selectedTab = selectedTab
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Автоматичне впорядкування")
                            .font(DT.Font.geistMedium(18))
                            .foregroundColor(DT.Color.textPrimary)
                        Text("Новий лінійний flow сортування файлів")
                            .font(DT.Font.body(13))
                            .foregroundColor(DT.Color.textSecondary)
                    }
                    Spacer()
                    
                    // AppStatus mapping
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
                
                // Content Switcher
                switch viewModel.state {
                case .idle:
                    idleView
                case .analysing:
                    analysingView
                case .preview(let groups):
                    previewView(groups: groups)
                case .sorting:
                    sortingProgressView
                case .done(let moved):
                    doneView(moved: moved)
                }
                
                // Undo Logs (if available)
                if showUndoLogs && !undoLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Журнал скасування")
                            .font(DT.Font.geistMedium(13))
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(undoLogs, id: \.self) { log in
                                    Text(log)
                                        .font(DT.Font.mono(12))
                                        .foregroundColor(.orange)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(10)
                        }
                        .frame(height: 120)
                        .liquidGlass(radius: DT.Radius.md)
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            if !folderPath.isEmpty {
                viewModel.folderPath = folderPath
            }
        }
        .onChangeCompat(of: folderPath) { newVal in
            if viewModel.folderPath != newVal {
                viewModel.folderPath = newVal
            }
        }
        .onChangeCompat(of: viewModel.folderPath) { newVal in
            if folderPath != newVal {
                folderPath = newVal
            }
        }
    }
    
    // MARK: - State Views
    
    private var idleView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Zone A: DropZoneView
            DropZoneView(folderPath: $viewModel.folderPath, isSorting: false)
            
            // Category Selector
            VStack(alignment: .leading, spacing: 12) {
                Text("Що сортувати:")
                    .font(DT.Font.geistMedium(13))
                    .foregroundColor(DT.Color.textSecondary)
                
                FlowLayout(spacing: 8) {
                    ForEach(SorterEngine.defaultCategories, id: \.id) { cat in
                        let isSelected = viewModel.selectedCategories.contains(cat.id)
                        Button {
                            if isSelected {
                                viewModel.selectedCategories.remove(cat.id)
                            } else {
                                viewModel.selectedCategories.insert(cat.id)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(isSelected ? "✓" : "○")
                                    .font(.system(size: 12, weight: .bold))
                                Image(systemName: iconForCategory(cat.icon))
                                    .font(.system(size: 11))
                                Text(cat.label)
                                    .font(DT.Font.bodyWeight(13, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isSelected ? DT.Color.backgroundInfo : DT.Color.backgroundSecondary)
                            )
                            .foregroundColor(isSelected ? DT.Color.textInfo : DT.Color.textSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(isSelected ? DT.Color.textInfo.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Analyze Button
            Button(action: {
                Task {
                    await viewModel.analyse(
                        url: URL(fileURLWithPath: viewModel.folderPath),
                        categories: viewModel.selectedCategories
                    )
                }
            }) {
                HStack {
                    Text("АНАЛІЗ")
                        .font(DT.Font.bodyWeight(13, weight: .semibold))
                    Image(systemName: "magnifyingglass")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.folderPath.isEmpty)
            .opacity(viewModel.folderPath.isEmpty ? 0.5 : 1.0)
        }
    }
    
    private var analysingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Аналізуємо вміст папки...")
                .font(DT.Font.body(13))
                .foregroundColor(DT.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .liquidGlass()
    }
    
    private func previewView(groups: [SortGroup]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Folder header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(DT.Color.accentStrong)
                    Text(URL(fileURLWithPath: viewModel.folderPath).lastPathComponent)
                        .font(DT.Font.geistMedium(14))
                        .foregroundColor(DT.Color.textPrimary)
                    
                    let totalFiles = groups.reduce(0) { $0 + $1.files.count }
                    Text("· \(totalFiles) файлів")
                        .font(DT.Font.body(13))
                        .foregroundColor(DT.Color.textSecondary)
                }
                
                Spacer()
                
                Button("Змінити") {
                    viewModel.reset()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            if groups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundColor(DT.Color.textTertiary)
                    Text("Файлів обраних категорій не знайдено.")
                        .font(DT.Font.body(13))
                        .foregroundColor(DT.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .liquidGlass()
            } else {
                // Group Rows
                VStack(spacing: 12) {
                    ForEach(groups.indices, id: \.self) { idx in
                        let group = groups[idx]
                        let isExpanded = expandedGroups.contains(group.id)
                        let relDest = group.destination.path.replacingOccurrences(of: viewModel.folderPath + "/", with: "")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            // Row Header
                            HStack {
                                Button {
                                    toggleGroupEnabled(id: group.id)
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(group.isEnabled ? Color.blue : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(group.isEnabled ? Color.blue : Color.white.opacity(0.25), lineWidth: 1)
                                            )
                                            .frame(width: 14, height: 14)
                                        if group.isEnabled {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                HStack(spacing: 4) {
                                    Text(categoryEmoji(for: group.category))
                                    Text(group.category)
                                        .font(DT.Font.bodyWeight(13, weight: .semibold))
                                        .foregroundColor(DT.Color.textPrimary)
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundColor(DT.Color.textTertiary)
                                    Text(relDest)
                                        .font(DT.Font.geistMono(12))
                                        .foregroundColor(DT.Color.textSecondary)
                                }
                                
                                Spacer()
                                
                                Text("\(group.files.count) файлів")
                                    .font(DT.Font.body(12))
                                    .foregroundColor(DT.Color.textSecondary)
                                
                                Button {
                                    toggleGroupExpanded(id: group.id)
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(DT.Color.textTertiary)
                                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Inline files list
                            if isExpanded {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(group.files, id: \.self) { file in
                                        Text("  \(file.lastPathComponent)")
                                            .font(DT.Font.mono(11))
                                            .foregroundColor(DT.Color.textPrimary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.leading, 24)
                                .transition(.opacity)
                            } else {
                                // Collapsed file preview
                                let previewText = collapsedFilesText(for: group.files)
                                Text("  \(previewText)")
                                    .font(DT.Font.mono(11))
                                    .foregroundColor(DT.Color.textTertiary)
                                    .lineLimit(1)
                                    .padding(.leading, 24)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).fill(DT.Color.glass))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(DT.Color.borderSubtle, lineWidth: 1)
                        )
                    }
                }
            }
            
            // Footer Control Bar
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.reset()
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Назад")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                
                let enabledCount = groups.filter(\.isEnabled).reduce(0) { $0 + $1.files.count }
                Button(action: {
                    Task {
                        await viewModel.sort()
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("СОРТУВАТИ \(enabledCount) файлів")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(enabledCount == 0)
                .opacity(enabledCount == 0 ? 0.5 : 1.0)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.top, 10)
        }
    }
    
    private var sortingProgressView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Впорядковуємо файли...")
                .font(DT.Font.body(13))
                .foregroundColor(DT.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .liquidGlass()
    }
    
    private func doneView(moved: Int) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(DT.Color.success)
                Text("Впорядкування завершено!")
                    .font(DT.Font.geistMedium(18))
                    .foregroundColor(DT.Color.textPrimary)
                Text("Успішно переміщено \(moved) файлів.")
                    .font(DT.Font.body(13))
                    .foregroundColor(DT.Color.textSecondary)
            }
            
            HStack(spacing: 15) {
                Button(action: {
                    let logs = SorterEngine.shared.undoSorting()
                    self.undoLogs = logs
                    self.showUndoLogs = true
                    viewModel.reset()
                }) {
                    Label("Скасувати сортування", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button(action: {
                    viewModel.reset()
                }) {
                    Text("Сортувати ще")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .liquidGlass()
    }
    
    // MARK: - Helpers
    
    private var currentStatus: AppStatus {
        switch viewModel.state {
        case .idle:
            return .ready
        case .analysing:
            return .sorting
        case .preview:
            return .ready
        case .sorting:
            return .sorting
        case .done:
            return .done
        }
    }
    
    private func iconForCategory(_ icon: String) -> String {
        switch icon {
        case "photo": return "photo"
        case "video": return "video"
        case "music": return "music.note"
        case "file-type-pdf": return "doc.text"
        case "zip": return "doc.zipper"
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "dots": return "ellipsis"
        default: return "folder"
        }
    }
    
    private func categoryEmoji(for name: String) -> String {
        switch name {
        case "Фото": return "🖼"
        case "Відео": return "📹"
        case "Аудіо": return "🎵"
        case "Документи": return "📄"
        case "Архіви": return "📦"
        case "Код": return "💻"
        default: return "📁"
        }
    }
    
    private func toggleGroupEnabled(id: UUID) {
        guard case .preview(var groups) = viewModel.state else { return }
        if let idx = groups.firstIndex(where: { $0.id == id }) {
            groups[idx].isEnabled.toggle()
            viewModel.state = .preview(groups: groups)
        }
    }
    
    private func toggleGroupExpanded(id: UUID) {
        if expandedGroups.contains(id) {
            expandedGroups.remove(id)
        } else {
            expandedGroups.insert(id)
        }
    }
    
    private func collapsedFilesText(for files: [URL]) -> String {
        let first3 = files.prefix(3).map { $0.lastPathComponent }
        var result = first3.joined(separator: ", ")
        if files.count > 3 {
            result += " + ще \(files.count - 3)"
        }
        return result
    }
}

// FlowLayout helper for dynamic chip grid wrapping
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX)
        }
        
        return CGSize(width: totalWidth, height: currentY + lineHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.minX + width {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
