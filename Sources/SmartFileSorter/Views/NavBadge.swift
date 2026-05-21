import SwiftUI

public enum NavBadgeType {
    case count(Int)
    case label(String)
}

public struct NavBadge: View {
    public let type: NavBadgeType
    
    public init(_ type: NavBadgeType) {
        self.type = type
    }
    
    public init(_ count: Int) {
        self.type = .count(count)
    }
    
    public init(_ label: String) {
        self.type = .label(label)
    }
    
    public var body: some View {
        switch type {
        case .count(let val):
            if val > 0 {
                Text("\(val)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(DT.Color.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule()
                            .fill(DT.Color.accentSoft)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(DT.Color.accent.opacity(0.3), lineWidth: 0.5)
                    )
            }
        case .label(let str):
            if !str.isEmpty {
                Text(str)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(str == "NEW" ? DT.Color.success : DT.Color.accentStrong)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(
                        Capsule()
                            .fill(str == "NEW" ? DT.Color.successSoft : DT.Color.accentSoft)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder((str == "NEW" ? DT.Color.success : DT.Color.accent).opacity(0.35), lineWidth: 0.5)
                    )
            }
        }
    }
}
