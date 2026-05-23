import SwiftUI

public struct MeshBackground: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init() {}
    
    public var body: some View {
        if reduceMotion {
            // Premium static dark gradient layout
            LinearGradient(
                colors: [
                    DT.Color.appBg,
                    DT.Color.appBg.opacity(0.95),
                    DT.Color.elevated
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        } else {
            ZStack {
                TimelineView(.periodic(from: .now, by: 1.0/10.0)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    
                    Canvas { context, size in
                        // Base background fill
                        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(DT.Color.appBg))
                        
                        // Blob 1: Electric Blue (top-left / center)
                        let x1 = size.width * (0.3 + 0.15 * sin(time * 0.4))
                        let y1 = size.height * (0.4 + 0.12 * cos(time * 0.3))
                        let r1 = min(size.width, size.height) * 0.45
                        context.fill(
                            Path(ellipseIn: CGRect(x: x1 - r1/2, y: y1 - r1/2, width: r1, height: r1)),
                            with: .color(DT.Color.accent.opacity(0.07))
                        )
                        
                        // Blob 2: Success Green/Teal (bottom-right)
                        let x2 = size.width * (0.7 + 0.12 * cos(time * 0.3))
                        let y2 = size.height * (0.6 + 0.15 * sin(time * 0.5))
                        let r2 = min(size.width, size.height) * 0.4
                        context.fill(
                            Path(ellipseIn: CGRect(x: x2 - r2/2, y: y2 - r2/2, width: r2, height: r2)),
                            with: .color(DT.Color.success.opacity(0.04))
                        )
                        
                        // Blob 3: Accent Strong Blue (top-right/center)
                        let x3 = size.width * (0.5 + 0.18 * sin(time * 0.5))
                        let y3 = size.height * (0.3 + 0.10 * cos(time * 0.4))
                        let r3 = min(size.width, size.height) * 0.35
                        context.fill(
                            Path(ellipseIn: CGRect(x: x3 - r3/2, y: y3 - r3/2, width: r3, height: r3)),
                            with: .color(DT.Color.accentStrong.opacity(0.05))
                        )
                    }
                    .drawingGroup()
                    .blur(radius: 40)
                    .ignoresSafeArea()
                }
                
                FilmGrain(intensity: 0.03)
                    .ignoresSafeArea()
            }
        }
    }
}
