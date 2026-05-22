import SwiftUI

struct ScanResultsView: View {
    @Binding var results: ScanResults
    let onFixAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Знайдено \(ByteCountFormatter.string(fromByteCount: results.totalBytes, countStyle: .file))")
                        .font(DT.titleFont)
                        .foregroundStyle(DT.label)
                    Text("· \(results.issueCount) об'єктів")
                        .font(DT.bodyFont)
                        .foregroundStyle(DT.label2)
                }
                Text("Скан завершено · \(results.scannedPath.lastPathComponent) · щойно")
                    .font(DT.captionFont)
                    .foregroundStyle(DT.label2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 18)

            Divider().background(DT.separator)

            // Priority list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(results.grouped, id: \.category) { group in
                        ResultGroupView(
                            category: group.category,
                            results: $results
                        )
                        Divider().background(DT.separator)
                    }
                }
            }

            Divider().background(DT.separator)

            // Fix All footer
            HStack {
                Text("Звільнить ")
                    .font(DT.captionFont)
                    .foregroundColor(DT.label2)
                + Text(ByteCountFormatter.string(fromByteCount: results.totalBytes, countStyle: .file))
                    .font(DT.captionFont).bold()
                    .foregroundColor(DT.label)
                + Text(" · всі файли → Кошик")
                    .font(DT.captionFont)
                    .foregroundColor(DT.label2)

                Spacer()

                Button("Fix All…") { onFixAll() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
        }
    }
}

struct ResultGroupView: View {
    let category: ScanIssueCategory
    @Binding var results: ScanResults
    @State private var isExpanded = false

    private var items: [ScanIssue] {
        results.issues.filter { $0.category == category }
    }

    private var totalBytes: Int64 {
        if category == .similarPhoto {
            // For similar photos, we only count the selected (marked for trash) issues,
            // or do we count all issues in the clusters?
            // Wait, standard totalBytes for category header shows the total bytes of ALL items in that category that are selected, or all items?
            // Let's look: `private var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }`
            // Wait, items already contains only duplicates (since original has isSelected = false, does its bytes count towards group totalBytes?
            // Yes, if items contains original and original has some bytes, it would add to the group totalBytes if we just sum them.
            // But wait, the original photo is kept, so it's not part of the space we can free!
            // Wait! The right text label shows: `totalBytes` of the group.
            // In the previous version, similarPhotos only had duplicates, so its totalBytes was the sum of duplicates.
            // In the new version, if we only sum the duplicates (i.e. isSelected == true, or rather non-original photos), that would match the space to be freed or the total size of issues.
            // Let's think: `items` for .similarPhoto contains all photos in the clusters.
            // If we only sum the non-original photos (the ones that are checked by default):
            // `results.clusters.flatMap(\.photos).filter { !$0.isSelected }`?
            // Wait, the duplicates are `isSelected = true`. The original is `isSelected = false`.
            // So if we sum all photos of category .similarPhoto that are NOT the original, or all?
            // Let's sum the duplicate photos: `items.filter { !results.clusters.first(where: { c in c.photos.contains(where: { $0.id == $0.id }) })?.photos[c.originalIndex].id == $0.id }.reduce(0) { $0 + $1.bytes }`
            // Actually, we can just sum the bytes of all photos in the clusters except the original ones!
            // That is: `results.clusters.reduce(0) { sum, cluster in sum + cluster.photos.enumerated().filter { $0.offset != cluster.originalIndex }.reduce(0) { $0 + $1.element.bytes } }`
            // Yes! That is exactly the sum of sizes of all duplicates!
            return results.clusters.reduce(0) { sum, cluster in
                sum + cluster.photos.enumerated()
                    .filter { $0.offset != cluster.originalIndex }
                    .reduce(0) { $0 + $1.element.bytes }
            }
        }
        return items.reduce(0) { $0 + $1.bytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(category.color)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.displayName)
                            .font(DT.subheadFont)
                            .foregroundStyle(DT.label)
                        Text(category.description)
                            .font(DT.captionFont)
                            .foregroundStyle(DT.label2)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                            .font(DT.subheadFont)
                            .foregroundStyle(DT.label)
                            .monospacedDigit()
                        if category == .similarPhoto {
                            Text("\(results.clusters.count) \(category.itemLabel)")
                                .font(DT.captionFont)
                                .foregroundStyle(DT.label3)
                        } else {
                            Text("\(items.count) \(category.itemLabel)")
                                .font(DT.captionFont)
                                .foregroundStyle(DT.label3)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DT.label3)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Items (expanded)
            if isExpanded {
                VStack(spacing: 0) {
                    if category == .similarPhoto {
                        ForEach(results.clusters) { cluster in
                            ClusterRowView(cluster: cluster, results: $results)
                            if cluster.id != results.clusters.last?.id {
                                Divider().padding(.leading, 48).background(DT.separator)
                            }
                        }
                    } else {
                        ForEach(items) { issue in
                            HStack(spacing: 10) {
                                Image(systemName: category.fileIcon)
                                    .font(.caption)
                                    .foregroundStyle(DT.label2)
                                    .frame(width: 28, height: 28)
                                    .background(DT.bg3)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(issue.displayName)
                                        .font(DT.captionFont)
                                        .foregroundStyle(DT.label)
                                        .lineLimit(1)
                                    Text(issue.detail)
                                        .font(.caption2)
                                        .foregroundStyle(DT.label3)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(ByteCountFormatter.string(fromByteCount: issue.bytes, countStyle: .file))
                                    .font(DT.captionFont)
                                    .foregroundStyle(DT.label2)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 7)
                            .padding(.leading, 48)
                            .padding(.trailing, 28)

                            if issue.id != items.last?.id {
                                Divider().padding(.leading, 48).background(DT.separator)
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}

// ── Category helpers ────────────────────────────────────────
extension ScanIssueCategory {
    var displayName: String {
        switch self {
        case .cleanup:      return "Очищення"
        case .duplicate:    return "Дублікати"
        case .similarPhoto: return "Схожі фото"
        }
    }
    var description: String {
        switch self {
        case .cleanup:      return "Кеш, логи, тимчасові файли — безпечно видалити"
        case .duplicate:    return "Ідентичні файли у різних папках"
        case .similarPhoto: return "Vision AI знайшов схожі кластери — потрібне рішення"
        }
    }
    var itemLabel: String {
        switch self {
        case .cleanup:      return "файл"
        case .duplicate:    return "груп"
        case .similarPhoto: return "кластери"
        }
    }
    var color: Color {
        switch self {
        case .cleanup:      return DT.green
        case .duplicate:    return .yellow
        case .similarPhoto: return .orange
        }
    }
    var fileIcon: String {
        switch self {
        case .cleanup:      return "trash"
        case .duplicate:    return "doc.on.doc"
        case .similarPhoto: return "photo.on.rectangle.angled"
        }
    }
}
