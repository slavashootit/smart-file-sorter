import SwiftUI

public struct FilmGrain: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let intensity: Double

    public init(intensity: Double = 0.03) {
        self.intensity = intensity
    }

    public var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            Canvas { context, size in
                for _ in 0..<Int(size.width * size.height * 0.003) {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let brightness = Double.random(in: 0.5...1.0)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(Color.white.opacity(intensity * brightness))
                    )
                }
            }
            .allowsHitTesting(false)
            .blendMode(.overlay)
            .ignoresSafeArea()
        }
    }
}
