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
                            items: group.items
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
    let items: [ScanIssue]
    @State private var isExpanded = false

    private var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }

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
                        Text("\(items.count) \(category.itemLabel)")
                            .font(DT.captionFont)
                            .foregroundStyle(DT.label3)
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
