import SwiftUI
import AppKit

public struct FlyingFileItem: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let systemImage: String
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var progress: CGFloat = 0.0
}

public class FileAnimator: ObservableObject {
    public static let shared = FileAnimator()
    @Published public var activeAnimations: [FlyingFileItem] = []
    
    private init() {}
    
    public func triggerMovement(name: String, isFolder: Bool, from start: CGPoint, to end: CGPoint) {
        let systemImage = isFolder ? "folder.fill" : "doc.fill"
        let item = FlyingFileItem(name: name, systemImage: systemImage, startPoint: start, endPoint: end)
        
        DispatchQueue.main.async {
            self.activeAnimations.append(item)
            
            SoundManager.shared.playWhoosh()
            
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75, blendDuration: 0.45)) {
                if let index = self.activeAnimations.firstIndex(where: { $0.id == item.id }) {
                    self.activeAnimations[index].progress = 1.0
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                SoundManager.shared.playChime()
                SoundManager.shared.performHapticFeedback()
                self.activeAnimations.removeAll(where: { $0.id == item.id })
            }
        }
    }
}

public struct AnimationOverlay: View {
    @ObservedObject var animator = FileAnimator.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            ForEach(animator.activeAnimations) { item in
                let currentX = item.startPoint.x + (item.endPoint.x - item.startPoint.x) * item.progress
                let currentY = item.startPoint.y + (item.endPoint.y - item.startPoint.y) * item.progress
                
                VStack(spacing: 4) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                    Text(item.name)
                        .font(.caption2)
                        .bold()
                        .lineLimit(1)
                        .frame(width: 80)
                }
                .padding(8)
                .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
                .cornerRadius(8)
                .shadow(radius: 6)
                .position(x: currentX, y: currentY)
                .scaleEffect(item.progress == 1.0 ? 0.0 : 1.0)
                .opacity(item.progress == 1.0 ? 0.0 : 1.0)
                
                if item.progress > 0.8 && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    ForEach(0..<8) { idx in
                        let angle = Double(idx) * (Double.pi / 4)
                        let speed: CGFloat = 30 * item.progress
                        let pX = item.endPoint.x + CGFloat(cos(angle)) * speed
                        let pY = item.endPoint.y + CGFloat(sin(angle)) * speed
                        
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 4)
                            .position(x: pX, y: pY)
                            .opacity(1.0 - Double(item.progress))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
