import SwiftUI

public enum AppStatus: String, CaseIterable, Codable {
    case ready
    case scanning
    case sorting
    case done
    case cancelled
    
    public var label: String {
        switch self {
        case .ready: return "Готовий"
        case .scanning: return "Сканування..."
        case .sorting: return "Сортування..."
        case .done: return "Завершено"
        case .cancelled: return "Скасовано"
        }
    }
    
    public var color: Color {
        switch self {
        case .ready: return DT.Color.accent
        case .scanning: return DT.Color.warning
        case .sorting: return DT.Color.accentStrong
        case .done: return DT.Color.success
        case .cancelled: return DT.Color.danger
        }
    }
    
    public var softColor: Color {
        switch self {
        case .ready: return DT.Color.accentSoft
        case .scanning: return DT.Color.warning.opacity(0.12)
        case .sorting: return DT.Color.accentSoft
        case .done: return DT.Color.successSoft
        case .cancelled: return DT.Color.danger.opacity(0.12)
        }
    }
}

public struct StatusPill: View {
    public let status: AppStatus
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var pulseScale: CGFloat = 1.0
    
    public init(status: AppStatus) {
        self.status = status
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            // Pulse circle
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
                .scaleEffect(pulseScale)
                .onAppear {
                    setupAnimation()
                }
                .onChange(of: status) { _ in
                    setupAnimation()
                }
                .onChange(of: reduceMotion) { _ in
                    setupAnimation()
                }
            
            Text(status.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(DT.Color.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(status.softColor)
        )
        .overlay(
            Capsule()
                .strokeBorder(status.color.opacity(0.25), lineWidth: 0.5)
        )
    }
    
    private func setupAnimation() {
        if !reduceMotion && (status == .scanning || status == .sorting) {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.5
            }
        } else {
            pulseScale = 1.0
        }
    }
}
