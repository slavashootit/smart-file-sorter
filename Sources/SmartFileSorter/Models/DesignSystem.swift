import SwiftUI
import AppKit

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

public struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var opacity: Double
    var shadowRadius: CGFloat
    
    @Environment(\.colorScheme) var colorScheme
    
    public func body(content: Content) -> some View {
        content
            .padding()
            .background(
                VisualEffectView(
                    material: colorScheme == .dark ? .hudWindow : .selection,
                    blendingMode: .withinWindow
                )
                .opacity(opacity)
            )
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.25),
                                Color.clear,
                                Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius / 2
            )
    }
}

extension View {
    public func liquidGlass(cornerRadius: CGFloat = 12, opacity: Double = 0.85, shadowRadius: CGFloat = 8) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, opacity: opacity, shadowRadius: shadowRadius))
    }
}
