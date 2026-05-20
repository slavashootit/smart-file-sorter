import SwiftUI
import AppKit

struct SemanticSearchView: View {
    @StateObject private var searchEngine = SemanticSearchEngine.shared
    @State private var queryText: String = ""
    @State private var searchPath: String = NSHomeDirectory() + "/Downloads"
    @State private var searchResults: [SearchResultItem] = []
    @State private var isSearching = false
    @State private var isCancelled = false
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
                        isCancelled = true
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
            
            Divider()
            
            if isSearching {
                VStack(spacing: 16) {
                    ProgressView(value: progress)
                        .frame(width: 300)
                    Text(statusText)
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !queryText.isEmpty && statusText == "done" {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Нічого не знайдено за запитом «\(queryText)»")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Спробуйте інші англійські ключові слова: cat, dog, beach, food, person, car, sky, tree...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                        .padding()
                    Text("Семантичний пошук фотографій")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Введіть англійський текстовий запит. Vision AI розпізнає об'єкти на зображеннях.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Приклади запитів:").font(.caption).bold()
                        Text("cat · dog · beach · sunset · food · car · person · flower · sky · tree · building")
                            .font(.caption)
                            .foregroundColor(.blue)
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
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    
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
                                            .cornerRadius(8)
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(height: 120)
                                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                                    }
                                    
                                    Text(item.url.lastPathComponent)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .bold()
                                    
                                    // Show matched labels
                                    if !item.labels.isEmpty {
                                        Text(item.labels.prefix(5).joined(separator: ", "))
                                            .font(.system(size: 9))
                                            .foregroundColor(.blue)
                                            .lineLimit(2)
                                    }
                                    
                                    HStack {
                                        Text(String(format: "Впевненість: %.0f%%", item.similarity * 100))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
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
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(12)
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
        isCancelled = false
        searchResults = []
        progress = 0.0
        statusText = "Пошук зображень..."
        
        let pathURL = URL(fileURLWithPath: searchPath)
        let query = queryText
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let enumerator = fileManager.enumerator(at: pathURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            
            var imageURLs: [URL] = []
            let allowedExtensions = Set(["png", "jpg", "jpeg", "heic"])
            
            while let fileURL = enumerator?.nextObject() as? URL {
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
            
            // Process sequentially on this background thread — no semaphores, no deadlocks
            // Vision is already GPU-accelerated, adding thread parallelism causes contention
            for url in imageURLs {
                if self.isCancelled { break }
                
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
                        self.progress = currentProgress
                        self.statusText = "Vision AI: \(filename) (\(count)/\(totalCount))"
                    }
                }
            }
            
            matchedItems.sort { $0.similarity > $1.similarity }
            
            DispatchQueue.main.async {
                self.searchResults = matchedItems
                self.isSearching = false
                self.statusText = "done"
            }
        }
    }
}
