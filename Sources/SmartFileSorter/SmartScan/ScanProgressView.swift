import SwiftUI

struct ScanProgressView: View {
    let progress: ScanProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Scan")
                    .font(DT.titleFont)
                    .foregroundStyle(DT.label)
                Text(progress.currentPath.isEmpty ? "Аналізую…" : progress.currentPath)
                    .font(DT.captionFont)
                    .foregroundStyle(DT.label2)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)

            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(currentStepLabel)
                        .font(DT.captionFont)
                        .foregroundStyle(DT.label2)
                    Spacer()
                    Text("\(Int(progress.overallFraction * 100))%")
                        .font(DT.captionFont)
                        .foregroundStyle(.blue)
                        .monospacedDigit()
                }
                ScanProgressBar(fraction: progress.overallFraction)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)

            // Steps
            VStack(spacing: 0) {
                ScanStepRow(name: "Очищення — тимчасові файли, кеш",    state: progress.cleanup)
                Divider().background(DT.separator)
                ScanStepRow(name: "Дублікати — XXHash64 two-pass",        state: progress.duplicates)
                Divider().background(DT.separator)
                ScanStepRow(name: "Схожі фото — Vision AI",               state: progress.similarPhotos)
            }
            .padding(.horizontal, 28)

            Spacer()
        }
    }

    private var currentStepLabel: String {
        if case .running = progress.similarPhotos { return "Схожі фото — Vision AI" }
        if case .running = progress.duplicates     { return "Дублікати — перевірка хешів" }
        if case .running = progress.cleanup        { return "Очищення — пошук файлів" }
        return "Підготовка…"
    }
}

// ── Progress bar з shimmer ──────────────────────────────────
struct ScanProgressBar: View {
    let fraction: Double
    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 8)

                // Fill + shimmer
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(colors: [.blue, Color(red: 0.18, green: 0.66, blue: 1.0), .blue],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * fraction, height: 8)
                    .overlay(
                        // Shimmer stripe
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .white.opacity(0.5), location: 0.45),
                                .init(color: .white.opacity(0.7), location: 0.5),
                                .init(color: .white.opacity(0.5), location: 0.55),
                                .init(color: .clear, location: 1.0),
                            ],
                            startPoint: .init(x: shimmerOffset, y: 0),
                            endPoint:   .init(x: shimmerOffset + 1, y: 0)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    )
                    .animation(.easeOut(duration: 0.4), value: fraction)

                // Glow under bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(.blue.opacity(0.4))
                    .frame(width: geo.size.width * fraction, height: 4)
                    .blur(radius: 6)
                    .offset(y: 8)
            }
        }
        .frame(height: 8)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                shimmerOffset = 2.0
            }
        }
    }
}

// ── Step row ────────────────────────────────────────────────
struct ScanStepRow: View {
    let name: String
    let state: ScanProgress.StepState

    var body: some View {
        HStack(spacing: 12) {
            StepDot(state: state)
            Text(name)
                .font(DT.bodyFont)
                .foregroundStyle(DT.label)
            Spacer()
            Text(statusText)
                .font(DT.captionFont)
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 11)
    }

    private var statusText: String {
        switch state {
        case .waiting:               return "Очікування"
        case .running:               return "Виконується…"
        case .done(let summary):     return summary
        }
    }
    private var statusColor: Color {
        switch state {
        case .waiting:  return DT.label3
        case .running:  return .blue
        case .done:     return DT.green
        }
    }
}

struct StepDot: View {
    let state: ScanProgress.StepState
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.7

    var body: some View {
        ZStack {
            if case .running = state {
                Circle()
                    .stroke(.blue.opacity(ringOpacity), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                    .scaleEffect(ringScale)
            }
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
        }
        .frame(width: 16, height: 16)
        .onAppear {
            if case .running = state {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    ringScale = 2.0
                    ringOpacity = 0.0
                }
            }
        }
    }

    private var dotColor: Color {
        switch state {
        case .waiting: return DT.label3
        case .running: return .blue
        case .done:    return DT.green
        }
    }
}
