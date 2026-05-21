import SwiftUI

public struct DiskMeter: View {
    @State private var usedBytes: Int64 = 0
    @State private var totalBytes: Int64 = 1

    private var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    private var freeBytes: Int64 {
        max(0, totalBytes - usedBytes)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Macintosh HD")
                    .font(DT.Font.body(11))
                    .foregroundColor(DT.Color.textTertiary)
                Spacer()
                Text("\(formatBytes(freeBytes)) вільно")
                    .font(DT.Font.mono(11))
                    .foregroundColor(DT.Color.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DT.Color.glass)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [DT.Color.accent, DT.Color.accentStrong],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * usedFraction)
                        .shimmer()
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .task {
            await loadDiskUsage()
        }
    }

    private func loadDiskUsage() async {
        do {
            let homeURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try homeURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            if let total = values.volumeTotalCapacity,
               let available = values.volumeAvailableCapacityForImportantUsage {
                await MainActor.run {
                    totalBytes = Int64(total)
                    usedBytes = Int64(total) - available
                }
            }
        } catch {
            // Silently fail — disk meter is non-critical
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
