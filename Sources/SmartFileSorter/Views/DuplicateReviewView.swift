import SwiftUI
import QuickLookUI
import AVFoundation

public final class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    public static let shared = QuickLookHelper()
    private var currentURLs: [URL] = []
    
    public func showPreview(urls: [URL]) {
        self.currentURLs = urls
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.reloadData()
            panel.makeKeyAndOrderFront(nil)
        }
    }
    
    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return currentURLs.count
    }
    
    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index < currentURLs.count else { return nil }
        return currentURLs[index] as QLPreviewItem
    }
}

public struct DuplicateReviewView: View {
    private var reduceMotion: Bool {
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    private var increaseContrast: Bool {
        return NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }

    @StateObject private var finder = DuplicateFinder()
    @State private var scanPath: String = NSHomeDirectory() + "/Downloads"
    @State private var selectedGroupId: UUID? = nil
    @State private var checkedFiles: Set<URL> = []
    @State private var showConfirmDelete = false
    @State private var selectedSmartSelection = "Вручну"
    
    private let smartSelectionOptions = ["Вручну", "Залишити найстаріші", "Залишити найновіші", "Залишити в Завантаженнях"]
    
    public var body: some View {
        VStack(spacing: 0) {
            // Заголовок сканування
            HStack {
                Text("Пошук дублікатів")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                TextField("Шлях для сканування", text: $scanPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 150, idealWidth: 250, maxWidth: 300)
                    .accessibilityLabel("Шлях сканування дублікатів")
                
                Button(action: selectFolder) {
                    Image(systemName: "folder")
                }
                .accessibilityLabel("Вибрати папку")
                .accessibilityHint("Відкриває діалог вибору папки на диску")
                
                if finder.isScanning {
                    Button(action: { finder.cancelScan() }) {
                        Text("Скасувати")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .accessibilityLabel("Скасувати сканування")
                } else {
                    Button(action: startScan) {
                        Text("Сканувати")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            
            if finder.isScanning {
                VStack(spacing: 12) {
                    ProgressView(value: finder.progress)
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                    Text(finder.currentFile)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding()
                Spacer()
            } else if finder.duplicateGroups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Не знайдено дублікатів")
                        .font(.headline)
                    Text("Вкажіть папку та запустіть сканування для очищення простору.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Панель підсумку та Smart Selection
                HStack {
                    Text("Знайдено дублікатів: \(finder.duplicatesCount) | Можна звільнити: \(formatBytes(finder.potentialSavings))")
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Picker("Авто-вибір:", selection: $selectedSmartSelection) {
                        ForEach(smartSelectionOptions, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }
                    .frame(width: 250)
                    .onChange(of: selectedSmartSelection) { newValue in
                        applySmartSelection(newValue)
                    }
                    
                    Button(action: {
                        if !checkedFiles.isEmpty {
                            showConfirmDelete = true
                        }
                    }) {
                        Text("Видалити вибрані (\(checkedFiles.count) файлів, \(formatBytes(selectedFilesSize())))")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(checkedFiles.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                // Основна таблиця
                HSplitView {
                    // Ліва колонка: групи дублікатів
                    List(selection: $selectedGroupId) {
                        ForEach(finder.duplicateGroups) { group in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(group.files.first?.lastPathComponent ?? "Невідомий файл")
                                        .fontWeight(.semibold)
                                    Text("\(group.files.count) копій | Розмір: \(formatBytes(group.fileSize)) кожна")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formatBytes(group.fileSize * Int64(group.files.count - 1)))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            .tag(group.id)
                        }
                    }
                    .frame(minWidth: 250, idealWidth: 350)
                    
                    // Права колонка: файли в обраній групі
                    if let selectedGroup = finder.duplicateGroups.first(where: { $0.id == selectedGroupId }) {
                        List {
                            Section(header: Text("Деталі дублікатів")) {
                                ForEach(selectedGroup.files, id: \.self) { file in
                                    HStack {
                                        Toggle("", isOn: Binding(
                                            get: { checkedFiles.contains(file) },
                                            set: { isChecked in
                                                if isChecked {
                                                    checkedFiles.insert(file)
                                                } else {
                                                    checkedFiles.remove(file)
                                                }
                                            }
                                        ))
                                        .toggleStyle(CheckboxToggleStyle())
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(file.lastPathComponent)
                                                .fontWeight(.medium)
                                            HStack(spacing: 6) {
                                                Text(file.deletingLastPathComponent().path)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                                
                                                if let videoInfo = getVideoMetadata(for: file) {
                                                    Text("•")
                                                        .foregroundColor(.secondary)
                                                    Text(videoInfo)
                                                        .foregroundColor(.blue)
                                                        .bold()
                                                }
                                            }
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            QuickLookHelper.shared.showPreview(urls: [file])
                                        }) {
                                            Image(systemName: "eye")
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button(action: {
                                            NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: file.deletingLastPathComponent().path)
                                        }) {
                                            Image(systemName: "arrow.right.circle")
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .frame(minWidth: 300)
                    } else {
                        VStack {
                            Text("Оберіть групу для перегляду копій")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .sheet(isPresented: $showConfirmDelete) {
            VStack(spacing: 16) {
                Text("Підтвердження видалення")
                    .font(.headline)
                Text("Ви дійсно хочете перенести \(checkedFiles.count) вибраних файлів у Смітник?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Button("Скасувати") {
                        showConfirmDelete = false
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Перенести в Смітник") {
                        deleteSelectedFiles()
                        showConfirmDelete = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 350, height: 150)
        }
        .onAppear {
            if let first = finder.duplicateGroups.first {
                selectedGroupId = first.id
            }
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            if let path = panel.url?.path {
                scanPath = path
            }
        }
    }
    
    private func startScan() {
        checkedFiles.removeAll()
        selectedSmartSelection = "Вручну"
        finder.scan(at: scanPath) {
            if let first = finder.duplicateGroups.first {
                selectedGroupId = first.id
            }
        }
    }
    
    private func selectedFilesSize() -> Int64 {
        var size: Int64 = 0
        for group in finder.duplicateGroups {
            for file in group.files {
                if checkedFiles.contains(file) {
                    size += group.fileSize
                }
            }
        }
        return size
    }
    
    private func applySmartSelection(_ mode: String) {
        checkedFiles.removeAll()
        if mode == "Вручну" { return }
        
        let fileManager = FileManager.default
        
        for group in finder.duplicateGroups {
            var filesWithDates: [(url: URL, date: Date)] = []
            for file in group.files {
                let attrs = try? fileManager.attributesOfItem(atPath: file.path)
                let date = (attrs?[.creationDate] as? Date) ?? (attrs?[.modificationDate] as? Date) ?? Date()
                filesWithDates.append((url: file, date: date))
            }
            
            if mode == "Залишити найстаріші" {
                // Сортуємо: найстаріші першими, їх залишаємо (не чекбоксимо). Інші додаємо в checkedFiles.
                filesWithDates.sort { $0.date < $1.date }
                if filesWithDates.count > 1 {
                    for i in 1..<filesWithDates.count {
                        checkedFiles.insert(filesWithDates[i].url)
                    }
                }
            } else if mode == "Залишити найновіші" {
                // Найновіші першими, їх залишаємо. Інші в checkedFiles.
                filesWithDates.sort { $0.date > $1.date }
                if filesWithDates.count > 1 {
                    for i in 1..<filesWithDates.count {
                        checkedFiles.insert(filesWithDates[i].url)
                    }
                }
            } else if mode == "Залишити в Завантаженнях" {
                // Ті, що в Downloads, залишаємо. Інші чекбоксимо.
                // Якщо немає жодного в Downloads або всі в Downloads, залишаємо першого.
                let inDownloads = group.files.filter { $0.path.contains("/Downloads") }
                if !inDownloads.isEmpty {
                    for file in group.files {
                        if !inDownloads.contains(file) {
                            checkedFiles.insert(file)
                        }
                    }
                    // Якщо копій в Downloads більше однієї, checked всі крім першої в Downloads
                    if inDownloads.count > 1 {
                        for i in 1..<inDownloads.count {
                            checkedFiles.insert(inDownloads[i])
                        }
                    }
                } else {
                    // Якщо нічого немає в Downloads, залишаємо першого
                    for i in 1..<group.files.count {
                        checkedFiles.insert(group.files[i])
                    }
                }
            }
        }
    }
    
    private func deleteSelectedFiles() {
        let fileManager = FileManager.default
        var deletedSize: Int64 = 0
        var deletedCount = 0
        
        for file in checkedFiles {
            let size = (try? fileManager.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
            do {
                try fileManager.trashItem(at: file, resultingItemURL: nil)
                deletedSize += size
                deletedCount += 1
            } catch {
                print("[DUPLICATE] Не вдалося видалити \(file.path): \(error.localizedDescription)")
            }
        }
        
        // Оновлюємо статистику в Dashboard
        let oldFreed = UserDefaults.standard.double(forKey: "FreedBytesTotal")
        UserDefaults.standard.set(oldFreed + Double(deletedSize), forKey: "FreedBytesTotal")
        
        let oldDuplicates = UserDefaults.standard.integer(forKey: "FreedDuplicatesCount")
        UserDefaults.standard.set(oldDuplicates + deletedCount, forKey: "FreedDuplicatesCount")
        
        // Записуємо звільнений простір в історію
        let dateKey = DateFormatter.FreedSpaceFormatter.string(from: Date())
        var savedFreedHistory = UserDefaults.standard.dictionary(forKey: "freed_history") as? [String: Double] ?? [:]
        savedFreedHistory[dateKey, default: 0.0] += Double(deletedSize)
        UserDefaults.standard.set(savedFreedHistory, forKey: "freed_history")
        
        checkedFiles.removeAll()
        startScan() // Пересканувати, щоб оновити результати
    }
    
    
    private func getVideoMetadata(for url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        guard ["mp4", "mov", "m4v", "avi", "mkv", "webm"].contains(ext) else { return nil }
        
        let asset = AVURLAsset(url: url)
        let duration = asset.duration
        let durationSeconds = CMTimeGetSeconds(duration)
        guard !durationSeconds.isNaN, durationSeconds > 0 else { return nil }
        
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        let durationStr = String(format: "%d:%02d", minutes, seconds)
        
        if let track = asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize
            let width = Int(size.width)
            let height = Int(size.height)
            return "\(width)x\(height) • \(durationStr)"
        }
        
        return durationStr
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

extension DateFormatter {
    static let FreedSpaceFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
