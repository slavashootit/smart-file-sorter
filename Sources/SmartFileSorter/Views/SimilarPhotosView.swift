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
                        .foregroundColor(DT.Color.textPrimary)
                    
                    HStack {
                        Text("Поріг схожості ( Vision AI ): \(String(format: "%.2f", displayThreshold))")
                            .font(.caption)
                            .foregroundColor(DT.Color.textSecondary)
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
                    .tint(DT.Color.accent)
                }
            }
            .padding()
            .liquidGlass(radius: 0)
            
            if finder.isScanning {
                VStack(spacing: 12) {
                    ProgressView(value: finder.progress)
                        .progressViewStyle(.linear)
                        .shimmer()
                        .padding(.horizontal)
                    Text(finder.currentFile)
                        .font(.caption)
                        .foregroundColor(DT.Color.textSecondary)
                        .lineLimit(1)
                }
                .padding()
                Spacer()
            } else if finder.similarGroups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(DT.Color.textTertiary)
                    Text("Не знайдено схожих фотографій")
                        .font(.headline)
                        .foregroundColor(DT.Color.textPrimary)
                    Text("Спробуйте збільшити поріг схожості або обрати іншу папку.")
                        .font(.subheadline)
                        .foregroundColor(DT.Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Панель підсумку та видалення
                HStack {
                    Text("Знайдено груп схожих фото: \(finder.similarGroups.count) | Позначено для видалення: \(checkedFiles.count)")
                        .font(DT.Font.bodyWeight(13, weight: .semibold))
                        .foregroundColor(DT.Color.textPrimary)
                    
                    Spacer()
                    
                    if !checkedFiles.isEmpty {
                        Button(action: { checkedFiles.removeAll() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                Text("Скинути вибір")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button(action: {
                        if !checkedFiles.isEmpty {
                            showConfirmDelete = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Видалити позначені в Смітник (\(checkedFiles.count))")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(checkedFiles.isEmpty)
                }
                .padding()
                .background(DT.Color.glass)
                
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
                                            .cornerRadius(DT.Radius.sm)
                                            .clipped()
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(firstPhoto.lastPathComponent)
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                            .foregroundColor(DT.Color.textPrimary)
                                        Text("\(group.photos.count) схожих знімків")
                                            .font(.caption)
                                            .foregroundColor(DT.Color.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Badge: скільки обрано з цієї групи
                                    let selectedInGroup = group.photos.filter { checkedFiles.contains($0) }.count
                                    if selectedInGroup > 0 {
                                        Text("\(selectedInGroup)")
                                            .font(DT.Font.mono(10))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.red))
                                    }
                                }
                            }
                            .tag(group.id)
                        }
                    }
                    .frame(minWidth: 250, idealWidth: 320)
                    
                    // Права колонка: перегляд та порівняння фото в групі
                    if let selectedGroup = finder.similarGroups.first(where: { $0.id == selectedGroupId }) {
                        VStack(spacing: 0) {
                            // Toolbar з кнопками масового вибору
                            HStack(spacing: 12) {
                                let selectedInGroup = selectedGroup.photos.filter { checkedFiles.contains($0) }.count
                                
                                Text("\(selectedInGroup) з \(selectedGroup.photos.count) обрано")
                                    .font(DT.Font.body(12))
                                    .foregroundColor(DT.Color.textSecondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    // Вибрати всі крім першого (оригіналу)
                                    Haptics.alignment()
                                    for photo in selectedGroup.photos.dropFirst() {
                                        checkedFiles.insert(photo)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Вибрати копії")
                                    }
                                    .font(DT.Font.body(12))
                                }
                                .buttonStyle(.bordered)
                                .help("Позначити всі крім першого (оригіналу)")
                                
                                Button(action: {
                                    // Зняти вибір в цій групі
                                    for photo in selectedGroup.photos {
                                        checkedFiles.remove(photo)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle")
                                        Text("Зняти вибір")
                                    }
                                    .font(DT.Font.body(12))
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(DT.Color.glass)
                            
                            // Grid з фотографіями
                            ScrollView(.vertical) {
                                // Підказка
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.tap")
                                        .foregroundColor(DT.Color.accent)
                                    Text("Натисніть на фото щоб позначити для видалення")
                                        .font(DT.Font.body(11))
                                        .foregroundColor(DT.Color.textTertiary)
                                }
                                .padding(.top, 8)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 16) {
                                    ForEach(Array(selectedGroup.photos.enumerated()), id: \.element) { index, photoURL in
                                        let isChecked = checkedFiles.contains(photoURL)
                                        let isOriginal = index == 0
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Фото preview — клік на все фото для вибору
                                            ZStack(alignment: .topLeading) {
                                                ZStack(alignment: .topTrailing) {
                                                    if let thumb = thumbCache.thumbnail(for: photoURL, maxSize: 400) {
                                                        Image(nsImage: thumb)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(height: 180)
                                                            .cornerRadius(DT.Radius.sm)
                                                            .shadow(radius: 2)
                                                    } else {
                                                        RoundedRectangle(cornerRadius: DT.Radius.sm)
                                                            .fill(DT.Color.glass)
                                                            .frame(height: 180)
                                                            .overlay(Text("Помилка завантаження").font(.caption).foregroundColor(DT.Color.textTertiary))
                                                    }
                                                    
                                                    // Чекбокс великий та помітний
                                                    ZStack {
                                                        Circle()
                                                            .fill(isChecked ? DT.Color.accent : Color.black.opacity(0.5))
                                                            .frame(width: 28, height: 28)
                                                        
                                                        Circle()
                                                            .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
                                                            .frame(width: 28, height: 28)
                                                        
                                                        if isChecked {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 14, weight: .bold))
                                                                .foregroundColor(.white)
                                                        }
                                                    }
                                                    .padding(8)
                                                }
                                                .overlay(
                                                    // Яскрава рамка на вибраних
                                                    RoundedRectangle(cornerRadius: DT.Radius.sm)
                                                        .strokeBorder(
                                                            isChecked ? DT.Color.accent : Color.clear,
                                                            lineWidth: 3
                                                        )
                                                )
                                                .opacity(isChecked ? 0.75 : 1.0)
                                                
                                                // Бейдж "Оригінал" на першому фото
                                                if isOriginal {
                                                    Text("ОРИГІНАЛ")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(Capsule().fill(DT.Color.success))
                                                        .padding(8)
                                                }
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                withAnimation(DT.Animation.springFast) {
                                                    if isChecked {
                                                        checkedFiles.remove(photoURL)
                                                    } else {
                                                        checkedFiles.insert(photoURL)
                                                    }
                                                    Haptics.alignment()
                                                }
                                            }
                                            
                                            // Інформація про файл
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(photoURL.lastPathComponent)
                                                        .font(DT.Font.body(12))
                                                        .fontWeight(.bold)
                                                        .lineLimit(1)
                                                        .foregroundColor(DT.Color.textPrimary)
                                                    
                                                    Text("Розмір: \(formatBytes(getFileSize(photoURL)))  •  \(getImageDimensions(for: photoURL))")
                                                        .font(DT.Font.mono(10))
                                                        .foregroundColor(DT.Color.textSecondary)
                                                    
                                                    Text("Змінено: \(formatDate(getFileDate(photoURL)))")
                                                        .font(DT.Font.mono(10))
                                                        .foregroundColor(DT.Color.textTertiary)
                                                }
                                                
                                                Spacer()
                                            }
                                            
                                            HStack(spacing: 8) {
                                                Button(action: {
                                                    withAnimation(DT.Animation.springFast) {
                                                        if isChecked {
                                                            checkedFiles.remove(photoURL)
                                                        } else {
                                                            checkedFiles.insert(photoURL)
                                                        }
                                                        Haptics.alignment()
                                                    }
                                                }) {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                                            .foregroundColor(isChecked ? DT.Color.accent : DT.Color.textTertiary)
                                                        Text(isChecked ? "Обрано" : "Обрати")
                                                            .font(DT.Font.body(12))
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                                
                                                Spacer()
                                                
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
                                        .padding(10)
                                        .liquidGlass(radius: DT.Radius.md)
                                    }
                                }
                                .padding()
                            }
                        }
                        .frame(minWidth: 350)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "hand.point.left")
                                .font(.system(size: 32))
                                .foregroundColor(DT.Color.textTertiary)
                            Text("Оберіть групу фотографій зліва")
                                .font(DT.Font.body(14))
                                .foregroundColor(DT.Color.textSecondary)
                            Text("Потім натискайте на фото щоб позначити для видалення")
                                .font(DT.Font.body(12))
                                .foregroundColor(DT.Color.textTertiary)
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
