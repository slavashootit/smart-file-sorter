import SwiftUI
import Vision

// Lightweight thumbnail cache to avoid reloading full-res images on every redraw
private final class ThumbnailCache: ObservableObject {
    static let shared = ThumbnailCache()
    private var cache: [URL: NSImage] = [:]
    private let lock = NSLock()
    
    func thumbnail(for url: URL, maxSize: CGFloat = 200) -> NSImage? {
        lock.lock()
        if let cached = cache[url] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        // Generate a downscaled thumbnail instead of loading the full image
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        lock.lock()
        cache[url] = nsImage
        lock.unlock()
        
        return nsImage
    }
    
    func clear() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}

public struct SimilarPhotosView: View {
    @StateObject private var finder = SimilarPhotosFinder()
    @State private var scanPath: String = NSHomeDirectory() + "/Downloads"
    @State private var threshold: Float = 0.15
    @State private var displayThreshold: Float = 0.15  // Debounced display value
    @State private var selectedGroupId: UUID? = nil
    @State private var checkedFiles: Set<URL> = []
    @State private var showConfirmDelete = false
    @State private var debounceTask: DispatchWorkItem? = nil
    
    private let thumbCache = ThumbnailCache.shared
    
    public var body: some View {
        VStack(spacing: 0) {
            // Верхня панель сканування
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Схожі фотографії")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("Поріг схожості ( Vision AI ): \(String(format: "%.2f", displayThreshold))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $displayThreshold, in: 0.05...0.35, step: 0.01)
                            .frame(width: 150)
                            .onChange(of: displayThreshold) { newValue in
                                // Debounce: apply the real threshold after 300ms of inactivity
                                debounceTask?.cancel()
                                let task = DispatchWorkItem {
                                    self.threshold = newValue
                                }
                                debounceTask = task
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
                            }
                    }
                }
                
                Spacer()
                
                TextField("Шлях для сканування", text: $scanPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 150, idealWidth: 200, maxWidth: 250)
                
                Button(action: selectFolder) {
                    Image(systemName: "folder")
                }
                
                if finder.isScanning {
                    Button(action: { finder.cancelScan() }) {
                        Text("Скасувати")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
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
            } else if finder.similarGroups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Не знайдено схожих фотографій")
                        .font(.headline)
                    Text("Спробуйте збільшити поріг схожості або обрати іншу папку.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Панель підсумку та видалення
                HStack {
                    Text("Знайдено груп схожих фото: \(finder.similarGroups.count) | Позначено для видалення: \(checkedFiles.count)")
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        if !checkedFiles.isEmpty {
                            showConfirmDelete = true
                        }
                    }) {
                        Text("Видалити позначені в Смітник (\(checkedFiles.count))")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(checkedFiles.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                // Таблиця перегляду груп та попарного preview
                HSplitView {
                    // Ліва колонка: групи схожих фотографій
                    List(selection: $selectedGroupId) {
                        ForEach(0..<finder.similarGroups.count, id: \.self) { idx in
                            let group = finder.similarGroups[idx]
                            HStack {
                                if let firstPhoto = group.photos.first {
                                    // Use cached thumbnail instead of full image
                                    if let thumb = thumbCache.thumbnail(for: firstPhoto, maxSize: 80) {
                                        Image(nsImage: thumb)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .cornerRadius(4)
                                            .clipped()
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(firstPhoto.lastPathComponent)
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                        Text("\(group.photos.count) схожих знімків")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tag(group.id)
                        }
                    }
                    .frame(minWidth: 250, idealWidth: 320)
                    
                    // Права колонка: перегляд та порівняння фото в групі side-by-side
                    if let selectedGroup = finder.similarGroups.first(where: { $0.id == selectedGroupId }) {
                        ScrollView(.vertical) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 16) {
                                ForEach(selectedGroup.photos, id: \.self) { photoURL in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Фото preview — use cached thumbnail
                                        ZStack(alignment: .topTrailing) {
                                            if let thumb = thumbCache.thumbnail(for: photoURL, maxSize: 400) {
                                                Image(nsImage: thumb)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(height: 180)
                                                    .cornerRadius(8)
                                                    .shadow(radius: 2)
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(height: 180)
                                                    .overlay(Text("Помилка завантаження").font(.caption))
                                            }
                                            
                                            Toggle("", isOn: Binding(
                                                get: { checkedFiles.contains(photoURL) },
                                                set: { isChecked in
                                                    if isChecked {
                                                        checkedFiles.insert(photoURL)
                                                    } else {
                                                        checkedFiles.remove(photoURL)
                                                    }
                                                }
                                            ))
                                            .toggleStyle(CheckboxToggleStyle())
                                            .padding(6)
                                            .background(Color.white.opacity(0.8))
                                            .cornerRadius(4)
                                            .padding(8)
                                        }
                                        
                                        // Інформація про файл
                                        Text(photoURL.lastPathComponent)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .lineLimit(1)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Розмір: \(formatBytes(getFileSize(photoURL)))")
                                            Text("Роздільна здатність: \(getImageDimensions(for: photoURL))")
                                            Text("Змінено: \(formatDate(getFileDate(photoURL)))")
                                        }
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        
                                        HStack {
                                            Button("Перегляд") {
                                                QuickLookHelper.shared.showPreview(urls: [photoURL])
                                            }
                                            .buttonStyle(.bordered)
                                            
                                            Button("Показати") {
                                                NSWorkspace.shared.selectFile(photoURL.path, inFileViewerRootedAtPath: photoURL.deletingLastPathComponent().path)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                        }
                        .frame(minWidth: 350)
                    } else {
                        VStack {
                            Text("Оберіть групу фотографій для порівняння")
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
                Text("Ви дійсно хочете перенести \(checkedFiles.count) схожих фотографій у Смітник?")
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
            if let first = finder.similarGroups.first {
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
        thumbCache.clear()
        finder.scan(at: scanPath, threshold: threshold) {
            if let first = finder.similarGroups.first {
                selectedGroupId = first.id
            }
        }
    }
    
    private func getFileSize(_ url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? Int64) ?? 0
    }
    
    private func getFileDate(_ url: URL) -> Date {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.modificationDate] as? Date) ?? Date()
    }
    
    private func getImageDimensions(for url: URL) -> String {
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) {
            if let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
                let width = imageProperties[kCGImagePropertyPixelWidth] as? Int ?? 0
                let height = imageProperties[kCGImagePropertyPixelHeight] as? Int ?? 0
                if width > 0 && height > 0 {
                    return "\(width)x\(height)"
                }
            }
        }
        return "Невідомо"
    }
    
    private func deleteSelectedFiles() {
        let fileManager = FileManager.default
        var deletedSize: Int64 = 0
        var deletedCount = 0
        
        for file in checkedFiles {
            let size = getFileSize(file)
            do {
                try fileManager.trashItem(at: file, resultingItemURL: nil)
                deletedSize += size
                deletedCount += 1
            } catch {
                print("[SIMILAR] Не вдалося видалити \(file.path): \(error.localizedDescription)")
            }
        }
        
        // Оновлюємо стастистику в Dashboard
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
        startScan() // Пересканувати для оновлення результатів
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
