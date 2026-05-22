import SwiftUI

struct ClusterRowView: View {
    let cluster: ScanCluster
    @Binding var results: ScanResults
    @State private var isExpanded = false
    @State private var isDeleting = false
    
    private var checkedIssues: [ScanIssue] {
        cluster.photos.filter(\.isSelected)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Collapsed state / Header row
            Button {
                withAnimation(DT.Animation.springFast) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DT.label3)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12, height: 12)
                    
                    // Mini-strip: up to 4 thumbnails of 28px
                    HStack(spacing: 4) {
                        ForEach(cluster.photos.prefix(4)) { photo in
                            if let firstURL = photo.urls.first {
                                ThumbnailView(url: firstURL, size: 28)
                            }
                        }
                    }
                    
                    // Name and count
                    Text("Кластер · \(cluster.photos.count) фото")
                        .font(DT.subheadFont)
                        .foregroundStyle(DT.label)
                    
                    Spacer()
                    
                    // Folder path
                    if let firstPhoto = cluster.photos.first, let firstURL = firstPhoto.urls.first {
                        Text(formatFolder(firstURL))
                            .font(DT.captionFont)
                            .foregroundStyle(DT.label2)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 10)
                .padding(.leading, 48)
                .padding(.trailing, 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded state
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()
                        .padding(.leading, 48)
                        .background(DT.separator)
                    
                    Text("Оберіть які залишити, решта — в Кошик")
                        .font(DT.captionFont)
                        .foregroundStyle(DT.label2)
                        .padding(.leading, 48)
                    
                    // Horizontal scroll view for 72px thumbnails
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(cluster.photos.indices, id: \.self) { idx in
                                let photo = cluster.photos[idx]
                                let isOriginal = (idx == cluster.originalIndex)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    if let url = photo.urls.first {
                                        ThumbnailView(url: url, size: 72)
                                            .opacity(isOriginal ? 0.6 : 1.0)
                                        
                                        Text(url.lastPathComponent)
                                            .font(DT.captionFont)
                                            .foregroundStyle(isOriginal ? DT.label2 : DT.label)
                                            .lineLimit(1)
                                            .frame(width: 72, alignment: .leading)
                                        
                                        HStack(spacing: 4) {
                                            // Action Checkbox (button)
                                            Button {
                                                toggleSelection(photoID: photo.id)
                                            } label: {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(photo.isSelected ? Color.blue : Color.clear)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 4)
                                                                .stroke(photo.isSelected ? Color.blue : Color.white.opacity(0.25), lineWidth: 1)
                                                        )
                                                        .frame(width: 14, height: 14)
                                                    if photo.isSelected {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 8, weight: .bold))
                                                            .foregroundStyle(.white)
                                                    }
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Text(formatBytes(photo.bytes) + (isOriginal ? " ← оригінал" : ""))
                                                .font(.system(size: 10))
                                                .foregroundStyle(isOriginal ? DT.label3 : DT.label2)
                                                .lineLimit(1)
                                        }
                                        .frame(height: 16)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 48)
                        .padding(.trailing, 28)
                    }
                    
                    // Lower control bar: "Зняти всі" and "В Кошик (N)"
                    HStack {
                        Button("Зняти всі") {
                            uncheckAll()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Spacer()
                        
                        let deleteCount = checkedIssues.count
                        Button(action: {
                            deleteSelected()
                        }) {
                            HStack(spacing: 6) {
                                if isDeleting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("🗑 В Кошик (\(deleteCount))")
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(deleteCount == 0 || isDeleting)
                    }
                    .padding(.leading, 48)
                    .padding(.trailing, 28)
                    .padding(.bottom, 12)
                }
            }
        }
    }
    
    private func toggleSelection(photoID: UUID) {
        // 1. Update in the local cluster representation (inside results.clusters)
        if let clusterIdx = results.clusters.firstIndex(where: { $0.id == cluster.id }) {
            if let photoIdx = results.clusters[clusterIdx].photos.firstIndex(where: { $0.id == photoID }) {
                results.clusters[clusterIdx].photos[photoIdx].isSelected.toggle()
            }
        }
        // 2. Update in results.issues flat array
        if let issueIdx = results.issues.firstIndex(where: { $0.id == photoID }) {
            results.issues[issueIdx].isSelected.toggle()
        }
        // 3. Update in results.similarPhotos stored array
        if let simIdx = results.similarPhotos.firstIndex(where: { $0.id == photoID }) {
            results.similarPhotos[simIdx].isSelected.toggle()
        }
    }
    
    private func uncheckAll() {
        if let clusterIdx = results.clusters.firstIndex(where: { $0.id == cluster.id }) {
            for idx in results.clusters[clusterIdx].photos.indices {
                results.clusters[clusterIdx].photos[idx].isSelected = false
                
                let photoID = results.clusters[clusterIdx].photos[idx].id
                if let issueIdx = results.issues.firstIndex(where: { $0.id == photoID }) {
                    results.issues[issueIdx].isSelected = false
                }
                if let simIdx = results.similarPhotos.firstIndex(where: { $0.id == photoID }) {
                    results.similarPhotos[simIdx].isSelected = false
                }
            }
        }
    }
    
    private func deleteSelected() {
        let targets = checkedIssues
        guard !targets.isEmpty else { return }
        isDeleting = true
        
        let urls = targets.flatMap(\.urls)
        
        Task {
            do {
                try await SorterEngine.shared.moveToTrash(urls)
                
                await MainActor.run {
                    let deletedIDs = Set(targets.map(\.id))
                    
                    // Filter out deleted issues
                    var newIssues = results.issues.filter { !deletedIDs.contains($0.id) }
                    
                    // Update clusters
                    var newClusters: [ScanCluster] = []
                    for c in results.clusters {
                        let remainingPhotos = c.photos.filter { !deletedIDs.contains($0.id) }
                        if remainingPhotos.count >= 2 {
                            // Find largest index in remaining
                            var largestIdx = 0
                            var largestSz: Int64 = -1
                            for (idx, p) in remainingPhotos.enumerated() {
                                if p.bytes > largestSz {
                                    largestSz = p.bytes
                                    largestIdx = idx
                                }
                            }
                            newClusters.append(ScanCluster(
                                id: c.id,
                                photos: remainingPhotos,
                                originalIndex: largestIdx
                            ))
                        } else {
                            // Cluster is resolved, remove remaining single photo from issues as well
                            let remainingIDs = Set(remainingPhotos.map(\.id))
                            newIssues.removeAll { remainingIDs.contains($0.id) }
                        }
                    }
                    
                    results.issues = newIssues
                    results.similarPhotos = newIssues.filter { $0.category == .similarPhoto }
                    results.clusters = newClusters
                    
                    isDeleting = false
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                }
            }
        }
    }
    
    private func formatFolder(_ url: URL) -> String {
        let folderURL = url.deletingLastPathComponent()
        let path = folderURL.path
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct ThumbnailView: View {
    let url: URL
    let size: CGFloat
    
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: url) {
            image = await ThumbnailLoader.shared.loadThumbnail(for: url, size: size)
        }
    }
}
