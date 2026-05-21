import SwiftUI
import AVFoundation

public struct CleanupView: View {
    @StateObject private var manager = CleanupManager()
    @State private var selectedTab = "large_files"
    @State private var scanPath: String = NSHomeDirectory() + "/Downloads"
    @State private var minSizeMB: String = "100"
    @State private var oldDownloadsDays: String = "30"
    
    // Смітник налаштування
    @AppStorage("AutoPurgeTrash") private var autoPurgeTrash = false
    @AppStorage("AutoPurgeTrashDays") private var autoPurgeTrashDays = 30
    
    @State private var checkedLargeFiles: Set<URL> = []
    @State private var checkedOldDownloads: Set<URL> = []
    @State private var checkedEmptyFolders: Set<URL> = []
    @State private var showConfirmDelete = false
    @State private var itemsToDeleteCount = 0
    @State private var itemsToDeleteSize: Int64 = 0
    @State private var deletionSource = "" // "large", "downloads", "folders"
    
    // Alert state to avoid blocking NSAlert calls
    struct AlertInfo: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
    @State private var activeAlert: AlertInfo? = nil
    @State private var metadata: [URL: VideoMetadata] = [:]
    
    public var body: some View {
        VStack(spacing: 0) {
            // Верхня панель налаштувань сканування
            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Великі файли").tag("large_files")
                    Text("Старі завантаження").tag("old_downloads")
                    Text("Порожні папки").tag("empty_folders")
                    Text("Смітник").tag("trash_config")
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 320, idealWidth: 420, maxWidth: 450)
                
                Spacer()
                
                if selectedTab != "trash_config" && selectedTab != "old_downloads" {
                    TextField("Шлях", text: $scanPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minWidth: 100, idealWidth: 150, maxWidth: 220)
                    
                    Button(action: selectFolder) {
                        Image(systemName: "folder")
                    }
                }
                
                if selectedTab == "large_files" {
                    HStack(spacing: 4) {
                        Text(">")
                        TextField("МБ", text: $minSizeMB)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                        Text("МБ")
                    }
                } else if selectedTab == "old_downloads" {
                    HStack(spacing: 4) {
                        Text(">")
                        TextField("днів", text: $oldDownloadsDays)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 40)
                        Text("днів")
                    }
                }
                
