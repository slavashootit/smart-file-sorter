import SwiftUI

public struct FilmGrain: View {
    public var body: some View {
        Canvas { ctx, size in
            for _ in 0..<800 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let dot = CGRect(x: x, y: y, width: 1, height: 1)
                ctx.fill(Path(dot), with: .color(.white.opacity(0.04)))
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
