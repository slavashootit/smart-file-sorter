import SwiftUI
import AppKit

struct SunburstArc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = Angle(degrees: newValue.first)
            endAngle = Angle(degrees: newValue.second)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * 0.6
        
        let endRad = endAngle.radians
        
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        
        let innerEndX = center.x + innerRadius * CGFloat(cos(endRad))
        let innerEndY = center.y + innerRadius * CGFloat(sin(endRad))
        path.addLine(to: CGPoint(x: innerEndX, y: innerEndY))
        
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        
        path.closeSubpath()
        return path
    }
}

struct SunburstSegment: Identifiable, Equatable {
    let id = UUID()
    let child: DiskNode
    let startAngle: Angle
    let endAngle: Angle
    
    static func == (lhs: SunburstSegment, rhs: SunburstSegment) -> Bool {
        lhs.child == rhs.child &&
        lhs.startAngle == rhs.startAngle &&
        lhs.endAngle == rhs.endAngle
    }
}

struct SunburstChartView: View {
    @StateObject private var analyzer = DiskAnalyzer()
    @State private var scanFolder = NSHomeDirectory() + "/Downloads"
    @State private var hoveredNode: DiskNode? = nil
    @State private var hoverPoint: CGPoint = .zero
    @State private var segments: [SunburstSegment] = []
    
    // Spring animation for drilling down
    private let drillAnimation = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.6)
    
    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 16) {
                Text("Аналізатор диска")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                TextField("Шлях", text: $scanFolder)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 320)
                
                Button(action: selectFolder) {
                    Image(systemName: "folder")
                }
                
                if analyzer.isScanning {
                    Button(action: { analyzer.cancel() }) {
                        Text("Зупинити")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button(action: { analyzer.analyze(directoryPath: scanFolder) }) {
                        Text("Аналізувати")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            
            Divider()
            
            if analyzer.isScanning {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Сканування диска...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let current = analyzer.currentNode {
                HStack(spacing: 0) {
                    // Left: Radial Map
                    VStack {
                        // Navigation Back button if we have history
                        HStack {
                            if !analyzer.history.isEmpty {
                                Button(action: {
                                    withAnimation(drillAnimation) {
                                        analyzer.navigateBack()
                                    }
                                }) {
                                    Label("Назад", systemImage: "arrow.left")
                                }
                                .buttonStyle(.bordered)
                            }
                            Spacer()
                            Text(current.url.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        GeometryReader { geo in
                            ZStack {
                                // Draw radial segments
                                ForEach(segments) { segment in
                                    let child = segment.child
                                    SunburstArc(startAngle: segment.startAngle, endAngle: segment.endAngle)
                                        .fill(colorForNode(child))
                                        .opacity(hoveredNode == child ? 1.0 : 0.85)
                                        .scaleEffect(hoveredNode == child ? 1.05 : 1.0)
                                        .animation(.interactiveSpring(), value: hoveredNode)
                                        .onHover { isHovered in
                                            hoveredNode = isHovered ? child : nil
                                        }
                                        .onTapGesture(count: 2) {
                                            withAnimation(drillAnimation) {
                                                analyzer.selectNode(child)
                                            }
                                        }
                                        .contextMenu {
                                            contextMenuForNode(child)
                                        }
                                }
                                
                                // Center parent circle
                                Circle()
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(width: min(geo.size.width, geo.size.height) * 0.58)
                                    .onTapGesture {
                                        if !analyzer.history.isEmpty {
                                            withAnimation(drillAnimation) {
                                                analyzer.navigateBack()
                                            }
                                        }
                                    }
                                
                                VStack(spacing: 4) {
                                    Text(current.name)
                                        .font(.headline)
                                        .lineLimit(1)
                                        .frame(width: min(geo.size.width, geo.size.height) * 0.45)
                                    Text(formatSize(current.size))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(width: 420)
                    
                    Divider()
                    
                    // Right: List of items
                    List {
                        ForEach(current.children) { child in
                            HStack {
                                Circle()
                                    .fill(colorForNode(child))
                                    .frame(width: 10, height: 10)
                                
                                Image(systemName: child.isDirectory ? "folder" : "doc")
                                    .foregroundColor(.secondary)
                                
                                Text(child.name)
                                    .fontWeight(hoveredNode == child ? .bold : .regular)
                                
                                Spacer()
                                
                                Text(formatSize(child.size))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onHover { isHovered in
                                hoveredNode = isHovered ? child : nil
                            }
                            .onTapGesture {
                                if child.isDirectory {
                                    withAnimation(drillAnimation) {
                                        analyzer.selectNode(child)
                                    }
                                }
                            }
                            .contextMenu {
                                contextMenuForNode(child)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
                .overlay(tooltipOverlay)
            } else {
                VStack {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                        .padding()
                    Text("Виберіть та проаналізуйте папку для побудови карти диска.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: analyzer.currentNode) {
            if let current = analyzer.currentNode {
                updateSegments(for: current)
            } else {
                segments = []
            }
        }
    }
    
    // Tooltip overlay
    private var tooltipOverlay: some View {
        Group {
            if let node = hoveredNode {
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.name)
                        .font(.caption)
                        .bold()
                    Text(formatSize(node.size))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
                .cornerRadius(6)
                .shadow(radius: 4)
                .position(x: 210, y: 340) // Anchor tooltip in a clean fixed location on bottom of visualizer
            }
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            scanFolder = url.path
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func colorForNode(_ node: DiskNode) -> Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .yellow, .green, .cyan, .teal]
        let hashValue = abs(node.name.hashValue)
        return colors[hashValue % colors.count]
    }
    
    private func updateSegments(for parent: DiskNode) {
        let totalSize = parent.size
        guard totalSize > 0 else {
            self.segments = []
            return
        }
        
        var calculatedSegments: [SunburstSegment] = []
        var currentAngle = Angle(degrees: 0)
        
        for child in parent.children.prefix(12) {
            let percentage = Double(child.size) / Double(totalSize)
            let sweep = percentage * 360.0
            let start = currentAngle
            let end = currentAngle + Angle(degrees: sweep)
            
            calculatedSegments.append(SunburstSegment(child: child, startAngle: start, endAngle: end))
            currentAngle = end
        }
        
        self.segments = calculatedSegments
    }
    
    @ViewBuilder
    private func contextMenuForNode(_ node: DiskNode) -> some View {
        Button("Показати у Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
        }
        
        Button("Перемістити у Смітник") {
            try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
            // Reload parent after deletion
            if let root = analyzer.rootNode {
                analyzer.analyze(directoryPath: root.url.path)
            }
        }
        
        Button("Створити правило для папки") {
            // Send notification to add rule
            NotificationCenter.default.post(name: NSNotification.Name("AddFolderRule"), object: node.url)
        }
    }
}