                if selectedTab != "trash_config" {
                    if manager.isScanning {
                        Button("Скасувати") {
                            manager.cancelScan()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button("Знайти") {
                            startScan()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
            }
            .padding()
            .background(
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                    .liquidGlass(radius: 0)
            )
            
            // Основний контент
            if manager.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Сканування...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch selectedTab {
                case "large_files":
                    largeFilesTab
                case "old_downloads":
                    oldDownloadsTab
                case "empty_folders":
                    emptyFoldersTab
                case "trash_config":
                    trashConfigTab
                default:
                    EmptyView()
                }
            }
        }
        .sheet(isPresented: $showConfirmDelete) {
            VStack(spacing: 16) {
                Text("Підтвердження видалення")
                    .font(.headline)
                Text("Ви дійсно хочете перенести \(itemsToDeleteCount) об'єктів (\(formatBytes(itemsToDeleteSize))) у Смітник?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Button("Скасувати") {
                        showConfirmDelete = false
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Видалити") {
                        performCheckedDeletion()
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
        .confirmationDialog(
            activeAlert?.title ?? "",
            isPresented: Binding(
                get: { activeAlert != nil },
                set: { if !$0 { activeAlert = nil } }
            ),
            titleVisibility: .visible,
            presenting: activeAlert
        ) { _ in
            Button("OK") { }
        } message: { info in
            Text(info.message)
        }
    }
    
    // Вкладка "Великі файли"
    private var largeFilesTab: some View {
        VStack(spacing: 0) {
            if manager.largeFiles.isEmpty {
                placeholderView(systemName: "doc.zipper", text: "Великих файлів не знайдено")
            } else {
                HStack {
                    Text("Знайдено великих файлів: \(manager.largeFiles.count)")
                        .fontWeight(.semibold)
                    Spacer()
                    Button("Видалити вибрані (\(checkedLargeFiles.count))") {
                        prepareDeletion(source: "large")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(checkedLargeFiles.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                
                List {
                    ForEach(manager.largeFiles) { item in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { checkedLargeFiles.contains(item.url) },
                                set: { isChecked in
                                    if isChecked {
                                        checkedLargeFiles.insert(item.url)
                                    } else {
                                        checkedLargeFiles.remove(item.url)
                                    }
                                }
                            ))
                            .toggleStyle(CheckboxToggleStyle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.url.lastPathComponent)
                                    .fontWeight(.semibold)
                                HStack(spacing: 6) {
                                    Text(item.url.deletingLastPathComponent().path)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    if let videoInfo = metadata[item.url] {
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        Text(videoInfo.displayString)
                                            .foregroundColor(.blue)
                                            .bold()
                                    }
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatBytes(item.size))
                                    .font(.system(.body, design: .monospaced))
                                Text("Відкрито: \(formatDate(item.lastOpened))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            // Створення правила автоматичного архівування
                            Button("Авто-Архів") {
                                createAutoArchiveRule(for: item.url)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button(action: {
                                QuickLookHelper.shared.showPreview(urls: [item.url])
                            }) {
                                Image(systemName: "eye")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .task(id: item.url) {
                            guard metadata[item.url] == nil else { return }
                            let ext = item.url.pathExtension.lowercased()
                            guard ["mp4", "mov", "m4v", "avi", "mkv", "webm"].contains(ext) else { return }
                            
                            let info = await Task.detached(priority: .userInitiated) { () -> VideoMetadata? in
                                let asset = AVURLAsset(url: item.url)
                                guard let duration = try? await asset.load(.duration) else { return nil }
                                let durationSeconds = CMTimeGetSeconds(duration)
                                guard !durationSeconds.isNaN, durationSeconds > 0 else { return nil }
                                
                                let minutes = Int(durationSeconds) / 60
                                let seconds = Int(durationSeconds) % 60
                                let durationStr = String(format: "%d:%02d", minutes, seconds)
                                
                                if let track = try? await asset.loadTracks(withMediaType: .video).first {
                                    if let size = try? await track.load(.naturalSize) {
                                        let width = Int(size.width)
                                        let height = Int(size.height)
                                        return VideoMetadata(width: width, height: height, duration: durationStr)
                                    }
                                }
                                return VideoMetadata(width: nil, height: nil, duration: durationStr)
                            }.value
                            
                            if let info = info {
                                metadata[item.url] = info
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Вкладка "Старі завантаження"
    private var oldDownloadsTab: some View {
        VStack(spacing: 0) {
            if manager.oldDownloads.isEmpty {
                placeholderView(systemName: "arrow.down.circle", text: "Старих завантажень не знайдено")
            } else {
                HStack {
                    Text("Знайдено старих файлів у Downloads: \(manager.oldDownloads.count)")
                        .fontWeight(.semibold)
                    Spacer()
                    Button("Видалити вибрані (\(checkedOldDownloads.count))") {
                        prepareDeletion(source: "downloads")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(checkedOldDownloads.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                
                List {
                    ForEach(manager.oldDownloads) { item in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { checkedOldDownloads.contains(item.url) },
                                set: { isChecked in
                                    if isChecked {
                                        checkedOldDownloads.insert(item.url)
                                    } else {
                                        checkedOldDownloads.remove(item.url)
                                    }
                                }
                            ))
                            .toggleStyle(CheckboxToggleStyle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.url.lastPathComponent)
                                    .fontWeight(.semibold)
                                HStack(spacing: 6) {
                                    Text(item.category)
                                    
                                    if let videoInfo = metadata[item.url] {
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        Text(videoInfo.displayString)
                                            .foregroundColor(.blue)
                                            .bold()
                                    }
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatBytes(item.size))
                                    .font(.system(.body, design: .monospaced))
                                Text("Відкрито: \(formatDate(item.lastOpened))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            Button(action: {
                                QuickLookHelper.shared.showPreview(urls: [item.url])
                            }) {
                                Image(systemName: "eye")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .task(id: item.url) {
                            guard metadata[item.url] == nil else { return }
                            let ext = item.url.pathExtension.lowercased()
                            guard ["mp4", "mov", "m4v", "avi", "mkv", "webm"].contains(ext) else { return }
                            
                            let info = await Task.detached(priority: .userInitiated) { () -> VideoMetadata? in
                                let asset = AVURLAsset(url: item.url)
                                guard let duration = try? await asset.load(.duration) else { return nil }
                                let durationSeconds = CMTimeGetSeconds(duration)
                                guard !durationSeconds.isNaN, durationSeconds > 0 else { return nil }
                                
                                let minutes = Int(durationSeconds) / 60
                                let seconds = Int(durationSeconds) % 60
                                let durationStr = String(format: "%d:%02d", minutes, seconds)
                                
                                if let track = try? await asset.loadTracks(withMediaType: .video).first {
                                    if let size = try? await track.load(.naturalSize) {
                                        let width = Int(size.width)
                                        let height = Int(size.height)
                                        return VideoMetadata(width: width, height: height, duration: durationStr)
                                    }
                                }
                                return VideoMetadata(width: nil, height: nil, duration: durationStr)
                            }.value
                            
                            if let info = info {
                                metadata[item.url] = info
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Вкладка "Порожні папки"
    private var emptyFoldersTab: some View {
        VStack(spacing: 0) {
            if manager.emptyFolders.isEmpty {
                placeholderView(systemName: "folder.badge.minus", text: "Порожніх папок не знайдено")
            } else {
                HStack {
                    Text("Знайдено порожніх папок: \(manager.emptyFolders.count)")
                        .fontWeight(.semibold)
                    Spacer()
                    Button("Видалити вибрані (\(checkedEmptyFolders.count))") {
                        prepareDeletion(source: "folders")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(checkedEmptyFolders.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                
                List {
                    ForEach(manager.emptyFolders) { item in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { checkedEmptyFolders.contains(item.url) },
                                set: { isChecked in
                                    if isChecked {
                                        checkedEmptyFolders.insert(item.url)
                                    } else {
                                        checkedEmptyFolders.remove(item.url)
                                    }
                                }
                            ))
                            .toggleStyle(CheckboxToggleStyle())
                            
                            Image(systemName: "folder")
                                .foregroundColor(.orange)
                            
                            Text(item.url.path)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button("Показати") {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.url.path)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    // Вкладка "Налаштування Смітника"
    private var trashConfigTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Автоматичне очищення Смітника")
                        .font(.headline)
                        .foregroundColor(DT.Color.textPrimary)
                    
                    Toggle("Автоматично видаляти елементи зі Смітника старше N днів", isOn: $autoPurgeTrash)
                        .toggleStyle(SwitchToggleStyle())
                    
                    if autoPurgeTrash {
                        HStack {
                            Text("Видаляти файли старші за")
                            Picker("", selection: $autoPurgeTrashDays) {
                                Text("15 днів").tag(15)
                                Text("30 днів").tag(30)
                                Text("60 днів").tag(60)
                                Text("90 днів").tag(90)
                            }
                            .frame(width: 150)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Button("Очистити Смітник зараз вручну") {
                        let deletedCount = manager.purgeTrashItems(olderThanDays: autoPurgeTrashDays)
                        activeAlert = AlertInfo(
                            title: "Смітник очищено",
                            message: "Видалено елементів зі Смітника: \(deletedCount)"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding()
                .liquidGlass(radius: DT.Radius.lg)
            }
            .padding()
        }
    }
    
    // Хелпери
    private func placeholderView(systemName: String, text: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemName)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(text)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        checkedLargeFiles.removeAll()
        checkedOldDownloads.removeAll()
        checkedEmptyFolders.removeAll()
        
        let sizeLimit = Int64(minSizeMB) ?? 100
        let daysLimit = Int(oldDownloadsDays) ?? 30
        
        if selectedTab == "large_files" {
            manager.scanLargeFiles(at: scanPath, minSizeMB: sizeLimit) {}
        } else if selectedTab == "old_downloads" {
            manager.scanOldDownloads(daysThreshold: daysLimit) {}
        } else if selectedTab == "empty_folders" {
            manager.scanEmptyFolders(at: scanPath) {}
        }
    }
    
    private func prepareDeletion(source: String) {
        deletionSource = source
        if source == "large" {
            itemsToDeleteCount = checkedLargeFiles.count
            itemsToDeleteSize = checkedLargeFiles.reduce(0) { sum, url in
                sum + (manager.largeFiles.first(where: { $0.url == url })?.size ?? 0)
            }
        } else if source == "downloads" {
            itemsToDeleteCount = checkedOldDownloads.count
            itemsToDeleteSize = checkedOldDownloads.reduce(0) { sum, url in
                sum + (manager.oldDownloads.first(where: { $0.url == url })?.size ?? 0)
            }
        } else if source == "folders" {
            itemsToDeleteCount = checkedEmptyFolders.count
            itemsToDeleteSize = 0 // Папки самі по собі не займають розмір
        }
        showConfirmDelete = true
    }
    
    private func performCheckedDeletion() {
        let fileManager = FileManager.default
        var deletedBytes: Int64 = 0
        var deletedCount = 0
        
        let targetURLs: Set<URL>
        if deletionSource == "large" {
            targetURLs = checkedLargeFiles
        } else if deletionSource == "downloads" {
            targetURLs = checkedOldDownloads
        } else {
            targetURLs = checkedEmptyFolders
        }
        
        for url in targetURLs {
            let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                deletedBytes += size
                deletedCount += 1
            } catch {
                print("[CLEANUP] Не вдалося видалити \(url.path): \(error.localizedDescription)")
            }
        }
        
        // Оновлюємо статистику в Dashboard
        let oldFreed = UserDefaults.standard.double(forKey: "FreedBytesTotal")
        UserDefaults.standard.set(oldFreed + Double(deletedBytes), forKey: "FreedBytesTotal")
        
        let oldDuplicates = UserDefaults.standard.integer(forKey: "FreedDuplicatesCount")
        UserDefaults.standard.set(oldDuplicates + deletedCount, forKey: "FreedDuplicatesCount")
        
        // Записуємо звільнений простір в історію
        let dateKey = DateFormatter.FreedSpaceFormatter.string(from: Date())
        var savedFreedHistory = UserDefaults.standard.dictionary(forKey: "freed_history") as? [String: Double] ?? [:]
        savedFreedHistory[dateKey, default: 0.0] += Double(deletedBytes)
        UserDefaults.standard.set(savedFreedHistory, forKey: "freed_history")
        
        // Пересканувати
        startScan()
    }
    
    private func createAutoArchiveRule(for url: URL) {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return }
        
        let ruleName = "Авто-Архів великих .\(ext) файлів"
        
        // Умови: розширення = ext, розмір > 100MB
        let conditions = [
            RuleCondition(type: .extensionIs, value: ext),
            RuleCondition(type: .sizeGreaterThan, value: "104857600")
        ]
        
        // Дія: архівувати
        let actions = [
            RuleAction(type: .archiveToZIP, value: "")
        ]
        
        let newRule = Rule(name: ruleName, enabled: true, conditions: conditions, actions: actions)
        
        // Додаємо в поточні правила RuleEngine та зберігаємо
        RuleEngine.shared.rules.append(newRule)
        RuleEngine.shared.saveRules()
        
        activeAlert = AlertInfo(
            title: "Правило створено",
            message: "Автоматичне правило '\(ruleName)' додано до активного профілю."
        )
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }
    
}
