import SwiftUI
import AppKit

// Extension to load hex colors
extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

public enum DT {  // Design Tokens — коротко, бо використовується скрізь
    public enum Color {
        // Backgrounds
        public static let appBg       = SwiftUI.Color(hex: "#0a0b0d")
        public static let elevated    = SwiftUI.Color(hex: "#14161a")
        public static let glass       = SwiftUI.Color.white.opacity(0.035)
        public static let glassHover  = SwiftUI.Color.white.opacity(0.055)

        // Borders
        public static let borderSubtle  = SwiftUI.Color.white.opacity(0.07)
        public static let borderDefault = SwiftUI.Color.white.opacity(0.11)
        public static let borderStrong  = SwiftUI.Color.white.opacity(0.18)

        // Text
        public static let textPrimary   = SwiftUI.Color(hex: "#f4f4f5")
        public static let textSecondary = SwiftUI.Color(hex: "#a1a1aa")
        public static let textTertiary  = SwiftUI.Color(hex: "#71717a")
        public static let textFaint     = SwiftUI.Color(hex: "#52525b")

        // Accent — один, electric blue desaturated
        public static let accent        = SwiftUI.Color(hex: "#3b82f6")
        public static let accentStrong  = SwiftUI.Color(hex: "#60a5fa")
        public static let accentSoft    = SwiftUI.Color(hex: "#3b82f6").opacity(0.12)

        // Semantic
        public static let success       = SwiftUI.Color(hex: "#34d399")
        public static let successSoft   = SwiftUI.Color(hex: "#34d399").opacity(0.10)
        public static let warning       = SwiftUI.Color(hex: "#fbbf24")
        public static let danger        = SwiftUI.Color(hex: "#f87171")
    }

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 20
    }

    public enum Animation {
        public static let spring     = SwiftUI.Animation.spring(response: 0.4,
                                                                dampingFraction: 0.7)
        public static let springFast = SwiftUI.Animation.spring(response: 0.25,
                                                                dampingFraction: 0.8)
        public static let smooth     = SwiftUI.Animation.easeInOut(duration: 0.2)
    }
}

public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .underWindowBackground
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    public init(material: NSVisualEffectView.Material = .underWindowBackground, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

public struct LiquidGlass: ViewModifier {
    public var cornerRadius: CGFloat = DT.Radius.lg
    public var borderOpacity: Double = 0.11

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                Color.white.opacity(borderOpacity),
                                lineWidth: 0.5
                            )
                    )
                    .overlay(
                        // Inner highlight top edge
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), .clear],
                                    startPoint: .top, endPoint: .center
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
    }
}

extension View {
    public func liquidGlass(radius: CGFloat = DT.Radius.lg) -> some View {
        modifier(LiquidGlass(cornerRadius: radius))
    }
    
    // Fallback/alias for old codebase usage to prevent errors
    public func liquidGlass(cornerRadius: CGFloat, opacity: Double = 0.85, shadowRadius: CGFloat = 8) -> some View {
        modifier(LiquidGlass(cornerRadius: cornerRadius))
    }
}

public struct SpotlightHover: ViewModifier {
    @State private var mouseLocation: CGPoint = .zero
    @State private var isHovering = false

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if isHovering {
                        RadialGradient(
                            colors: [Color.white.opacity(0.12), .clear],
                            center: UnitPoint(
                                x: mouseLocation.x / geo.size.width,
                                y: mouseLocation.y / geo.size.height
                            ),
                            startRadius: 0,
                            endRadius: 80
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.md))
                        .allowsHitTesting(false)
                    }
                }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc):
                    isHovering = true
                    mouseLocation = loc
                case .ended:
                    isHovering = false
                }
            }
    }
}

extension View {
    public func spotlightHover() -> some View {
        modifier(SpotlightHover())
    }
}

public struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                if reduceMotion {
                    EmptyView()
                } else {
                    LinearGradient(
                        colors: [.clear,
                                 Color.white.opacity(0.35),
                                 .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.4)
                    .offset(x: geo.size.width * (phase + 0.5))
                    .allowsHitTesting(false)
                }
            }
            .clipped()
        )
        .onAppear {
            if !reduceMotion {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
        }
    }
}

extension View {
    public func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
