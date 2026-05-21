import SwiftUI

// MARK: - Ripple Effect
struct Ripple: View {
    let origin: CGPoint
    let onComplete: () -> Void

    @State private var animate = false

    var body: some View {
        Circle()
            .fill(Color.white.opacity(animate ? 0 : 0.35))
            .frame(width: animate ? 400 : 0, height: animate ? 400 : 0)
            .position(origin)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    animate = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                    onComplete()
                }
            }
    }
}

// MARK: - MagneticButton
public struct MagneticButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var offset: CGSize = .zero
    @State private var isPressed = false
    @State private var rippleOrigin: CGPoint? = nil
    @State private var showRipple = false
    @State private var buttonSize: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    public var body: some View {
        label()
            .font(DT.Font.body(14))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [DT.Color.accentStrong, DT.Color.accent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .onAppear { buttonSize = geo.size }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.lg))
            .overlay(
                Group {
                    if showRipple, let origin = rippleOrigin {
                        Ripple(origin: origin) {
                            showRipple = false
                            rippleOrigin = nil
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.lg))
            )
            .shadow(
                color: DT.Color.accent.opacity(0.5),
                radius: isPressed ? 16 : 24,
                x: 0, y: isPressed ? 4 : 8
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .offset(reduceMotion ? .zero : offset)
            .onContinuousHover { phase in
                guard !reduceMotion else { return }
                switch phase {
                case .active(let loc):
                    let center = CGPoint(x: buttonSize.width / 2, y: buttonSize.height / 2)
                    withAnimation(DT.Animation.springFast) {
                        offset = CGSize(
                            width: (loc.x - center.x) * 0.12,
                            height: (loc.y - center.y) * 0.12
                        )
                    }
                case .ended:
                    withAnimation(DT.Animation.spring) {
                        offset = .zero
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressed {
                            withAnimation(.easeOut(duration: 0.1)) {
                                isPressed = true
                            }
                            rippleOrigin = value.location
                            showRipple = true
                            // Haptic feedback
                            NSHapticFeedbackManager.defaultPerformer.perform(
                                .generic, performanceTime: .now
                            )
                        }
                    }
                    .onEnded { _ in
                        withAnimation(DT.Animation.springFast) {
                            isPressed = false
                        }
                        action()
                    }
            )
    }
}
