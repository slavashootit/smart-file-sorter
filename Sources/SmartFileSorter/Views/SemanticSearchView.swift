import SwiftUI
import AppKit

struct SemanticSearchView: View {
    @StateObject private var searchEngine = SemanticSearchEngine.shared
    @State private var queryText: String = ""
    @State private var searchPath: String = NSHomeDirectory() + "/Downloads"
    @State private var searchResults: [SearchResultItem] = []
    @State private var isSearching = false
    private class CancellationToken {
        private let lock = NSLock()
        private var _isCancelled = false
        
        var isCancelled: Bool {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _isCancelled
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _isCancelled = newValue
            }
        }
    }
    @State private var activeCancellation: CancellationToken? = nil
    @State private var statusText: String = ""
    @State private var progress: Double = 0.0
    
    struct SearchResultItem: Identifiable {
        let id = UUID()
        let url: URL
        let similarity: Float
        let labels: [String]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Верхня панель пошуку
            HStack(spacing: 12) {
                TextField("Введіть запит (напр., 'beach', 'cat', 'food', 'car')...", text: $queryText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit { performSearch() }
                
                TextField("Шлях", text: $searchPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 120, idealWidth: 180, maxWidth: 220)
                
                Button(action: selectFolder) {
                    Image(systemName: "folder")
                }
                
                if isSearching {
                    Button("Скасувати") {
                        activeCancellation?.isCancelled = true
                        isSearching = false
                        statusText = "Пошук скасовано"
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button(action: performSearch) {
                        Label("Шукати", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(queryText.isEmpty)
                }
            }
            .padding()
            .liquidGlass(radius: 0)
            
            if isSearching {
                VStack(spacing: 16) {
                    ProgressView(value: progress)
                        .shimmer()
                        .frame(width: 300)
                    Text(statusText)
                        .foregroundColor(DT.Color.textSecondary)
                        .font(.caption)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !queryText.isEmpty && statusText == "done" {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(DT.Color.textSecondary)
                    Text("Нічого не знайдено за запитом «\(queryText)»")
                        .font(.headline)
                        .foregroundColor(DT.Color.textSecondary)
                    Text("Спробуйте інші англійські ключові слова: cat, dog, beach, food, person, car, sky, tree...")
                        .font(.caption)
                        .foregroundColor(DT.Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(DT.Color.accent)
                        .padding()
                    Text("Семантичний пошук фотографій")
                        .font(.headline)
                        .foregroundColor(DT.Color.textPrimary)
                    Text("Введіть англійський текстовий запит. Vision AI розпізнає об'єкти на зображеннях.")
                        .font(.caption)
                        .foregroundColor(DT.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Приклади запитів:").font(.caption).bold()
                        Text("cat · dog · beach · sunset · food · car · person · flower · sky · tree · building")
                            .font(.caption)
                            .foregroundColor(DT.Color.accentStrong)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Результати
                VStack(spacing: 0) {
                    HStack {
                        Text("Знайдено результатів: \(searchResults.count)")
                            .fontWeight(.semibold)
                            .foregroundColor(DT.Color.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(DT.Color.glass)
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 16) {
                            ForEach(searchResults) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    // Thumbnail via CGImageSource (lightweight)
                                    if let imageSource = CGImageSourceCreateWithURL(item.url as CFURL, nil),
                                       let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
                                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 400,
                                        kCGImageSourceCreateThumbnailWithTransform: true
                                       ] as CFDictionary) {
                                        Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 120)
                                            .clipped()
                                            .cornerRadius(DT.Radius.sm)
                                    } else {
                                        RoundedRectangle(cornerRadius: DT.Radius.sm)
                                            .fill(DT.Color.glass)
                                            .frame(height: 120)
                                            .overlay(Image(systemName: "photo").foregroundColor(DT.Color.textTertiary))
                                    }
                                    
                                    Text(item.url.lastPathComponent)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .bold()
                                        .foregroundColor(DT.Color.textPrimary)
                                    
                                    // Show matched labels
                                    if !item.labels.isEmpty {
                                        Text(item.labels.prefix(5).joined(separator: ", "))
                                            .font(.system(size: 9))
                                            .foregroundColor(DT.Color.accentStrong)
                                            .lineLimit(2)
                                    }
                                    
                                    HStack {
                                        Text(String(format: "Впевненість: %.0f%%", item.similarity * 100))
                                            .font(.caption2)
                                            .foregroundColor(DT.Color.textSecondary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            NSWorkspace.shared.activateFileViewerSelecting([item.url])
                                        }) {
                                            Image(systemName: "eye")
                                                .font(.caption2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(8)
                                .liquidGlass(radius: DT.Radius.md)
                            }
                        }
                        .padding()
                    }
                }
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
                searchPath = path
            }
        }
    }
    
    private func performSearch() {
        guard !queryText.isEmpty else { return }
        isSearching = true
        searchResults = []
        progress = 0.0
        statusText = "Пошук зображень..."
        
        let pathURL = URL(fileURLWithPath: searchPath)
        let query = queryText
        
        let token = CancellationToken()
        self.activeCancellation = token
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let enumerator = fileManager.enumerator(at: pathURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            
            var imageURLs: [URL] = []
            let allowedExtensions = Set(["png", "jpg", "jpeg", "heic"])
            
            while let fileURL = enumerator?.nextObject() as? URL {
                if token.isCancelled { return }
                let ext = fileURL.pathExtension.lowercased()
                if allowedExtensions.contains(ext) {
                    imageURLs.append(fileURL)
                }
            }
            
            if imageURLs.isEmpty {
                DispatchQueue.main.async {
                    self.isSearching = false
                    self.statusText = "done"
                }
                return
            }
            
            let totalCount = imageURLs.count
            var matchedItems: [SearchResultItem] = []
            var processedCount = 0
            var lastProgressUpdate = Date()
            
            for url in imageURLs {
                if token.isCancelled { break }
                
                // Synchronous classification — safe on background thread
                let labels = self.searchEngine.classifyImageSync(at: url)
                let score = self.searchEngine.searchByText(query: query, in: labels)
                
                if score > 0.3 {
                    matchedItems.append(SearchResultItem(url: url, similarity: score, labels: labels))
                }
                
                processedCount += 1
                
                // Throttle UI updates to every 200ms to avoid main thread flood
                let now = Date()
                if now.timeIntervalSince(lastProgressUpdate) > 0.2 || processedCount == totalCount {
                    lastProgressUpdate = now
                    let currentProgress = Double(processedCount) / Double(totalCount)
                    let filename = url.lastPathComponent
                    let count = processedCount
                    DispatchQueue.main.async {
                        if !token.isCancelled {
                            self.progress = currentProgress
                            self.statusText = "Vision AI: \(filename) (\(count)/\(totalCount))"
                        }
                    }
                }
            }
            
            if token.isCancelled { return }
            
            matchedItems.sort { $0.similarity > $1.similarity }
            
            DispatchQueue.main.async {
                if !token.isCancelled {
                    self.searchResults = matchedItems
                    self.isSearching = false
                    self.statusText = "done"
                }
            }
        }
    }
}
