import SwiftUI
import Charts

// MARK: - AnimatedNumber
public struct AnimatedNumber: View {
    let value: Int
    let font: SwiftUI.Font
    @State private var displayed: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(value: Int, font: SwiftUI.Font = DT.Font.mono(22)) {
        self.value = value
        self.font = font
    }

    public var body: some View {
        Text("\(displayed)")
            .font(font)
            .foregroundColor(DT.Color.textPrimary)
            .onAppear { animate() }
            .onChange(of: value) { _ in animate() }
    }

    private func animate() {
        guard !reduceMotion else {
            displayed = value
            return
        }
        let steps = 30
        let duration = 1.2
        let stepDelay = duration / Double(steps)
        let target = value
        let start = displayed

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDelay * Double(i)) {
                let progress = Double(i) / Double(steps)
                let eased = 1 - pow(1 - progress, 3) // easeOutCubic
                displayed = start + Int(Double(target - start) * eased)
            }
        }
    }
}

// MARK: - BentoStat
public struct BentoStat: View {
    let label: String
    let value: Int
    let formattedValue: String?
    let delta: String?
    let trend: [Double]
    let tint: Color

    public init(
        label: String,
        value: Int,
        formattedValue: String? = nil,
        delta: String? = nil,
        trend: [Double] = [],
        tint: Color = DT.Color.accent
    ) {
        self.label = label
        self.value = value
        self.formattedValue = formattedValue
        self.delta = delta
        self.trend = trend
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DT.Color.textTertiary)
                    .tracking(0.6)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let formatted = formattedValue {
                    Text(formatted)
                        .font(DT.Font.mono(22))
                        .foregroundColor(DT.Color.textPrimary)
                } else {
                    AnimatedNumber(value: value)
                }
                if let delta = delta {
                    Text(delta)
                        .font(DT.Font.mono(11))
                        .foregroundColor(tint)
                }
            }

            if !trend.isEmpty {
                Chart {
                    ForEach(Array(trend.enumerated()), id: \.offset) { i, val in
                        LineMark(
                            x: .value("i", i),
                            y: .value("v", val)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(tint)
                    }
                    ForEach(Array(trend.enumerated()), id: \.offset) { i, val in
                        AreaMark(
                            x: .value("i", i),
                            y: .value("v", val)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tint.opacity(0.3), tint.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartPlotStyle { plot in
                    plot.background(.clear)
                }
                .frame(height: 28)
                .opacity(0.8)
            }
        }
        .padding(14)
        .liquidGlass(radius: DT.Radius.lg)
    }
}
