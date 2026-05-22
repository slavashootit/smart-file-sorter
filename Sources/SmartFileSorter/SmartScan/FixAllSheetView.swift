import SwiftUI

struct FixAllSheetView: View {
    @Binding var issues: [ScanIssue]
    let onCancel: () -> Void
    let onConfirm: ([ScanIssue]) -> Void

    private var selectedIssues: [ScanIssue] { issues.filter(\.isSelected) }
    private var totalSelected: Int64 { selectedIssues.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Що перемістити в Кошик?")
                    .font(DT.subheadFont).bold()
                    .foregroundStyle(DT.label)
                Text("Зніми галочку — і файл залишиться. Дія незворотна лише після спустошення Кошика.")
                    .font(DT.captionFont)
                    .foregroundStyle(DT.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Divider().background(DT.separator)

            // Checklist grouped by category
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(ScanIssueCategory.allCases, id: \.self) { category in
                        let categoryIssues = issues.indices.filter { issues[$0].category == category }
                        if !categoryIssues.isEmpty {
                            SheetSectionHeader(category: category,
                                              totalBytes: categoryIssues.reduce(0) { $0 + issues[$1].bytes })
                            ForEach(categoryIssues, id: \.self) { idx in
                                SheetItemRow(issue: $issues[idx])
                            }
                        }
                    }
                }
            }

            Divider().background(DT.separator)

            // Footer
            HStack(spacing: 10) {
                Button("Скасувати") { onCancel() }
                    .buttonStyle(SecondaryButtonStyle())

                Text("\(selectedIssues.count) з \(issues.count) вибрано")
                    .font(DT.captionFont)
                    .foregroundStyle(DT.label3)
                    .frame(maxWidth: .infinity)

                Button("Перемістити в Кошик") { onConfirm(selectedIssues) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedIssues.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SheetSectionHeader: View {
    let category: ScanIssueCategory
    let totalBytes: Int64
    var body: some View {
        HStack {
            Text(category.displayName.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DT.label3)
                .tracking(0.5)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                .font(.caption2)
                .foregroundStyle(DT.label3)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

struct SheetItemRow: View {
    @Binding var issue: ScanIssue

    var body: some View {
        Button { issue.isSelected.toggle() } label: {
            HStack(spacing: 12) {
                Checkbox(isChecked: issue.isSelected)

                VStack(alignment: .leading, spacing: 1) {
                    Text(issue.displayName)
                        .font(DT.bodyFont)
                        .foregroundStyle(DT.label)
                        .lineLimit(1)
                    Text(issue.detail)
                        .font(DT.captionFont)
                        .foregroundStyle(DT.label2)
                        .lineLimit(1)
                }

                Spacer()

                Text(ByteCountFormatter.string(fromByteCount: issue.bytes, countStyle: .file))
                    .font(DT.captionFont)
                    .foregroundStyle(DT.label2)
                    .monospacedDigit()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Checkbox: View {
    let isChecked: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(isChecked ? Color.blue : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isChecked ? Color.blue : Color.white.opacity(0.25), lineWidth: 1.5)
                )
                .frame(width: 18, height: 18)
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isChecked)
    }
}
